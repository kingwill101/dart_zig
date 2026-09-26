# Calls example

A standalone Dart project with its own Zig asset and build hook.
`zig/src/handlers.zig` defines `add(request: AddRequest)`. The CLI generates
its Dart encoder, decoder, `ZigApi`, FFI bindings, and `createSession()`
factory. The shared Zig exports derive dispatch from the handler at comptime.

## Run

From this directory, with Dart and Zig 0.15.2 or 0.16.0 installed:

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```

Expected output: `20 + 22 = 42`.

## Follow the call

`zig/src/handlers.zig` defines `AddRequest` with two `i64` fields and a public
`add` function. Generation turns that signature into `ZigApi.add`, which takes
the Dart record `(a: int, b: int)` and returns `Future<int>`. It also creates
the request and response codecs.

```dart
final sum = await ZigApi(session).add((a: 20, b: 22));
```

`bin/main.dart` opens a session, calls `ZigApi(session).add((a: 20, b: 22))`,
prints the result, and closes the session in `finally`. The build hook compiles
this package's Zig asset when Dart runs the program. Add another public Zig
handler in `handlers.zig`, then rerun `generate` to expose its typed Dart method.
