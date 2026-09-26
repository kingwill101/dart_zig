# Signals and state example

This standalone project publishes a broadcast signal and a session-scoped
latest-value endpoint. `zig/src/handlers.zig` declares the named event routes
and the `publish` handler. The CLI generates their Dart codecs and an eagerly
initialized state endpoint alongside the FFI bindings.

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```
