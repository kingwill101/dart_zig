/// Keeps only the newest state while a listener is paused.
library;

import 'dart:async';

import 'package:dart_zig/dart_zig.dart';

Future<void> main() async {
  final bus = SignalBus<int>(
    sizeOf: (_) => 8,
    maxMessages: 2,
    overflow: OverflowPolicy.latest,
    replayLatest: true,
  );
  final received = Completer<int>();
  final subscription = bus.stream.listen(received.complete)..pause();
  for (var value = 1; value <= 10; value++) {
    bus.add(value);
  }
  subscription.resume();
  print(
    'Coalesced value: ${await received.future}; replaced values: ${bus.overflowCount}',
  );
  await subscription.cancel();
  bus.close();
}
