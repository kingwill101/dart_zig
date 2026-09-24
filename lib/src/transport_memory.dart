import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'cleanup.dart';
import 'codec.dart';
import 'native_buffer.dart';
import 'transport.dart';

/// Application handler for deterministic consumers without FFI or Wasm.
///
/// Complete or fail calls, emit a credited stream, or await [MemoryContext.callback].
/// Observe cancellation in long-running work. One-way signals have no result.
typedef MemoryHandler = FutureOr<void> Function(
  MemoryContext context,
  Uint8List bytes,
);

/// Bounded in-process implementation of the session protocol.
///
/// Supply the generated schema fingerprint and application behavior. This is an
/// injectable transport for examples, previews, and fakes, not a Zig emulator.
final class MemoryTransport implements SessionTransport {
  MemoryTransport({
    required this.schemaFingerprint,
    required this.handler,
    this.maxMessages = 256,
    this.maxBytes = 8 * 1024 * 1024,
    this.maxTasks = 256,
  }) {
    if (maxMessages <= 0 || maxBytes <= 0 || maxTasks <= 0) {
      throw ArgumentError('Invalid memory transport limits');
    }
  }
  final MemoryHandler handler;
  final int maxMessages, maxBytes, maxTasks;
  @override
  final int schemaFingerprint;
  @override
  int get protocolVersion => 2;
  @override
  void Function()? onWake;
  final _tasks = <int, MemoryContext>{};
  final _signals = <MemoryContext>{};
  final _output = ListQueue<TransportFrame>();
  Completer<void> _capacity = Completer<void>();
  bool _closed = false, _scheduled = false;
  int _next = 1, _outputBytes = 0, _inputBytes = 0, _inputs = 0;
  int _submitted = 0, _delivered = 0, _copied = 0, _wakes = 0;
  void _wake() {
    if (_scheduled || _closed) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (!_closed) {
        _wakes++;
        onWake?.call();
      }
    });
  }

  void _capacityChanged() {
    final prior = _capacity;
    _capacity = Completer<void>();
    prior.complete();
    _wake();
  }

  int _admission(Uint8List bytes) {
    if (_closed) return 2;
    if (bytes.length > maxBytes) return 5;
    if (_inputs >= maxMessages ||
        _tasks.length + _signals.length >= maxTasks ||
        bytes.length > maxBytes - _inputBytes) {
      return 1;
    }
    return 0;
  }

  @override
  ({int status, int id}) submit(
    int route,
    int kind,
    Uint8List bytes,
    int timeoutNs,
  ) {
    if (kind != 0 && kind != 2 && kind != 10) return (status: 3, id: 0);
    final status = _admission(bytes);
    if (status != 0) return (status: status, id: 0);
    final context = MemoryContext._(this, _next++, route, kind == 10, false);
    _tasks[context.id] = context;
    _dispatch(context, bytes);
    return (status: 0, id: context.id);
  }

  @override
  int sendSignal(int route, Uint8List bytes) {
    final status = _admission(bytes);
    if (status != 0) return status;
    final context = MemoryContext._(this, 0, route, false, true);
    _signals.add(context);
    _dispatch(context, bytes);
    return 0;
  }

  void _dispatch(MemoryContext context, Uint8List bytes) {
    final copy = Uint8List.fromList(bytes);
    _inputs++;
    _inputBytes += bytes.length;
    _submitted++;
    _copied += bytes.length;
    scheduleMicrotask(() async {
      _inputs--;
      _inputBytes -= copy.length;
      _capacityChanged();
      try {
        context.cancellation.check();
        await handler(context, copy);
        if (!context.isSignal &&
            !context._finished &&
            !context.cancellation.isCancelled) {
          await context.fail('Handler returned without completing its call');
        }
      } catch (error) {
        if (!context._finished &&
            !context.cancellation.isCancelled &&
            !_closed &&
            !context.isSignal) {
          try {
            await context.fail(error.toString());
          } catch (_) {
            /* cancelled while reporting */
          }
        }
        if (context.isSignal && !context.cancellation.isCancelled && !_closed) {
          final writer = BinaryWriter()
            ..u32(context.route)
            ..string(error.toString());
          try {
            await _emit(context, 2, 0xfffffff1, 0, writer.finish());
          } catch (_) {
            /* diagnostic budget exhausted */
          }
        }
      } finally {
        if (context.isSignal) {
          _signals.remove(context);
          _capacityChanged();
        }
      }
    });
  }

  Future<void> _emit(
    MemoryContext context,
    int kind,
    int route,
    int code,
    Uint8List bytes,
  ) async {
    if (bytes.length > maxBytes) {
      throw RangeError('Output exceeds transport byte budget');
    }
    while (true) {
      context.cancellation.check();
      if (_closed) throw StateError('Transport stopped');
      if (_output.length < maxMessages &&
          bytes.length <= maxBytes - _outputBytes) {
        break;
      }
      await _capacity.future;
    }
    _output.add(
      TransportFrame(
        context.id,
        route,
        kind,
        code,
        NativeBuffer.fromBytes(bytes),
      ),
    );
    _outputBytes += bytes.length;
    _copied += bytes.length;
    _wake();
  }

  @override
  int callbackReply(int id, int callbackId, int code, Uint8List bytes) {
    if (_closed) return 2;
    final task = _tasks[id];
    if (task == null || task._reply == null || task._callbackId != callbackId) {
      return 3;
    }
    if (bytes.length > maxBytes) return 5;
    final reply = task._reply!;
    task._reply = null;
    if (code == 0) {
      reply.complete(Uint8List.fromList(bytes));
    } else {
      reply.completeError(StateError(utf8.decode(bytes, allowMalformed: true)));
    }
    _submitted++;
    _copied += bytes.length;
    return 0;
  }

  @override
  void cancel(int id) {
    final context = _tasks.remove(id);
    context?._cancel();
    _capacityChanged();
  }

  @override
  void grant(int id) {
    final context = _tasks[id];
    if (context != null && !context._credit.isCompleted) {
      context._credit.complete();
    }
  }

  @override
  List<TransportFrame> poll(int capacity) {
    final frames = <TransportFrame>[];
    while (frames.length < capacity && _output.isNotEmpty) {
      final frame = _output.removeFirst();
      _outputBytes -= frame.buffer.length;
      frames.add(frame);
      _delivered++;
    }
    if (frames.isNotEmpty) _capacityChanged();
    return frames;
  }

  @override
  TransportStats get stats => TransportStats(
    submitted: _submitted,
    delivered: _delivered,
    copiedBytes: _copied,
    wakes: _wakes,
    inputMessages: _inputs,
    inputBytes: _inputBytes,
    outputMessages: _output.length,
    outputBytes: _outputBytes,
  );
  @override
  bool get stopped => _closed;
  @override
  bool get readyToDestroy => _closed;
  @override
  void stop() {
    if (_closed) return;
    _closed = true;
    for (final context in [..._tasks.values, ..._signals]) {
      context._cancel();
    }
    _tasks.clear();
    _signals.clear();
    _capacityChanged();
  }

  @override
  void destroy() {
    stop();
    onWake = null;
    while (_output.isNotEmpty) {
      _output.removeFirst().buffer.dispose();
    }
    _outputBytes = 0;
  }
}

/// One in-process invocation, with the same result and credit rules as Zig.
final class MemoryContext {
  MemoryContext._(
    this._transport,
    this.id,
    this.route,
    this.isStream,
    this.isSignal,
  );
  final MemoryTransport _transport;
  final int id, route;
  final bool isStream, isSignal;
  final cancellation = CancellationScope();
  bool _finished = false, _completing = false;
  Completer<void> _credit = Completer<void>();
  Completer<Uint8List>? _reply;
  int? _callbackId;
  void _cancel() {
    cancellation.cancel();
    if (!_credit.isCompleted) _credit.complete();
    _reply?.completeError(
      const CancelledException('Transport cancelled callback'),
    );
    _reply = null;
  }

  Future<void> _terminal(int kind, int code, Uint8List bytes) async {
    if (isSignal) throw StateError('One-way signals have no result');
    if (_finished || _completing) throw StateError('Call already completing');
    _completing = true;
    try {
      await _transport._emit(this, kind, route, code, bytes);
      _finished = true;
      _transport._tasks.remove(id);
      _transport._capacityChanged();
    } finally {
      _completing = false;
    }
  }

  Future<void> complete(Uint8List bytes) => _terminal(1, 0, bytes);
  Future<void> fail(String message) {
    final bytes = Uint8List.fromList(utf8.encode(message));
    return _terminal(
      5,
      1,
      bytes.length <= _transport.maxBytes ? bytes : Uint8List(0),
    );
  }

  Future<void> signal(int route, Uint8List bytes) =>
      _transport._emit(this, 2, route, 0, bytes);
  Future<void> item(Uint8List bytes) async {
    if (!isStream) throw StateError('Not a streaming operation');
    await _credit.future;
    cancellation.check();
    _credit = Completer<void>();
    await _transport._emit(this, 3, route, 0, bytes);
  }

  Future<void> end() async {
    if (!isStream) throw StateError('Not a streaming operation');
    await _credit.future;
    cancellation.check();
    await _terminal(4, 0, Uint8List(0));
  }

  Future<Uint8List> callback(int callbackId, Uint8List bytes) async {
    if (isSignal || _reply != null) throw StateError('Invalid callback state');
    final reply = Completer<Uint8List>();
    _reply = reply;
    _callbackId = callbackId;
    // Install the error listener before emission can yield to cancellation.
    final result = reply.future;
    unawaited(result.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    try {
      await _transport._emit(this, 7, callbackId, 0, bytes);
      return await result;
    } finally {
      _reply = null;
      _callbackId = null;
    }
  }
}
