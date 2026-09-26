import 'dart:js_interop';

import 'package:dart_zig/dart_zig.dart' show NativeSession, NativeException;
import 'package:dart_zig/web.dart' show WebTransport;

@JS()
extension type _FeatureWasmApi(JSObject _) implements JSObject {
  @JS('dz_web_sum')
  external double sum(double a, double b);
}

int sumSync(NativeSession session, int a, int b) {
  if (session.isClosed) throw const NativeException('closed', 'Session closed');
  final backend = session.transport;
  if (backend is! WebTransport) {
    throw UnsupportedError(
      'This transport does not provide synchronous Wasm calls',
    );
  }
  final result = _FeatureWasmApi(backend.api).sum(a.toDouble(), b.toDouble());
  if (!result.isFinite) {
    throw const NativeException('sync_error', 'Native sum failed');
  }
  return result.toInt();
}
