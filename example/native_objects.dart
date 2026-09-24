/// Owns a native object through a generation-checked, session-local handle.
library;

import 'package:dart_zig/dart_zig.dart';

Future<void> main() async {
  await initializeZig();
  final session = NativeSession();
  try {
    final counter = await NativeCounter.open(
      GeneratedApi(session),
      initial: 10,
    );
    try {
      print('Counter: ${await counter.add(5)}');
      print('Counter: ${await counter.add(-2)}');
    } finally {
      await counter.dispose();
    }
  } finally {
    await session.close();
  }
}
