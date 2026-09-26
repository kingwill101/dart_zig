import 'dart:async';

import 'codec.dart';
import 'session.dart';

/// A typed callback registration owned by one native session.
final class CallbackRegistration {
  CallbackRegistration._(this._session, this.id) {
    _detach = _session.cleanup.defer(dispose);
  }

  final NativeSession _session;

  /// Session-local ID passed to a Zig handler that requests this callback.
  final int id;

  late final void Function() _detach;
  bool _disposed = false;

  /// Stops future callback invocations. Running callbacks may finish.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _detach();
    _session.unregisterCallback(id);
  }
}

/// Registers callbacks using generated or application-defined codecs.
extension TypedSessionCallbacks on NativeSession {
  /// Converts callback input and output while keeping the byte protocol hidden.
  CallbackRegistration registerTypedCallback<I, O>(
    FutureOr<O> Function(I) callback, {
    required MessageDecoder<I> input,
    required MessageEncoder<O> output,
  }) {
    final id = registerCallback((bytes) async {
      final value = input.decode(bytes);
      return output.encode(await callback(value));
    });
    return CallbackRegistration._(this, id);
  }
}
