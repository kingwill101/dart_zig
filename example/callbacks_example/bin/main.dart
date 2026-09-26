import 'package:callbacks_example/callbacks_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession(workers: 1);
  try {
    final api = ProtocolApi(session);
    final callback = session.registerTypedCallback<int, int>(
      (value) => api.add((a: value, b: value)),
      input: const AskDartResponseCodec(),
      output: const AskDartResponseCodec(),
    );
    try {
      final result = await api.askDart((callbackId: callback.id, value: 21));
      print('Callback result: $result');
    } finally {
      callback.dispose();
    }
  } finally {
    await session.close();
  }
}
