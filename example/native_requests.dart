import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:dart_zig/dart_zig.dart';
import 'package:ffi/ffi.dart';

import '../bin/demo.g.dart' as demo;

void consumeReply(NativeBridge bridge, int id, ReplyKind kind, String text) {
  final bytes = utf8.encode(text);
  final pointer = calloc<Uint8>(bytes.isEmpty ? 1 : bytes.length);
  try {
    pointer.asTypedList(bytes.length).setAll(0, bytes);
    if (!demo.dz_demo_consume(
      bridge.nativeHandle.cast(),
      id,
      kind.index + 1,
      pointer,
      bytes.length,
    )) {
      throw StateError('Native reply did not match $kind / $text');
    }
  } finally {
    calloc.free(pointer);
  }
}

Future<void> main() async {
  // #region native-requests
  final bridge = NativeBridge(maxMessages: 1, maxBytes: 1024);
  try {
    final id = demo.dz_demo_submit(bridge.nativeHandle.cast());
    if (id == 0) throw StateError('Native submission failed');
    final request = (await bridge.nextRequest())!;
    print('Native request $id: ${utf8.decode(request.bytes)}');
    await request.add(Uint8List.fromList(utf8.encode('Hello from Dart')));

    // The one-slot reply queue is full. Completion waits for native consumption.
    final finished = request.finish();
    consumeReply(bridge, id, ReplyKind.chunk, 'Hello from Dart');
    await finished;
    consumeReply(bridge, id, ReplyKind.end, '');
    print('Zig consumed the streamed reply and completion.');

    final cancelledId = demo.dz_demo_submit(bridge.nativeHandle.cast());
    final cancelled = (await bridge.nextRequest())!;
    await cancelled.cancel();
    consumeReply(bridge, cancelledId, ReplyKind.cancelled, '');
    print('Zig observed cancellation.');

    final nativeCancelledId = demo.dz_demo_submit(bridge.nativeHandle.cast());
    final nativeCancelled = (await bridge.nextRequest())!;
    await nativeCancelled.add(Uint8List.fromList([1, 2, 3]));
    final blocked = nativeCancelled.finish();
    if (!demo.dz_demo_cancel(bridge.nativeHandle.cast(), nativeCancelledId)) {
      throw StateError('Native cancellation failed');
    }
    try {
      await blocked;
      throw Exception('Cancelled write unexpectedly succeeded');
    } on StateError {
      if (!nativeCancelled.isCancelled) rethrow;
    }
    print('Native cancellation interrupted a blocked Dart writer.');

    final waiting = bridge.nextRequest();
    await bridge.close();
    if (await waiting != null) throw StateError('Closed bridge returned work');
    print('Shutdown released the pending reader.');
  } finally {
    await bridge.close();
  }
  // #endregion native-requests
}
