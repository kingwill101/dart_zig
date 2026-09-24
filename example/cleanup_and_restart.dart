/// Uses host-controlled cancellation, ordered cleanup, and serialized restart.
library;

import 'package:dart_zig/dart_zig.dart';

Future<void> main() async {
  await initializeZig();
  final parent = CancellationScope();
  final child = CancellationScope(parent: parent);
  child.listen((reason) => print('Child cancelled: $reason'));
  parent.cancel('Host is restarting');
  await CleanupScope.run((scope) async {
    scope.defer(() => print('First registered, last released'));
    scope.defer(() async => print('Stop producer before its runtime'));
  });
  final owner = RestartableResource(
    () async => NativeSession(),
    (session) => session.close(),
  );
  try {
    await owner.restart();
    final current = await owner.restart();
    print(
      'Generation ${owner.generation}: ${await GeneratedApi(current).sum(const SumArgs(a: 1, b: 2))}',
    );
  } finally {
    await owner.close();
  }
}
