import 'dart:isolate';

import 'package:isolates_example/isolates_example.dart';

Future<int> calculate() async {
  final session = createSession();
  try {
    return await ZigApi(session).add((a: 20, b: 22));
  } finally {
    await session.close();
  }
}

Future<void> main() async {
  await initializeZig();
  final results = await Future.wait([
    Isolate.run(calculate),
    Isolate.run(calculate),
  ]);
  print('Isolate results: $results');
}
