import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'runtime_error.dart';
import 'signal_bus.dart';
import 'native_buffer.dart';
import 'codec.dart';
import 'transport.dart';
import 'transport_native.dart'
    if (dart.library.js_interop) 'transport_web.dart'
    as platform;
import 'cleanup.dart';
import 'diagnostics.dart';

/// One asynchronous native operation and its explicit cancellation control.
final class NativeCall {
  /// Creates a transport call with its result and cancellation action.
  NativeCall(this.result, this.cancel);

  /// Independently owned Dart bytes, or the operation failure.
  final Future<Uint8List> result;

  /// Cancels a pending call; repeated calls after completion have no effect.
  ///
  /// The result fails with `cancelled`; native work must cooperate to stop.
  final void Function() cancel;
}

/// An asynchronous call returning an owned native buffer without copying it to Dart.
final class NativeBufferCall {
  /// Creates a transport call that transfers one native buffer reference.
  NativeBufferCall(this.result, this.cancel);

  /// Owned result that the receiver must dispose, or the operation failure.
  final Future<NativeBuffer> result;

  /// Cancels a pending call; completed buffer ownership remains with the caller.
  final void Function() cancel;
}

/// Snapshot of native transport counters. Copied bytes count native-side copies.
final class SessionStats {
  /// Creates a snapshot from native counters and current queue occupancy.
  const SessionStats(
    this.submitted,
    this.delivered,
    this.wakes,
    this.copiedBytes,
    this.inputMessages,
    this.outputMessages,
    this.inputBytes,
    this.outputBytes, {
    this.logDrops = 0,
  });

  /// Input frames enqueued since creation, including callback replies.
  final int submitted;

  /// Output frames transferred to Dart, including events and callbacks.
  final int delivered;

  /// Native wake notifications counted by the runtime.
  final int wakes;

  /// Payload bytes copied at the native transport boundary.
  ///
  /// Excludes Dart allocations, codecs, and application-specific copies.
  final int copiedBytes;

  /// Structured native log records dropped before delivery.
  final int logDrops;

  /// Frames currently queued for native dispatch.
  final int inputMessages;

  /// Frames currently queued for Dart delivery.
  final int outputMessages;

  /// Payload bytes currently queued for native dispatch.
  final int inputBytes;

  /// Payload bytes currently queued for Dart delivery.
  final int outputBytes;
}

/// One typed-event transport frame; payload bytes are owned by Dart.
final class NativeSignal {
  /// Creates an event carrying an application route and Dart-owned payload.
  const NativeSignal(this.route, this.bytes);

  /// Application signal identifier, used by typed subscriptions.
  final int route;

  /// Payload shared among subscribers; treat it as read-only.
  final Uint8List bytes;
}

/// One owned signal frame. Each listener must dispose its own buffer lease.
final class OwnedNativeSignal {
  OwnedNativeSignal(this.route, this.buffer);
  final int route;
  final NativeBuffer buffer;
  OwnedNativeSignal retain() => OwnedNativeSignal(route, buffer.retain());
  void dispose() => buffer.dispose();
}

/// A native log record with numeric severity (debug=0, info=1, warning=2, error=3).
final class NativeLog {
  /// Creates a decoded native log record.
  const NativeLog(this.level, this.scope, this.message);

  /// Severity: debug 0, info 1, warning 2, or error 3.
  final int level;

  /// Application-defined source or component name.
  final String scope;

  /// Formatted message supplied by native code.
  final String message;
}

/// Internal transport state for one admitted or waiting call.
///
/// @nodoc
final class _PendingCall {
  _PendingCall(this.route);
  final int route;
  final completer = Completer<Uint8List>();
  int? id;
  bool finished = false;
  Timer? timer;
  Duration? timeout;
  final elapsed = Stopwatch()..start();
  StreamController<Uint8List>? stream;
  Uint8List? heldItem;
  bool paused = false;
  bool credit = false;
  Uint8List? input;
  Completer<NativeBuffer>? nativeBuffer;
}

/// A general native session with bounded calls, batch delivery, and async callbacks.
///
/// Explicitly close the session. Application handlers run on native worker threads.
/// Each session owns its native objects and callbacks; they cannot cross sessions.
///
/// {@example /example/runtime_features_example/demo/toolkit.dart#session-setup}
final class NativeSession {
  /// Creates a session using its application's native asset or an injected transport.
  ///
  /// [workers] must be between 1 and 64; [batchSize] between 1 and 1024.
  /// [queueCapacity] limits frames in each native queue. [maxBytes] limits
  /// queued input bytes, regular output bytes, and each submitted payload.
  /// Native results have one additional [maxBytes] pending-output reserve for
  /// completion while Dart drains the regular output queue.
  /// [maxPendingBytes] defaults to [maxBytes]. All limits must be positive.
  ///
  /// Throws [ArgumentError] for invalid limits and [NativeException] if
  /// initialization, protocol negotiation, or native allocation fails.
  /// Close this session explicitly, including when application work fails.
  NativeSession({
    this.bindings,
    this.onDiagnostic,
    SessionTransport? transport,
    this.stopExternal,
    this.maxPending = 256,
    this.maxBytes = 8 * 1024 * 1024,
    int? maxPendingBytes,
    int queueCapacity = 256,
    int workers = 1,
    this.batchSize = 32,
  }) : maxPendingBytes = maxPendingBytes ?? maxBytes {
    if (this.maxPendingBytes <= 0 ||
        maxPending <= 0 ||
        maxBytes <= 0 ||
        queueCapacity <= 0 ||
        workers <= 0 ||
        workers > 64 ||
        batchSize <= 0 ||
        batchSize > 1024) {
      throw ArgumentError('Invalid session limits');
    }
    _transport =
        transport ??
        platform.createTransport(
          bindings: bindings,
          queueCapacity: queueCapacity,
          maxBytes: maxBytes,
          maxPending: maxPending,
          workers: workers,
          batchSize: batchSize,
        );
    if (_transport.protocolVersion != 2) {
      _transport.stop();
      unawaited(_destroyTransport());
      throw const NativeException(
        'protocol',
        'Incompatible transport protocol',
      );
    }
    _transport.onWake = () {
      if (_closed) return;
      _signalCapacity();
      _drain();
    };
  }

  /// Optional payload-free tracing for calls, admission pressure, and signals.
  final DiagnosticSink? onDiagnostic;
  void _trace(String kind, {int? route, int? id, int? bytes, Object? error}) {
    final sink = onDiagnostic;
    if (sink == null) return;
    final event = RuntimeDiagnostic(
      kind,
      route: route,
      requestId: id,
      bytes: bytes,
      error: error,
    );
    scheduleMicrotask(() => sink(event));
  }

  /// Generated adapter for this application's native asset.
  ///
  /// Required on the Dart VM unless a transport is supplied.
  final Object? bindings;

  /// Stops and joins application-owned native producers before storage is freed.
  /// A failure retains native storage; repeated close calls return the same error.
  final Future<void> Function()? stopExternal;

  /// Maximum outstanding calls, including calls waiting for admission.
  final int maxPending;

  /// Native queued-byte budget for input and each output queue, and maximum
  /// individual payload. Native output has a second, equally sized reserve.
  final int maxBytes;

  /// Budget for Dart payload snapshots awaiting native admission.
  final int maxPendingBytes;
  int _pendingBytes = 0;

  /// Maximum output frames polled in one Dart drain pass.
  final int batchSize;
  late final SessionTransport _transport;

  /// Backend for application-specific adapters. Its lifetime belongs to this session.
  SessionTransport get transport => _transport;

  /// Cancels host-owned work when this session begins shutdown.
  final CancellationScope cancellation = CancellationScope();

  /// Releases host registrations before runtime storage is freed.
  final CleanupScope cleanup = CleanupScope();
  final _pending = <int, _PendingCall>{};
  final _active = <_PendingCall>{};
  final _callbacks = <int, FutureOr<Uint8List> Function(Uint8List)>{};
  int _nextCallback = 1;
  final _signals = SignalBus<NativeSignal>(
    sizeOf: (signal) => signal.bytes.length,
  );
  final _ownedSignals = SignalBus<OwnedNativeSignal>(
    sizeOf: (signal) => signal.buffer.length,
    retain: (signal) => signal.retain(),
    release: (signal) => signal.dispose(),
  );

  /// Native frames with explicit per-listener leases; dispose every received value.
  /// Web frames are copied out of Wasm before this stream receives them.
  Stream<OwnedNativeSignal> get ownedSignals => _ownedSignals.stream;
  Completer<void> _capacity = Completer<void>();
  bool _closed = false;
  bool _drainScheduled = false;
  Future<void>? _closeFuture;

  /// Broadcast events with a bounded backlog for each paused subscription.
  ///
  /// Events are not replayed to new listeners. A paused subscription exceeding
  /// 64 frames or 1 MiB receives `signal_overflow` and closes. Other listeners
  /// continue. Payloads are shared; treat them as read-only. Keep handlers short.
  ///
  /// {@example /example/runtime_features_example/demo/toolkit.dart#typed-signals}
  Stream<NativeSignal> get signals => _signals.stream;

  /// Whether shutdown has started; native cleanup may still be in progress.
  bool get isClosed => _closed;

  /// Structured, best-effort native logs. Oversized/full native log messages drop.
  Stream<NativeLog> get logs =>
      signals.where((event) => event.route == 0xfffffff0).map((event) {
        final reader = BinaryReader(event.bytes);
        final value = NativeLog(reader.u8(), reader.string(), reader.string());
        reader.finish();
        return value;
      });

  /// Best-effort failures from one-way native handlers, scoped by input route.
  /// Admission success cannot guarantee a later handler succeeds.
  Stream<NativeException> get signalErrors =>
      signals.where((event) => event.route == 0xfffffff1).map((event) {
        final reader = BinaryReader(event.bytes);
        final route = reader.u32();
        final message = reader.string();
        reader.finish();
        return NativeException('signal_failed', message, operation: route);
      });

  /// Live buffers in this session's native asset or transport.
  int get liveBuffers => _transport.liveBuffers;

  /// Allocated buffer capacity in this session's native asset or transport.
  int get liveBufferBytes => _transport.liveBufferBytes;

  /// A snapshot of transport activity and queue occupancy.
  ///
  /// Throws [NativeException] after shutdown starts.
  SessionStats get stats {
    _ensureOpen();
    final value = _transport.stats;
    return SessionStats(
      value.submitted,
      value.delivered,
      value.wakes,
      value.copiedBytes,
      value.inputMessages,
      value.outputMessages,
      value.inputBytes,
      value.outputBytes,
      logDrops: value.logDrops,
    );
  }

  void _ensureOpen() {
    if (_closed) throw const NativeException('closed', 'Session is closed');
  }

  void _signalCapacity() {
    final previous = _capacity;
    _capacity = Completer<void>();
    previous.complete();
  }

  /// Admits a one-way signal; completion does not acknowledge native processing.
  ///
  /// Waiting payloads share the session's count and byte budgets. [timeout]
  /// covers admission only. Closing the session rejects waiters.
  Future<void> sendSignal(
    int route,
    Uint8List bytes, {
    Duration? timeout,
  }) async {
    _ensureOpen();
    if (route < 0 ||
        route > 0xffffffff ||
        (timeout != null && timeout <= Duration.zero)) {
      throw ArgumentError('Invalid signal route or timeout');
    }
    if (bytes.length > maxBytes) {
      throw const NativeException('too_large', 'Signal exceeds byte budget');
    }
    if (_active.length + _signalWaiters >= maxPending ||
        bytes.length > maxPendingBytes - _pendingBytes) {
      throw const NativeException('busy', 'Signal admission budget exhausted');
    }
    final copy = Uint8List.fromList(bytes);
    _signalWaiters++;
    _pendingBytes += copy.length;
    final watch = Stopwatch()..start();
    try {
      while (true) {
        _ensureOpen();
        final status = _transport.sendSignal(route, copy);
        if (status == 0) return;
        if (status != 1) {
          throw NativeException(
            'submit_$status',
            'Signal rejected',
            operation: route,
          );
        }
        if (timeout == null) {
          await _capacity.future;
        } else {
          final remaining = timeout - watch.elapsed;
          if (remaining <= Duration.zero) {
            throw const NativeException('deadline', 'Signal admission expired');
          }
          try {
            await _capacity.future.timeout(remaining);
          } on TimeoutException {
            throw const NativeException('deadline', 'Signal admission expired');
          }
        }
      }
    } finally {
      _signalWaiters--;
      _pendingBytes -= copy.length;
    }
  }

  int _signalWaiters = 0;

  /// Starts a call without blocking Dart on native work.
  ///
  /// [timeout] covers admission and execution. At most [maxPending] operations
  /// may exist, including operations waiting for native queue capacity.
  /// Copies [bytes] before returning. [route] must fit an unsigned 32-bit ID.
  /// [signal] selects a signal input frame; normal generated calls leave it false.
  ///
  /// Throws [ArgumentError] for invalid route/timeout and [NativeException] for
  /// closed sessions, excessive payloads, or exhausted Dart admission budgets.
  /// Native failures and cancellation complete [NativeCall.result] with errors.
  NativeCall call(
    int route,
    Uint8List bytes, {
    Duration? timeout,
    bool signal = false,
  }) {
    final pending = _begin(route, bytes, timeout: timeout, signal: signal);
    return NativeCall(
      pending.completer.future,
      () => _cancel(pending, 'cancelled', 'Call cancelled'),
    );
  }

  /// Starts a call whose result transfers native buffer ownership to Dart.
  ///
  /// Admission and timeout behavior match [call]. Dispose the returned
  /// [NativeBuffer] even after this session closes. The input still copies;
  /// only the final result payload copy into Dart memory is avoided.
  ///
  /// {@example /example/runtime_features_example/demo/toolkit.dart#owned-buffer}
  NativeBufferCall callBuffer(int route, Uint8List bytes, {Duration? timeout}) {
    final pending = _begin(route, bytes, timeout: timeout, ownedBuffer: true);
    return NativeBufferCall(
      pending.nativeBuffer!.future,
      () => _cancel(pending, 'cancelled', 'Call cancelled'),
    );
  }

  _PendingCall _begin(
    int route,
    Uint8List bytes, {
    Duration? timeout,
    bool signal = false,
    StreamController<Uint8List>? stream,
    bool ownedBuffer = false,
  }) {
    _ensureOpen();
    if (route < 0 || route > 0xffffffff) {
      throw ArgumentError.value(route, 'route');
    }
    if (timeout != null && timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout');
    }
    if (_active.length + _signalWaiters >= maxPending) {
      throw const NativeException('busy', 'Session pending-call limit reached');
    }
    if (bytes.length > maxBytes) {
      throw const NativeException(
        'too_large',
        'Payload exceeds session byte limit',
      );
    }
    if (bytes.length > maxPendingBytes - _pendingBytes) {
      throw const NativeException(
        'busy',
        'Pending Dart payload budget exceeded',
      );
    }
    final pending = _PendingCall(route)
      ..timeout = timeout
      ..stream = stream
      ..input = Uint8List.fromList(bytes);
    _pendingBytes += bytes.length;
    if (ownedBuffer) {
      pending.nativeBuffer = Completer<NativeBuffer>();
      unawaited(
        pending.completer.future.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        ),
      );
    }
    _active.add(pending);
    _trace("started", route: route, bytes: bytes.length);
    if (timeout != null) {
      pending.timer = Timer(
        timeout,
        () => _cancel(pending, 'deadline', 'Call deadline expired'),
      );
    }
    unawaited(_submit(pending, signal));
    return pending;
  }

  /// Creates a single-subscription stream with native production credits.
  ///
  /// Admission, the input snapshot, and [timeout] start when listening begins.
  /// Do not mutate [bytes] before subscribing. Pausing withholds further credits;
  /// one item may already be in flight. Cancellation invalidates the native task.
  /// Continuation-based producers release their worker while paused. Errors are delivered on the
  /// stream, except calling this method on a closed session throws immediately.
  ///
  /// {@example /example/runtime_features_example/demo/toolkit.dart#typed-stream}
  Stream<Uint8List> stream(int route, Uint8List bytes, {Duration? timeout}) {
    _ensureOpen();
    _PendingCall? pending;
    late StreamController<Uint8List> controller;
    controller = StreamController<Uint8List>(
      sync: true,
      onListen: () {
        try {
          pending = _begin(route, bytes, timeout: timeout, stream: controller);
          // Stream completion is reported by the controller, not this future.
          unawaited(
            pending!.completer.future.then<void>(
              (_) {},
              onError: (Object _, StackTrace _) {},
            ),
          );
        } catch (error, stack) {
          controller.addError(error, stack);
          unawaited(controller.close());
        }
      },
      onPause: () {
        pending?.paused = true;
      },
      onResume: () {
        final call = pending;
        if (call == null || call.finished) return;
        call.paused = false;
        final item = call.heldItem;
        call.heldItem = null;
        if (item != null) _deliverItem(call, item);
        _grant(call);
      },
      onCancel: () {
        final call = pending;
        if (call != null && !call.finished) {
          _cancel(call, 'cancelled', 'Stream subscription cancelled');
        }
      },
    );
    return controller.stream;
  }

  void _grant(_PendingCall pending) {
    if (_closed ||
        pending.finished ||
        pending.paused ||
        pending.credit ||
        pending.id == null) {
      return;
    }
    final status = _grantCredit(pending.id!);
    if (status == 0) pending.credit = true;
  }

  void _deliverItem(_PendingCall pending, Uint8List bytes) {
    pending.credit = false;
    if (pending.paused) {
      pending.heldItem = bytes;
      return;
    }
    pending.stream!.add(bytes);
    _grant(pending);
  }

  void _releaseInput(_PendingCall pending) {
    final input = pending.input;
    if (input != null) {
      _pendingBytes -= input.length;
      pending.input = null;
    }
  }

  int _trySubmit(_PendingCall pending, bool signal) {
    final admitted = _transport.submit(
      pending.route,
      pending.stream != null ? 10 : (signal ? 2 : 0),
      pending.input!,
      pending.timeout == null
          ? 0
          : ((pending.timeout! - pending.elapsed.elapsed).inMicroseconds * 1000)
                .clamp(1, 9007199254740991),
    );
    final status = admitted.status;
    if (status == 0) {
      pending.id = admitted.id;
      _trace("admitted", route: pending.route, id: admitted.id);
      _pending[admitted.id] = pending;
      _releaseInput(pending);
      if (pending.stream != null) _grant(pending);
    }
    return status;
  }

  Future<void> _submit(_PendingCall pending, bool signal) async {
    try {
      while (!pending.finished && !_closed) {
        final status = _trySubmit(pending, signal);
        if (status == 0) return;
        if (status != 1) {
          throw NativeException(
            'submit_$status',
            'Native admission failed',
            operation: pending.route,
          );
        }
        _trace("backpressure", route: pending.route);
        await _capacity.future;
      }
    } catch (error, stack) {
      _fail(pending, error, stack);
    }
  }

  void _finish(_PendingCall pending) {
    pending.finished = true;
    _releaseInput(pending);
    pending.timer?.cancel();
    _active.remove(pending);
    if (pending.id != null) _pending.remove(pending.id);
  }

  void _fail(_PendingCall pending, Object error, [StackTrace? stack]) {
    if (pending.finished) return;
    _trace("failed", route: pending.route, id: pending.id, error: error);
    _finish(pending);
    pending.completer.completeError(error, stack);
    pending.nativeBuffer?.completeError(error, stack);
    final stream = pending.stream;
    if (stream != null) {
      pending.heldItem = null;
      scheduleMicrotask(() {
        if (!stream.isClosed) {
          stream.addError(error, stack);
          unawaited(stream.close());
        }
      });
    }
  }

  void _cancel(_PendingCall pending, String code, String message) {
    if (pending.finished) return;
    if (!_closed && pending.id != null) {
      _transport.cancel(pending.id!);
    }
    _fail(
      pending,
      NativeException(
        code,
        message,
        operation: pending.route,
        requestId: pending.id,
      ),
    );
    _signalCapacity();
  }

  /// Registers a Dart callback and returns its session-local identifier.
  ///
  /// The callback may await other native calls. Its input is Dart-owned;
  /// its result is copied into the native reply. Thrown errors become callback
  /// failures. Call [unregisterCallback] when the registration is no longer used.
  /// Closing the session removes registrations but cannot stop running Dart code.
  ///
  /// Generated scoped helpers register and unregister automatically:
  /// {@example /example/runtime_features_example/demo/toolkit.dart#typed-callback}
  int registerCallback(FutureOr<Uint8List> Function(Uint8List) callback) {
    _ensureOpen();
    if (_nextCallback > 0xffffffff) throw StateError('Callback IDs exhausted');
    final id = _nextCallback++;
    _callbacks[id] = callback;
    return id;
  }

  /// Removes a registration; unknown IDs are ignored.
  ///
  /// Already-running callbacks continue. Future invocations fail as unknown.
  void unregisterCallback(int id) {
    _callbacks.remove(id);
  }

  Future<void> _invokeCallback(
    int requestId,
    int callbackId,
    Uint8List bytes,
  ) async {
    var code = 0;
    Uint8List reply;
    try {
      final callback = _callbacks[callbackId];
      if (callback == null) {
        throw StateError('Callback $callbackId is not registered');
      }
      reply = await callback(bytes);
      if (reply.length > maxBytes) {
        throw StateError('Callback reply is too large');
      }
    } catch (error) {
      code = 1;
      reply = Uint8List.fromList(utf8.encode(error.toString()));
      if (reply.length > maxBytes) reply = Uint8List(0);
    }
    while (!_closed && _pending.containsKey(requestId)) {
      final status = _transport.callbackReply(
        requestId,
        callbackId,
        code,
        reply,
      );
      if (status == 0 || status == 3 || status == 2) return;
      if (status != 1) {
        final pending = _pending[requestId];
        if (pending != null) {
          _cancel(pending, 'callback_$status', 'Callback delivery failed');
        }
        return;
      }
      await _capacity.future;
    }
  }

  void _drain() {
    if (_closed) return;
    final frames = _transport.poll(batchSize);
    final count = frames.length;
    final messages =
        <
          ({
            int id,
            int route,
            int kind,
            int code,
            Uint8List bytes,
            NativeBuffer? buffer,
          })
        >[];
    try {
      for (final frame in frames) {
        final owned =
            (frame.kind == 1 && _pending[frame.id]?.nativeBuffer != null) ||
            frame.kind == 2;
        messages.add((
          id: frame.id,
          route: frame.route,
          kind: frame.kind,
          code: frame.code,
          bytes: owned ? Uint8List(0) : frame.buffer.copy(),
          buffer: owned ? frame.buffer.retain() : null,
        ));
      }
    } finally {
      for (final frame in frames) {
        frame.buffer.dispose();
      }
    }
    for (final frame in messages) {
      if (_closed) {
        frame.buffer?.dispose();
        continue;
      }
      if (frame.kind == 2) {
        final signal = OwnedNativeSignal(frame.route, frame.buffer!);
        try {
          _trace("signal", route: frame.route, bytes: signal.buffer.length);
          if (_signals.hasListeners) {
            _signals.add(NativeSignal(frame.route, signal.buffer.copy()));
          }
          _ownedSignals.add(signal);
        } finally {
          signal.dispose();
        }
      } else if (frame.kind == 7) {
        unawaited(_invokeCallback(frame.id, frame.route, frame.bytes));
      } else {
        final pending = _pending[frame.id];
        if (pending == null) {
          frame.buffer?.dispose();
          continue;
        }
        if (frame.kind == 5) {
          _fail(
            pending,
            NativeException(
              frame.code == 2 ? 'deadline' : 'native_${frame.code}',
              utf8.decode(frame.bytes, allowMalformed: true),
              operation: pending.route,
              requestId: frame.id,
            ),
          );
        } else if (frame.kind == 3 && pending.stream != null) {
          _deliverItem(pending, frame.bytes);
        } else if (frame.kind == 1 || frame.kind == 4) {
          _trace(
            "completed",
            route: pending.route,
            id: pending.id,
            bytes: frame.bytes.length,
          );
          _finish(pending);
          pending.completer.complete(frame.bytes);
          if (pending.nativeBuffer != null) {
            pending.nativeBuffer!.complete(frame.buffer!);
          }
          if (pending.stream != null) unawaited(pending.stream!.close());
        } else {
          _cancel(pending, 'protocol', 'Unexpected native frame ${frame.kind}');
        }
      }
    }
    if (_closed) return;
    if (_transport.stopped) {
      unawaited(close());
      return;
    }
    if (count == batchSize && !_drainScheduled) {
      _drainScheduled = true;
      Timer.run(() {
        _drainScheduled = false;
        _drain();
      });
    }
  }

  /// Stops admission and asynchronously waits for cooperative workers to exit.
  ///
  /// The Dart isolate remains responsive while native handlers finish. Pending
  /// calls fail with `closed`; queued results are discarded. Calls are not drained
  /// gracefully. Await desired work before closing. Remaining native objects are
  /// destroyed; already-returned [NativeBuffer] instances keep their ownership.
  ///
  /// Repeated calls return the same future. [stopExternal] runs before storage
  /// is freed; its failure retains storage and remains the close future's error.
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _closed = true;
    cancellation.cancel();
    _transport.stop();
    for (final pending in _active.toList()) {
      _fail(pending, const NativeException('closed', 'Session closed'));
    }
    _signalCapacity();
    _transport.onWake = null;
    _callbacks.clear();
    _signals.close();
    _ownedSignals.close();
    final failures = <({Object error, StackTrace stack})>[];
    try {
      await cleanup.close();
    } catch (error, stack) {
      failures.add((error: error, stack: stack));
    }
    try {
      await stopExternal?.call();
    } catch (error, stack) {
      failures.add((error: error, stack: stack));
    }
    if (failures.isNotEmpty) throw CleanupException(failures);
    await _destroyTransport();
  }

  Future<void> _destroyTransport() async {
    while (!_transport.readyToDestroy) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    _transport.destroy();
  }

  int _grantCredit(int id) {
    _transport.grant(id);
    return 0;
  }
}
