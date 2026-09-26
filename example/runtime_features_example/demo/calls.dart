/// Synchronous and asynchronous typed calls through the example facade.
library;

import 'package:runtime_features_example/runtime_features_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession();
  try {
    final api = FeatureApi(session);
    print('Synchronous sum: ${api.sumSync(20, 22)}');
    print('Asynchronous sum: ${await api.sum(const SumArgs(a: 20, b: 22))}');
  } finally {
    await session.close();
  }
}
