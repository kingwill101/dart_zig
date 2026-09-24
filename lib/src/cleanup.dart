import 'dart:async';

/// Cooperative cancellation shared by related Dart work.
final class CancellationScope {
  CancellationScope({CancellationScope? parent}) {
    if (parent != null) {
      if (parent.isCancelled) {
        cancel(parent.reason);
      } else {
        _parent = parent.listen(cancel);
      }
    }
  }
  final _listeners = <void Function(Object?)>{};
  final _done = Completer<Object?>();
  void Function()? _parent;
  bool get isCancelled => _done.isCompleted;
  Object? get reason => _reason;
  Object? _reason;
  Future<Object?> get cancelled => _done.future;

  /// Registers a synchronous observer and returns its detach action.
  void Function() listen(void Function(Object?) listener) {
    if (isCancelled) {
      listener(_reason);
      return () {};
    }
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Cancels once and notifies every observer, even if another observer throws.
  void cancel([Object? reason]) {
    if (isCancelled) return;
    _reason = reason;
    _done.complete(reason);
    _parent?.call();
    _parent = null;
    final listeners = _listeners.toList();
    _listeners.clear();
    for (final listener in listeners) {
      try {
        listener(reason);
      } catch (error, stack) {
        scheduleMicrotask(() => Zone.current.handleUncaughtError(error, stack));
      }
    }
  }

  /// Throws when cooperative work should stop.
  void check() {
    if (isCancelled) throw CancelledException(reason);
  }
}

/// A cooperative cancellation carrying the initiating reason.
final class CancelledException implements Exception {
  const CancelledException(this.reason);
  final Object? reason;
  @override
  String toString() => 'CancelledException: $reason';
}

/// All failures collected while releasing a cleanup scope.
final class CleanupException implements Exception {
  CleanupException(this.failures);
  final List<({Object error, StackTrace stack})> failures;
  @override
  String toString() => 'CleanupException(${failures.length} failures)';
}

/// Host-independent asynchronous cleanup, in reverse registration order.
///
/// Register producers after their runtime so producers are stopped first.
/// Closing cancels [cancellation], attempts every disposer, then reports all
/// failures. Repeated closes share a future; registration after close fails.
final class CleanupScope {
  CleanupScope({CancellationScope? parent})
    : cancellation = CancellationScope(parent: parent);
  final CancellationScope cancellation;
  final _actions = <FutureOr<void> Function()>[];
  Future<void>? _closing;
  bool get isClosed => _closing != null;

  /// Registers cleanup and returns a detach action that does not run it.
  void Function() defer(FutureOr<void> Function() cleanup) {
    if (isClosed) throw StateError('Cleanup scope is closed');
    _actions.add(cleanup);
    return () {
      if (!isClosed) _actions.remove(cleanup);
    };
  }

  /// Owns a resource and returns it for convenient construction.
  T own<T>(T resource, FutureOr<void> Function(T) dispose) {
    defer(() => dispose(resource));
    return resource;
  }

  /// Closes resources even when the body throws.
  static Future<T> run<T>(Future<T> Function(CleanupScope) body) async {
    final scope = CleanupScope();
    late T result;
    Object? bodyError;
    StackTrace? bodyStack;
    try {
      result = await body(scope);
    } catch (error, stack) {
      bodyError = error;
      bodyStack = stack;
    }
    try {
      await scope.close();
    } catch (error, stack) {
      if (bodyError == null) rethrow;
      throw CleanupException([
        (error: bodyError, stack: bodyStack!),
        (error: error, stack: stack),
      ]);
    }
    if (bodyError != null) Error.throwWithStackTrace(bodyError, bodyStack!);
    return result;
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    final done = Completer<void>();
    _closing = done.future;
    unawaited(_release(done));
    return done.future;
  }

  Future<void> _release(Completer<void> done) async {
    final failures = <({Object error, StackTrace stack})>[];
    cancellation.cancel();
    for (final action in _actions.reversed) {
      try {
        await action();
      } catch (error, stack) {
        failures.add((error: error, stack: stack));
      }
    }
    _actions.clear();
    if (failures.isEmpty) {
      done.complete();
    } else {
      done.completeError(CleanupException(List.unmodifiable(failures)));
    }
  }
}

/// Serializes host-controlled replacement of an owned resource.
///
/// Closing the previous resource completes before a replacement is constructed.
/// A failed cleanup prevents replacement; callers can retry an explicit restart.
final class RestartableResource<T> {
  RestartableResource(this.create, this.dispose);
  final Future<T> Function() create;
  final Future<void> Function(T) dispose;
  T? _value;
  int generation = 0;
  Future<void> _tail = Future.value();
  bool _closed = false;
  T? get current => _value;
  Future<T> restart() {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        if (_closed) throw StateError('Resource owner is closed');
        if (_value != null) {
          await dispose(_value as T);
          _value = null;
        }
        _value = await create();
        generation++;
        result.complete(_value as T);
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<void>? _closing;
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    await _tail;
    if (_value != null) {
      await dispose(_value as T);
      _value = null;
    }
  }
}
