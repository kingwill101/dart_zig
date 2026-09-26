/// Sends a one-way signal and retains independent binary attachment leases.
library;

import 'dart:typed_data';

import 'package:runtime_features_example/runtime_features_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession();
  try {
    final updates = FeatureApi(session).updates;
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
