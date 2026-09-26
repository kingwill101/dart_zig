# Diagnostics example

This standalone project connects payload-free session diagnostics and bounded
Zig logs to Dart callbacks. It also reads the session's delivery counters.

## Run

From this directory, with Dart and Zig 0.15.2 or 0.16.0 installed:

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```

The console prints session diagnostic events, `[example] Hello from Zig`,
and a delivered-frame count. Event order can vary with scheduling.

## Follow the code

- `zig/src/handlers.zig` defines `logMessage`, which uses the runtime logging
  API to emit a bounded info log from Zig.
- Generation creates `ZigApi.logMessage` and its text codec.
- `bin/main.dart` passes `onDiagnostic` to `createSession`, forwards native
  logs with `forwardNativeLogs`, calls the handler, and reads `session.stats`.

```dart
forwardNativeLogs(session, (log) => print('[${log.scope}] ${log.message}'));
await ZigApi(session).logMessage('Hello from Zig');
```

The Dart code subscribes to `session.logs` before making the call so it can
await the emitted log. It closes the session in `finally`. Use diagnostics for
runtime events and logs for application messages; the frame counters describe
delivery rather than computation time.
