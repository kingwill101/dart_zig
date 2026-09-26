# Native request example

This standalone Dart package uses `dart_zig` for native-to-Dart requests and
streamed Dart replies. Its Zig build compiles the shared runtime exports;
`zig/src/demo.zig` implements the request producer and consumer, while
`zig/src/extra_exports.zig` exposes its three demo functions.

## Run

From this directory, with Dart and Zig 0.15.2 or 0.16.0 installed:

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```

`bin/main.dart` is the short request/reply path. `dart run bin/stress.dart`
covers bounded reply queues, both cancellation directions, and shutdown.

## Follow the request

`zig/src/demo.zig` submits `GET /hello` through the bridge. `bin/main.dart`
uses the generated native exports to start the producer, waits for
`bridge.nextRequest()`, writes `Hello from Dart` to the request, and finishes
the reply. The example closes the bridge in `finally`.

`bin/stress.dart` uses a one-message, 1024-byte reply budget to exercise
backpressure and verify that Zig consumes Dart's reply. It also covers Dart
cancelling a request, Zig cancelling one, and a pending reader being released
on shutdown. This is the lower-level `dart_api_dl` bridge for native-to-Dart
requests; the ordinary generated `ZigApi` call path is shown in
[calls](../calls_example/README.md).

The build hook compiles this package's Zig asset when Dart runs. After changing
its exported Zig functions, regenerate both runtime and demo FFI bindings with
`dart run dart_zig:dart_zig generate`. The generated `createBridge()` factory
selects this package's native asset.
