import 'package:lifecycle_example/lifecycle_example.dart';

Future<int> sum(NativeSession session) async {
  return ZigApi(session).add((a: 1, b: 2));
}

Future<void> main() async {
  await initializeZig();
  final parent = CancellationScope();
  CancellationScope(parent: parent)
      .listen((reason) => print('Child cancelled: $reason'));
  parent.cancel('Host is restarting');

  await CleanupScope.run((scope) async {
    scope.defer(() => print('First registered, last released'));
    scope.defer(() => print('Stop producer before its runtime'));
  });

  final owner = RestartableResource(
    () async => createSession(),
    (session) => session.close(),
  );
  try {
    await owner.restart();
    final current = await owner.restart();
    print('Generation ${owner.generation}: ${await sum(current)}');
  } finally {
    await owner.close();
  }
}
