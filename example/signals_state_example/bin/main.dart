import 'package:signals_state_example/signals_state_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession();
  try {
    final api = ZigApi(session);
    final event = api.notifications.stream.first;
    await api.publish('hello');
    final notification = await event;
    print('Signal: ${notification.message}');
    notification.dispose();

    final updates = api.updates;
    final first = updates.stream.first;
    await updates.send('ready');
    final received = await first;
    print('State: ${received.message}');
    received.dispose();
    final replay = await updates.stream.first;
    print('Replay: ${replay.message}');
    replay.dispose();
  } finally {
    await session.close();
  }
}
