import 'dart:async';
import 'dart:typed_data';

import 'codec.dart';
import 'native_buffer.dart';
import 'session.dart';
import 'signal_bus.dart';

/// A typed message and an independently owned binary attachment.
///
/// Each listener owns its pack. Dispose it after use, or retain another lease.
final class SignalPack<T> {
  SignalPack(this.message, this.attachment);
  final T message;
  final NativeBuffer attachment;
  SignalPack<T> retain() => SignalPack(message, attachment.retain());
  void dispose() => attachment.dispose();
}

/// A session-scoped, typed bidirectional endpoint.
///
/// Sending completes on queue admission, not application processing. Use a
/// generated call for processing acknowledgment. Close the endpoint to detach
/// its subscription; the session also closes it during cleanup.
final class SignalEndpoint<T> {
  SignalEndpoint(
    this.session,
    this.route,
    this.codec, {
    bool state = false,
    int maxMessages = 64,
    int maxBytes = 1048576,
    OverflowPolicy overflow = OverflowPolicy.error,
  }) : _bus = SignalBus<SignalPack<T>>(
         sizeOf: (pack) =>
             codec.encode(pack.message).length + pack.attachment.length,
         maxMessages: maxMessages,
         maxBytes: maxBytes,
         overflow: state ? OverflowPolicy.latest : overflow,
         replayLatest: state,
         retain: (pack) => pack.retain(),
         release: (pack) => pack.dispose(),
       ) {
    _subscription = session.ownedSignals.listen(
      (event) {
        if (event.route != route) {
          event.dispose();
          return;
        }
        try {
          final reader = BinaryReader(event.buffer.view);
          final message = codec.decode(reader.bytes());
          final bytes = reader.bytes();
          reader.finish();
          final start = bytes.offsetInBytes - event.buffer.view.offsetInBytes;
          final pack = SignalPack(
            message,
            event.buffer.slice(start, start + bytes.length),
          );
          try {
            _bus.add(pack);
          } finally {
            pack.dispose();
          }
        } catch (error) {
          if (!_closed) _errors.add(error);
        } finally {
          event.dispose();
        }
      },
      onError: (Object error, StackTrace stack) {
        _errors.add(error);
      },
    );
    _failureSubscription = session.signalErrors
        .where((error) => error.operation == route)
        .listen((error) {
          if (!_closed) _errors.add(error);
        });
    _detach = session.cleanup.defer(close);
  }
  final NativeSession session;
  final int route;
  final BinaryCodec<T> codec;
  final SignalBus<SignalPack<T>> _bus;
  late final StreamSubscription<OwnedNativeSignal> _subscription;
  late final void Function() _detach;
  late final StreamSubscription<Object> _failureSubscription;
  final _errors = StreamController<Object>.broadcast();
  bool _closed = false;
  Stream<SignalPack<T>> get stream => _bus.stream;
  Stream<Object> get errors => _errors.stream;
  SignalPack<T>? get latest => _bus.latest;
  int get dropped => _bus.overflowCount;
  Future<void> send(T message, {Uint8List? binary, Duration? timeout}) {
    if (_closed) throw StateError('Signal endpoint is closed');
    final writer = BinaryWriter(maxBytes: session.maxBytes);
    writer.bytes(codec.encode(message));
    writer.bytes(binary ?? Uint8List(0));
    return session.sendSignal(route, writer.finish(), timeout: timeout);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _detach();
    await _subscription.cancel();
    await _failureSubscription.cancel();
    _bus.close();
    unawaited(_errors.close());
  }
}
