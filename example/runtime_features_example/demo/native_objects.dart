/// Owns a native object through a generation-checked, session-local handle.
library;

import 'package:runtime_features_example/runtime_features_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession();
  try {
    final counter = await NativeCounter.open(
      FeatureApi(session),
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
