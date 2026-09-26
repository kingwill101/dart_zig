import 'dart:convert';
import 'dart:typed_data';

import 'package:native_requests_example/native_requests_example.dart';

Future<void> main() async {
  final bridge = createBridge();
  try {
    final id = submitExampleRequest(bridge);
    if (id == 0) throw StateError('Native submission failed');
    final request = (await bridge.nextRequest())!;
    print('Native request $id: ${utf8.decode(request.bytes)}');
    await request.add(Uint8List.fromList(utf8.encode('Hello from Dart')));
    await request.finish();
    print('Dart sent the reply.');
  } finally {
    await bridge.close();
  }
}
