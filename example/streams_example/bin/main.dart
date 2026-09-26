import 'package:streams_example/streams_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession();
  try {
    // #region typed-stream-endpoint
    final squares = ZigApi(session).squares(5);
    // #endregion
    print('Squares: ${await squares.toList()}');
  } finally {
    await session.close();
  }
}
