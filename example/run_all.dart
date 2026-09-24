/// Runs the small portable examples on the VM or through the Web entrypoint.
library;

import 'calls.dart' as calls;
import 'signals.dart' as signals;
import 'state_and_attachments.dart' as state_and_attachments;
import 'streams.dart' as streams;
import 'callbacks.dart' as callbacks;
import 'native_objects.dart' as native_objects;
import 'owned_buffers.dart' as owned_buffers;
import 'collections.dart' as collections;
import 'errors_and_cancellation.dart' as errors_and_cancellation;
import 'cleanup_and_restart.dart' as cleanup_and_restart;
import 'diagnostics.dart' as diagnostics;
import 'in_memory.dart' as in_memory;
import 'overflow_policies.dart' as overflow_policies;

Future<void> main() async {
  print('Example: calls');
  await calls.main();
  print('Example: signals');
  await signals.main();
  print('Example: state_and_attachments');
  await state_and_attachments.main();
  print('Example: streams');
  await streams.main();
  print('Example: callbacks');
  await callbacks.main();
  print('Example: native_objects');
  await native_objects.main();
  print('Example: owned_buffers');
  await owned_buffers.main();
  print('Example: collections');
  await collections.main();
  print('Example: errors_and_cancellation');
  await errors_and_cancellation.main();
  print('Example: cleanup_and_restart');
  await cleanup_and_restart.main();
  print('Example: diagnostics');
  await diagnostics.main();
  print('Example: in_memory');
  await in_memory.main();
  print('Example: overflow_policies');
  await overflow_policies.main();
  print('All portable examples completed.');
}
