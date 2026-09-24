import 'dart:async';

import 'session.dart';

/// An immutable observation of session work. Payload contents are never recorded.
final class RuntimeDiagnostic {
  RuntimeDiagnostic(
    this.kind, {
    this.route,
    this.requestId,
    this.bytes,
    this.error,
  }) : timestamp = DateTime.now();
  final String kind;
  final int? route, requestId, bytes;
  final Object? error;
  final DateTime timestamp;
}

/// Host-supplied tracing adapter usable by CLI, server, desktop, or Web consumers.
typedef DiagnosticSink = void Function(RuntimeDiagnostic event);

/// Connects structured native logs to a host's logging system.
///
/// The registration is detached by session cleanup. The caller owns its logger.
StreamSubscription<NativeLog> forwardNativeLogs(
  NativeSession session,
  void Function(NativeLog) write,
) {
  final subscription = session.logs.listen(write);
  session.cleanup.defer(subscription.cancel);
  return subscription;
}
