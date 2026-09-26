import 'models.dart';

import 'package:dart_zig/dart_zig.dart' show NativeException;

/// Example stateful native object using a generation-checked opaque handle.
///
/// {@example /demo/toolkit.dart#native-object}
///
/// The session releases remaining objects on shutdown; dispose releases early.
final class NativeCounter {
  NativeCounter._(this._api, this._handle);
  final FeatureApi _api;
  final int _handle;
  Future<void>? _disposal;

  /// Creates a counter owned by the session behind [api].
  ///
  /// [initial] is its signed 64-bit starting value.
  static Future<NativeCounter> open(FeatureApi api, {int initial = 0}) async =>
      NativeCounter._(
        api,
        await api.counterCreate(CounterCreate(initial: initial)),
      );

  /// Atomically adds [delta] and returns the new signed 64-bit value.
  ///
  /// Throws [NativeException] after disposal or session shutdown. Native overflow
  /// and stale-handle failures complete the returned future with an error.
  Future<int> add(int delta) {
    if (_disposal != null || _api.session.isClosed) {
      throw const NativeException('disposed', 'Counter has been disposed');
    }
    return _api.counterAdd(CounterAdd(handle: _handle, delta: delta));
  }

  /// Removes the native handle early; repeated calls share one future.
  ///
  /// In-flight native leases may finish before the object is freed. After
  /// session shutdown, cleanup belongs to the session and this is a no-op.
  Future<void> dispose() => _disposal ??= _api.session.isClosed
      ? Future<void>.value()
      : _api.counterDispose(HandleArgs(handle: _handle));
}
