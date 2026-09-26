/// Subscribes before invoking an operation that publishes a typed event.
library;

import 'package:runtime_features_example/runtime_features_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession();
  try {
    final api = FeatureApi(session);
    final firstListener = api.messages.first;
    final secondListener = api.messages.first;
    await api.publish(const Message(text: 'Hello, subscribers', sequence: 1));
    print((await firstListener).text);
    print('Second listener saw sequence ${(await secondListener).sequence}');
  } finally {
    await session.close();
  }
}
