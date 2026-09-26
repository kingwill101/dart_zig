import 'generated/generated.dart';

/// Owns one session-local Zig counter handle.
final class NativeCounter {
  NativeCounter._(this._api, this._handle);

  final ProtocolApi _api;
  final int _handle;
  bool _closed = false;

  /// Allocates a counter in the given session.
  static Future<NativeCounter> open(NativeSession session, int initial) async {
    final api = ProtocolApi(session);
    return NativeCounter._(api, await api.createCounter(initial));
  }

  /// Adds to the counter and returns its new value.
  Future<int> add(int delta) {
    if (_closed) throw StateError('Counter is closed');
    return _api.addCounter((handle: _handle, delta: delta));
  }

  /// Releases the Zig handle before closing its session.
  Future<void> close() async {
    if (_closed) return;
    await _api.releaseCounter(_handle);
    _closed = true;
  }
}
