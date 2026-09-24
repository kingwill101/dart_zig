/// Selects a CLI-generated adapter for a native asset on the Dart VM.
library;

import 'package:dart_zig/dart_zig.dart';

Future<void> main() async {
  // Use the adapter generated for your own asset here. This example uses the
  // bundled asset; tool/check_consumer.py builds a truly separate library.
  final session = NativeSession(bindings: const GeneratedRuntimeBindings());
  try {
    print(await GeneratedApi(session).sum(const SumArgs(a: 20, b: 22)));
  } finally {
    await session.close();
  }
}
