/// Connects payload-free call tracing and native logging to host-provided sinks.
library;

import 'package:runtime_features_example/runtime_features_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession(
    onDiagnostic: (event) => print('${event.kind}: route ${event.route}'),
  );
  try {
    forwardNativeLogs(session, (log) => print('[${log.scope}] ${log.message}'));
    final delivered = session.logs.first;
    final api = FeatureApi(session);
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
