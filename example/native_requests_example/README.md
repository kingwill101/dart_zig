# Native request example

This standalone Dart package uses `dart_zig` for native-to-Dart requests and
streamed Dart replies. Its Zig build compiles the shared runtime exports;
`zig/src/demo.zig` implements the request producer and consumer, while
`zig/src/extra_exports.zig` exposes its three demo functions.

From this directory:

```sh
dart pub get
dart run bin/main.dart
```

`bin/main.dart` is the short request/reply path. `dart run bin/stress.dart`
covers bounded reply queues, both cancellation directions, and shutdown.

The build hook compiles this package's Zig asset when Dart runs. After changing
its exported Zig functions, regenerate both runtime and demo FFI bindings with
`dart run dart_zig:dart_zig generate`. The generated `createBridge()` factory
selects this package's native asset.
