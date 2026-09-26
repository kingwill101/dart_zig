import 'dart:isolate';

import 'package:runtime_features_example/runtime_features_example.dart';

/// Each isolate owns its ports, session, callbacks, and native task namespace.
Future<int> calculate() async {
  final session = createSession();
  try {
    return await FeatureApi(session).sum(const SumArgs(a: 20, b: 22));
  } finally {
    await session.close();
    if (session.liveBuffers != 0) {
      throw StateError('Isolate session retained native buffers');
    }
  }
}

Future<void> main() async {
  final results = await Future.wait([
    Isolate.run(calculate),
    Isolate.run(calculate),
  ]);
  if (results.any((value) => value != 42)) {
    throw StateError('Isolate session ownership failed');
  }
  print('Independent Dart isolate sessions passed.');
}
