import 'dart:typed_data';

import 'package:attachments_example/attachments_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession();
  try {
    final endpoint = ZigApi(session).attachments;
    final first = endpoint.stream.first;
    final second = endpoint.stream.first;
    await endpoint.send((label: 'image', tag: Uint8List.fromList([1, 2])), binary: Uint8List.fromList([3, 1, 4]));
    final a = await first;
    final b = await second;
    a.dispose();
    print('${b.message.label} ${b.message.tag}: ${b.attachment.view}');
    b.dispose();
  } finally {
    await session.close();
  }
}
