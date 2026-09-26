import 'dart:convert';
import 'dart:typed_data';

import 'package:native_requests_example/native_requests_example.dart';

Future<void> main() async {
  // #region native-requests
  final bridge = createBridge(maxMessages: 1, maxBytes: 1024);
  try {
    final id = submitExampleRequest(bridge);
    if (id == 0) throw StateError('Native submission failed');
    final request = (await bridge.nextRequest())!;
    print('Native request $id: ${utf8.decode(request.bytes)}');
    await request.add(Uint8List.fromList(utf8.encode('Hello from Dart')));

    // The one-slot reply queue is full. Completion waits for native consumption.
    final finished = request.finish();
    consumeExampleReply(bridge, id, ReplyKind.chunk, 'Hello from Dart');
    await finished;
    consumeExampleReply(bridge, id, ReplyKind.end, '');
    print('Zig consumed the streamed reply and completion.');

    final cancelledId = submitExampleRequest(bridge);
    final cancelled = (await bridge.nextRequest())!;
    await cancelled.cancel();
    consumeExampleReply(bridge, cancelledId, ReplyKind.cancelled, '');
    print('Zig observed cancellation.');

    final nativeCancelledId = submitExampleRequest(bridge);
    final nativeCancelled = (await bridge.nextRequest())!;
    await nativeCancelled.add(Uint8List.fromList([1, 2, 3]));
    final blocked = nativeCancelled.finish();
    if (!cancelExampleRequest(bridge, nativeCancelledId)) {
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
