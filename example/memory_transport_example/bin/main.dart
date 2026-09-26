import 'package:memory_transport_example/memory_transport_example.dart';

Future<void> main() async {
  final transport = MemoryTransport(
    handler: (context, bytes) async {
      if (context.route != ZigApi.addRoute) {
        await context.fail('Unknown operation');
        return;
      }
      final request = const AddRequestCodec().decode(bytes);
      await context.complete(
        const AddResponseCodec().encode(request.a + request.b),
      );
    },
  );
  final session = createSession(transport: transport);
  try {
    final sum = await ZigApi(session).add((a: 20, b: 22));
    print('In-memory sum: $sum');
  } finally {
    await session.close();
  }
}
