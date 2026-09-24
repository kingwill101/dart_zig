/// Subscribes before invoking an operation that publishes a typed event.
library;

import 'package:dart_zig/dart_zig.dart';

Future<void> main() async {
  await initializeZig();
  final session = NativeSession();
  try {
    final api = GeneratedApi(session);
    final firstListener = api.messages.first;
    final secondListener = api.messages.first;
    await api.publish(const Message(text: 'Hello, subscribers', sequence: 1));
    print((await firstListener).text);
    print('Second listener saw sequence ${(await secondListener).sequence}');
  } finally {
    await session.close();
  }
}
