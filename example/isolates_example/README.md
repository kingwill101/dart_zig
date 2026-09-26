# Isolates example

This standalone project creates a separate native session inside each Dart
isolate. Each session owns its own ports, task IDs, and native state.

## Run

From this directory, with Dart and Zig 0.15.2 or 0.16.0 installed:

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```

Expected output: `Isolate results: [42, 42]`.

## Follow the code

`zig/src/handlers.zig` provides the same `add` call used by the basic calls
example. Generation creates its typed `ZigApi.add` method. In `bin/main.dart`,
two `Isolate.run` tasks each call `calculate()`. That function creates, uses,
and closes its own session inside the isolate; no session or native handle is
sent between isolates. The main isolate waits for both results with
`Future.wait`.

This is the pattern for running independent Dart isolate workloads against
the same native asset. Keep session creation and cleanup in the isolate that
uses it.
