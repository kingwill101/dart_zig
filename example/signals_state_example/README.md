# Signals and state example

This standalone project publishes a broadcast signal and a session-scoped
latest-value endpoint. `zig/src/handlers.zig` declares the named event routes
and the `publish` handler. The CLI generates their Dart codecs and an eagerly
initialized state endpoint alongside the FFI bindings.

## Run

From this directory, with Dart and Zig 0.15.2 or 0.16.0 installed:

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```

Expected output includes `Signal: hello`, `State: ready`, and `Replay: ready`.

## Follow the events

`zig/src/handlers.zig` declares `notifications` as a signal and `updates` as
state. Its `publish` handler emits a notification from Zig. Generation creates
`ZigApi.publish`, `ZigApi.notifications`, `ZigApi.updates`, and their codecs.

```dart
final api = ZigApi(session);
final next = api.notifications.stream.first;
await api.publish('hello');
final pack = await next;
print(pack.message);
pack.dispose();
```

In `bin/main.dart`, Dart subscribes before calling `publish('hello')` and
receives the signal. It then sends `ready` through the state endpoint. A
later subscriber receives the latest value immediately, within that session.
The example disposes each received signal pack and closes the session. Use a
signal for broadcasts and state for a latest-value stream with replay.
