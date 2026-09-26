import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:dart_zig/dart_zig.dart' show NativeException, NativeSession;
import 'package:dart_zig/native.dart' show NativeTransport;

import 'ffi_app.g.dart' as native;

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
    if (native.dz_sync_sum(a, b, output) != 0) {
      throw const NativeException('sync_error', 'Native sum failed');
    }
    return output.value;
  } finally {
    calloc.free(output);
  }
}
