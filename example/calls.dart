/// Synchronous and asynchronous typed calls through the generated facade.
library;

import 'package:dart_zig/dart_zig.dart';

Future<void> main() async {
  await initializeZig();
  final session = NativeSession();
  try {
    final api = GeneratedApi(session);
    print('Synchronous sum: ${api.sumSync(20, 22)}');
    print('Asynchronous sum: ${await api.sum(const SumArgs(a: 20, b: 22))}');
  } finally {
    await session.close();
  }
}
