/// Sends a one-way signal and retains independent binary attachment leases.
library;

import 'dart:typed_data';

import 'package:dart_zig/dart_zig.dart';

Future<void> main() async {
  await initializeZig();
  final session = NativeSession();
  try {
    final updates = GeneratedApi(session).updates;
    final first = updates.stream.first;
    final second = updates.stream.first;
    // Completion means admission. Receiving the echoed event shows processing.
    await updates.send(
      const Message(text: 'Current selection', sequence: 1),
      binary: Uint8List.fromList([3, 1, 4]),
    );
    final a = await first;
    final b = await second;
    a.dispose(); // This does not invalidate b's lease.
    print('Attachment: ${b.attachment.view}');
    b.dispose();
    final snapshot = updates.latest!;
    print('Cached state: ${snapshot.message.text}');
    snapshot.dispose();
    final replay = await updates.stream.first;
    print('New subscriber: ${replay.message.text}');
    replay.dispose();
  } finally {
    await session.close();
  }
}
