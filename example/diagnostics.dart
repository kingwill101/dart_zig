/// Connects payload-free call tracing and native logging to host-provided sinks.
library;

import 'package:dart_zig/dart_zig.dart';

Future<void> main() async {
  await initializeZig();
  final session = NativeSession(
    onDiagnostic: (event) => print('${event.kind}: route ${event.route}'),
  );
  try {
    forwardNativeLogs(session, (log) => print('[${log.scope}] ${log.message}'));
    final delivered = session.logs.first;
    final api = GeneratedApi(session);
    await api.emitLog(
      const Message(text: 'Hello from Zig logging', sequence: 1),
    );
    await delivered;
    await api.sum(const SumArgs(a: 1, b: 2));
    print(
      'Delivered frames: ${session.stats.delivered}; copied bytes: ${session.stats.copiedBytes}',
    );
  } finally {
    await session.close();
  }
}
