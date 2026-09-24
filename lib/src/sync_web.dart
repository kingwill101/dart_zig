import 'session.dart';
import 'runtime_error.dart';
import 'transport_web.dart';

int sumSync(NativeSession session, int a, int b) {
  if (session.isClosed) throw const NativeException('closed', 'Session closed');
  final backend = session.transport;
  if (backend is! WebTransport) {
    throw UnsupportedError(
      'This transport does not provide synchronous Wasm calls',
    );
  }
  return webSum(a, b, api: backend.api);
}
