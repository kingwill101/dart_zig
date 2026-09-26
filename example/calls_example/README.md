# Calls example

A standalone Dart project with its own Zig asset and build hook.
`zig/src/handlers.zig` defines `add(request: AddRequest)`. The CLI generates
its Dart encoder, decoder, `ZigApi`, FFI bindings, and `createSession()`
factory. The shared Zig exports derive dispatch from the handler at comptime.

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```

Expected output: `20 + 22 = 42`.
