/// Selects a CLI-generated adapter for a native asset on the Dart VM.
library;

import 'package:runtime_features_example/runtime_features_example.dart';

Future<void> main() async {
  // The generated factory selects this package's native asset.
  final session = createSession();
  try {
    print(await FeatureApi(session).sum(const SumArgs(a: 20, b: 22)));
  } finally {
    await session.close();
  }
}
