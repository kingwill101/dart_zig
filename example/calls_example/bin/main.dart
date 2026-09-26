import 'package:calls_example/calls_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession();
  try {
    // #region typed-call
    final sum = await ZigApi(session).add((a: 20, b: 22));
    // #endregion
    print('20 + 22 = $sum');
  } finally {
    await session.close();
  }
}
