import 'package:web_example/web_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession();
  try {
    final sum = await ZigApi(session).add((a: 20, b: 22));
    print('20 + 22 = $sum');
  } finally {
    await session.close();
  }
}
