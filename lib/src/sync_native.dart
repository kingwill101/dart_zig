import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'transport_native.dart';
import 'session.dart';
import 'runtime_error.dart';

int sumSync(NativeSession session, int a, int b) {
  if (session.isClosed) throw const NativeException('closed', 'Session closed');
  final backend = session.transport;
  if (backend is! NativeTransport) {
    throw UnsupportedError(
      'This transport does not provide synchronous native calls',
    );
  }
  final output = calloc<Int64>();
  try {
    if (backend.bindings.dz_sync_sum(a, b, output) != 0) {
      throw const NativeException('sync_error', 'Native sum failed');
    }
    return output.value;
  } finally {
    calloc.free(output);
  }
}
