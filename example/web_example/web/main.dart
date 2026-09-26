import 'package:web_example/web_example.dart';

Future<void> main() async {
  await initializeZig(wasmUri: Uri.parse('dart_zig.wasm'));
  final session = createSession();
  try {
    final sum = await ZigApi(session).add((a: 20, b: 22));
    print('Web sum: $sum');
  } finally {
    await session.close();
  }
}
