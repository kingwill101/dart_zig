import 'dart:async';
import 'dart:typed_data';

import 'package:runtime_features_example/runtime_features_example.dart';

void require(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> main() async {
  await initializeZig();
  // #region general-toolkit
  // #region session-setup
  final diagnostics = <RuntimeDiagnostic>[];
  final session = createSession(
    workers: 2,
    queueCapacity: 8,
    batchSize: 8,
    onDiagnostic: diagnostics.add,
  );
  final api = FeatureApi(session);
  // #endregion
  NativeBuffer? retained;
  SignalPack<Message>? retainedSignal;
  try {
    require(api.sumSync(20, 22) == 42, 'sync call');
    require(await api.sum(const SumArgs(a: 20, b: 22)) == 42, 'sum');
    // #region typed-signals
    final received = api.messages.first;
    await api.publish(const Message(text: 'hello from Zig', sequence: 1));
    require((await received).text == 'hello from Zig', 'typed signal');
    // #endregion

    // #region state-attachments
    final update = api.updates.stream.first;
    final otherListener = api.updates.stream.first;
    await api.updates.send(
      const Message(text: 'state', sequence: 2),
      binary: Uint8List.fromList([3, 1, 4]),
    );
    final pack = await update;
    require(
      pack.message.text == 'state' && pack.attachment.view[2] == 4,
      'bidirectional attachment',
    );
    pack.dispose();
    retainedSignal = await otherListener;
    require(
      retainedSignal.attachment.view[0] == 3,
      'subscriber leases are independent',
    );
    final latest = api.updates.latest!;
    require(latest.message.sequence == 2, 'latest snapshot');
    latest.dispose();
    final replay = await api.updates.stream.first;
    require(replay.message.text == 'state', 'replay');
    replay.dispose();
    // #endregion

    // #region native-object
    final counter = await NativeCounter.open(api, initial: 10);
    require(await counter.add(5) == 15, 'native object');
    await counter.dispose();
    // #endregion

    // #region typed-stream
    final values = await api.squares(const CountArgs(count: 5)).toList();
    require(values.join(',') == '0,1,4,9,16', 'typed stream');
    // #endregion

    // #region typed-callback
    require(
      await api.transformWith(
            value: 21,
            callback: (value) async {
              // A callback can await another native call without blocking native workers.
              return api.sum(SumArgs(a: value, b: value));
            },
          ) ==
          42,
      'typed async callback',
    );
    // #endregion

    final record = Record(
      label: 'typed',
      tags: ['one', 'two'],
      score: 0.5,
      importance: Importance.high,
      data: Uint8List.fromList([1, 2, 3]),
      flags: [true, false],
    );
    final returned = await api.roundTripRecord(record);
    require(
      returned.tags.join(',') == 'one,two' &&
          returned.score == 0.5 &&
          returned.flags.first,
      'model codec',
    );
    final rich = await api.roundTripRich(
      RichValues(
        scores: {'first': -7},
        labels: {'one', 'two'},
        coordinates: [1.5, 2.0, -3.0],
        pair: ('wide', -(BigInt.one << 100)),
        huge: (BigInt.one << 128) - BigInt.one,
        small: -128,
        medium: 65535,
      ),
    );
    require(
      rich.scores['first'] == -7 &&
          rich.labels.contains('two') &&
          rich.coordinates[2] == -3 &&
          rich.pair.$2 == -(BigInt.one << 100) &&
          rich.huge == (BigInt.one << 128) - BigInt.one &&
          rich.small == -128,
      'rich codecs preserve exact values',
    );
    final union = await api.roundTripValue(const ValueText('tagged union'));
    require(union is ValueText && union.value == 'tagged union', 'union codec');
    final log = session.logs.first;
    await api.emitLog(const Message(text: 'native logging', sequence: 0));
    require((await log).message == 'native logging', 'native logs');

    // #region owned-buffer
    final payload = Uint8List.fromList(
      List<int>.generate(65536, (i) => i % 251),
    );
    retained = await session.callBuffer(8, payload).result;
    require(retained.view[65535] == payload[65535], 'owned native buffer');
    // #endregion

    final cancelled = session.call(8, Uint8List(8));
    cancelled.cancel();
    try {
      await cancelled.result;
      throw StateError('Cancellation succeeded');
    } on NativeException catch (error) {
      require(error.code == 'cancelled', 'cancel code');
    }

    final never = Completer<Uint8List>();
    final stalled = session.registerCallback((_) => never.future);
    try {
      await api.transform(
        TransformArgs(callbackId: stalled, value: 1),
        timeout: const Duration(milliseconds: 10),
      );
      throw StateError('Deadline succeeded');
    } on NativeException catch (error) {
      require(error.code == 'deadline', 'deadline code');
    }
    never.complete(Uint8List(8));
    session.unregisterCallback(stalled);

    final streamDone = Completer<void>();
    var items = 0;
    late StreamSubscription<int> subscription;
    subscription = api
        .squares(const CountArgs(count: 20))
        .listen(
          (value) {
            require(value == items * items, 'stream order');
            items++;
            if (items == 1) {
              subscription.pause();
              Timer(const Duration(milliseconds: 5), subscription.resume);
            }
          },
          onError: streamDone.completeError,
          onDone: streamDone.complete,
        );
    await streamDone.future;
    require(items == 20, 'pause/resume flow control');
    await subscription.cancel();

    final stale = await api.counterCreate(const CounterCreate(initial: 0));
    await api.counterDispose(HandleArgs(handle: stale));
    final replacement = await api.counterCreate(
      const CounterCreate(initial: 0),
    );
    require(replacement != stale, 'handle generation changed');
    try {
      await api.counterAdd(CounterAdd(handle: stale, delta: 1));
      throw StateError('Stale handle accepted');
    } on NativeException catch (error) {
      require(error.message == 'StaleHandle', 'stale handle rejection');
    }
    await Future.wait(
      List.generate(
        64,
        (_) => api.counterAdd(CounterAdd(handle: replacement, delta: 1)),
      ),
    );
    require(
      await api.counterAdd(CounterAdd(handle: replacement, delta: 0)) == 64,
      'concurrent native object access',
    );
    await api.counterDispose(HandleArgs(handle: replacement));

    try {
      await session.call(1, Uint8List(3)).result;
      throw StateError('Malformed payload accepted');
    } on NativeException catch (error) {
      require(error.message == 'Truncated', 'checked native decoding');
    }
    final overflowDone = Completer<void>();
    var overflowed = false;
    final pausedSignals = api.messages.listen(
      (_) {},
      onError: (Object error) {
        overflowed =
            error is NativeException && error.code == 'signal_overflow';
      },
      onDone: overflowDone.complete,
    );
    pausedSignals.pause();
    for (var i = 0; i < 65; i++) {
      await api.publish(Message(text: 'bounded', sequence: i));
    }
    pausedSignals.resume();
    await overflowDone.future;
    require(overflowed, 'paused signal backlog bounded');
    await pausedSignals.cancel();

    final signalFailure = session.signalErrors.first;
    await session.sendSignal(999, Uint8List(0));
    require(
      (await signalFailure).operation == 999,
      'one-way handler errors are observable',
    );
    require(
      diagnostics.any((event) => event.kind == 'completed'),
      'call tracing',
    );
    final stats = session.stats;
    require(stats.delivered > 0 && stats.copiedBytes > 0, 'runtime metrics');
    print(
      'Typed calls, signals, native objects, streams, callbacks, codecs, logs, cancellation, deadlines, and owned buffers passed.',
    );
  } finally {
    await session.close();
  }
  require(retained.view.length == 65536, 'buffer survives session close');
  retained.dispose();
  require(
    retainedSignal.attachment.view[2] == 4,
    'signal lease survives session close',
  );
  retainedSignal.dispose();
  require(
    session.liveBuffers == 0 && session.liveBufferBytes == 0,
    'native storage released',
  );
  for (var cycle = 0; cycle < 3; cycle++) {
    final restarted = createSession();
    require(
      await FeatureApi(restarted).sum(const SumArgs(a: 1, b: 2)) == 3,
      'new session',
    );
    await restarted.close();
  }
  require(session.liveBuffers == 0, 'repeated session cleanup');
  final reentrant = createSession();
  final reentrantApi = FeatureApi(reentrant);
  final subscription = reentrantApi.messages.listen((_) {
    unawaited(reentrant.close());
  });
  try {
    await reentrantApi.publish(
      const Message(text: 'close inside listener', sequence: 0),
    );
  } on NativeException catch (error) {
    require(error.code == 'closed', 'reentrant shutdown result');
  }
  await reentrant.close();
  await subscription.cancel();
  require(reentrant.liveBuffers == 0, 'reentrant session cleanup');
  final memory = createSession(
    transport: MemoryTransport(
      handler: (context, bytes) async {
        if (context.route == 1) {
          final reader = BinaryReader(bytes);
          final a = reader.i64();
          final b = reader.i64();
          reader.finish();
          final writer = BinaryWriter()..i64(a + b);
          await context.complete(writer.finish());
        } else {
          await context.fail('Unknown operation');
        }
      },
    ),
  );
  require(
    await FeatureApi(memory).sum(const SumArgs(a: 12, b: 30)) == 42,
    'in-memory facade',
  );
  await memory.close();
  // #region cleanup
  final order = <int>[];
  final scope = CleanupScope();
  scope.defer(() {
    order.add(1);
  });
  scope.defer(() async {
    order.add(2);
  });
  await scope.close();
  await scope.close();
  require(
    order.join(',') == '2,1' && scope.cancellation.isCancelled,
    'ordered idempotent cleanup',
  );
  final failingScope = CleanupScope();
  var releasedAfterFailure = false;
  failingScope.defer(() {
    releasedAfterFailure = true;
  });
  failingScope.defer(() {
    throw StateError('expected cleanup failure');
  });
  try {
    await failingScope.close();
    throw StateError('Missing cleanup failure');
  } on CleanupException catch (error) {
    require(
      error.failures.length == 1 && releasedAfterFailure,
      'cleanup attempts every disposer',
    );
  }
  final owner = RestartableResource(
    () async => createSession(workers: 1),
    (session) => session.close(),
  );
  final first = await owner.restart();
  final firstApi = FeatureApi(first);
  final paused = firstApi.squares(const CountArgs(count: 100)).listen((_) {});
  paused.pause();
  require(
    await firstApi.sum(
          const SumArgs(a: 4, b: 5),
          timeout: const Duration(seconds: 2),
        ) ==
        9,
    'paused stream releases single worker',
  );
  await paused.cancel();
  await owner.restart();
  require(
    first.isClosed && owner.generation == 2,
    'restart closes old session',
  );
  await owner.close();
  // #endregion
  print(
    'Session restart, stale handles, bounded subscriptions, reentrant shutdown, and native cleanup passed.',
  );
  // #endregion general-toolkit
}
