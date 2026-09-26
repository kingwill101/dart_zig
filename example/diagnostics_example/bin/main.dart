import 'package:diagnostics_example/diagnostics_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession(
    onDiagnostic: (event) => print('${event.kind}: route ${event.route}'),
  );
  try {
    forwardNativeLogs(session, (log) => print('[${log.scope}] ${log.message}'));
    final delivered = session.logs.first;
    await ZigApi(session).logMessage('Hello from Zig');
    await delivered;
    print('Delivered frames: ${session.stats.delivered}');
  } finally {
    await session.close();
  }
}
