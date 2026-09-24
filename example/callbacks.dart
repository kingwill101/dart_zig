/// Lets Zig request an asynchronous Dart callback that calls Zig again.
library;

import 'package:dart_zig/dart_zig.dart';

Future<void> main() async {
  await initializeZig();
  final session = NativeSession(workers: 1);
  try {
    final api = GeneratedApi(session);
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
