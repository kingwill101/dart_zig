# Lifecycle example

This standalone project demonstrates parent cancellation, reverse-order async
cleanup, and serialized native session restart. The app's Zig operation is a
small sum used to prove the replacement session is live.

## Run

From this directory, with Dart and Zig 0.15.2 or 0.16.0 installed:

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```

The output shows the child cancellation reason, cleanup in reverse
registration order, and `Generation 2: 3`.

## Follow the code

`bin/main.dart` creates a parent `CancellationScope` and a child listener.
Cancelling the parent forwards the reason to the child. `CleanupScope.run`
registers two cleanup actions and runs the second one first when the scope
ends. `RestartableResource` owns a native session: two calls to `restart()`
replace it, and the generated `ZigApi.add` call confirms generation 2 works.

The Zig side in `zig/src/handlers.zig` is deliberately small so the example
focuses on Dart-side lifecycle control. `owner.close()` releases the final
session. Regenerate after changing the Zig handler signature.
