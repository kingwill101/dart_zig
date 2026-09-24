/// Uses the generated Dart facade with a bounded application-supplied transport.
library;

import 'package:dart_zig/dart_zig.dart';

Future<void> main() async {
  final transport = MemoryTransport(
    schemaFingerprint: schemaFingerprint,
    handler: (context, bytes) async {
      if (context.route != 1) {
        await context.fail('Unknown operation');
        return;
      }
      final reader = BinaryReader(bytes);
      final sum = reader.i64() + reader.i64();
      reader.finish();
      await context.complete((BinaryWriter()..i64(sum)).finish());
    },
  );
  final session = NativeSession(transport: transport);
  try {
    print(
      'In-memory sum: ${await GeneratedApi(session).sum(const SumArgs(a: 20, b: 22))}',
    );
  } finally {
    await session.close();
  }
}
