/// Pauses a credited stream without occupying the only native worker.
library;

import 'dart:async';

import 'package:runtime_features_example/runtime_features_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession(workers: 1);
  try {
    final api = FeatureApi(session);
    print('Squares: ${await api.squares(const CountArgs(count: 5)).toList()}');
    final first = Completer<void>();
    late StreamSubscription<int> subscription;
    subscription = api.squares(const CountArgs(count: 100)).listen((value) {
      print('Stream item: $value');
      if (!first.isCompleted) {
        subscription.pause();
        first.complete();
      }
    });
    await first.future;
    print('Call while paused: ${await api.sum(const SumArgs(a: 6, b: 7))}');
    subscription.resume();
    await subscription.cancel(); // Cancels the native producer and its state.
  } finally {
    await session.close();
  }
}
