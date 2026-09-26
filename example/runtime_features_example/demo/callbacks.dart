/// Lets Zig request an asynchronous Dart callback that calls Zig again.
library;

import 'package:runtime_features_example/runtime_features_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession(workers: 1);
  try {
    final api = FeatureApi(session);
    final result = await api.transformWith(
      value: 21,
      callback: (value) async {
        return api.sum(SumArgs(a: value, b: value));
      },
    );
    print('Callback result: $result');
    // transformWith unregisters the callback on success or failure.
  } finally {
    await session.close();
  }
}
