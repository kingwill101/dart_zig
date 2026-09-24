import 'dart:async';
import 'dart:collection';

import 'runtime_error.dart';

/// Explicit delivery policy when an event subscriber exhausts its budget.
enum OverflowPolicy { error, dropNewest, dropOldest, latest }

/// Broadcast delivery with bounded per-subscriber storage and optional replay.
///
/// [retain] creates a subscriber-owned value; [release] frees queued or cached
/// values. Delivered values belong to the subscriber. All callbacks run on the
/// Dart event loop, so replay registration cannot miss an intervening update.
final class SignalBus<T> {
  SignalBus({
    required this.sizeOf,
    this.maxMessages = 64,
    this.maxBytes = 1048576,
    this.overflow = OverflowPolicy.error,
    this.replayLatest = false,
    T Function(T)? retain,
    void Function(T)? release,
  }) : _retain = retain ?? ((value) => value),
       _release = release ?? ((_) {}) {
    if (maxMessages <= 0 || maxBytes <= 0) {
      throw ArgumentError('Signal budgets must be positive');
    }
  }
  final int Function(T) sizeOf;
  final int maxMessages, maxBytes;
  final OverflowPolicy overflow;
  final bool replayLatest;
  final T Function(T) _retain;
  final void Function(T) _release;
  final _listeners = <SignalListener<T>>{};
  bool _closed = false;
  bool _hasLatest = false;
  T? _latest;
  int overflowCount = 0;
  bool get hasListeners => _listeners.isNotEmpty;
  bool get hasLatest => _hasLatest;

  /// Retains a snapshot for its caller. Dispose owned values after use.
  T? get latest => _hasLatest ? _retain(_latest as T) : null;
  late final Stream<T> stream = Stream<T>.multi((controller) {
    if (_closed) {
      controller.close();
      return;
    }
    final listener = SignalListener<T>(controller);
    _listeners.add(listener);
    controller.onCancel = () {
      _listeners.remove(listener);
      _clear(listener);
    };
    controller.onResume = () => _schedule(listener);
    if (_hasLatest) _enqueue(listener, _latest as T);
  }, isBroadcast: true);

  void _clear(SignalListener<T> listener) {
    while (listener.pending.isNotEmpty) {
      _release(listener.pending.removeFirst());
    }
    listener.bytes = 0;
  }

  void _schedule(SignalListener<T> listener) {
    if (listener.scheduled || listener.controller.isPaused) return;
    listener.scheduled = true;
    scheduleMicrotask(() {
      listener.scheduled = false;
      while (!_closed &&
          _listeners.contains(listener) &&
          !listener.controller.isPaused &&
          listener.pending.isNotEmpty) {
        final value = listener.pending.removeFirst();
        listener.bytes -= sizeOf(value);
        listener.controller.addSync(value);
      }
    });
  }

  void _enqueue(SignalListener<T> listener, T value) {
    final size = sizeOf(value);
    if (size < 0) throw ArgumentError('Negative signal size');
    if (overflow == OverflowPolicy.latest) {
      overflowCount += listener.pending.length;
      _clear(listener);
    }
    bool full() =>
        listener.pending.length >= maxMessages ||
        size > maxBytes - listener.bytes;
    if (full()) {
      overflowCount++;
      if (overflow == OverflowPolicy.dropOldest) {
        while (listener.pending.isNotEmpty && full()) {
          final old = listener.pending.removeFirst();
          listener.bytes -= sizeOf(old);
          _release(old);
        }
      }
      if (full()) {
        if (overflow == OverflowPolicy.error) {
          _clear(listener);
          _listeners.remove(listener);
          listener.controller.addError(
            const NativeException(
              'signal_overflow',
              'Signal subscriber exceeded its budget',
            ),
          );
          listener.controller.close();
        }
        return;
      }
    }
    listener.pending.add(_retain(value));
    listener.bytes += size;
    _schedule(listener);
  }

  /// Publishes without taking ownership of [value].
  void add(T value) {
    if (_closed) return;
    if (replayLatest) {
      if (sizeOf(value) > maxBytes) {
        throw const NativeException(
          'too_large',
          'State snapshot exceeds budget',
        );
      }
      final next = _retain(value);
      if (_hasLatest) _release(_latest as T);
      _latest = next;
      _hasLatest = true;
    }
    for (final listener in _listeners.toList()) {
      _enqueue(listener, value);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (_hasLatest) {
      _release(_latest as T);
      _latest = null;
      _hasLatest = false;
    }
    for (final listener in _listeners) {
      _clear(listener);
      listener.controller.close();
    }
    _listeners.clear();
  }
}

/// @nodoc
final class SignalListener<T> {
  SignalListener(this.controller);
  final MultiStreamController<T> controller;
  final pending = ListQueue<T>();
  int bytes = 0;
  bool scheduled = false;
}
