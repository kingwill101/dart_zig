import 'dart:isolate';

import 'package:dart_zig/dart_zig.dart';

/// Each isolate owns its ports, session, callbacks, and native task namespace.
Future<int> calculate() async {
  final session = NativeSession();
  try {
    return await GeneratedApi(session).sum(const SumArgs(a: 20, b: 22));
  } finally {
    await session.close();
  }
}

Future<void> main() async {
  final results = await Future.wait([
    Isolate.run(calculate),
    Isolate.run(calculate),
  ]);
  if (results.any((value) => value != 42) || NativeSession.liveBuffers != 0) {
    throw StateError('Isolate session ownership failed');
  }
  print('Independent Dart isolate sessions passed.');
}
