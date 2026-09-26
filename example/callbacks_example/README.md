# Callbacks example

This standalone project lets Zig ask Dart for asynchronous work. The callback
makes another native call while the original task waits, even with one native
worker. Zig route declarations generate the call API and codecs, including the
codec reused for callback payloads. Registration and unregistration belong to
the Dart session; `registerTypedCallback` handles the byte conversion and its
registration is cleaned up on session close.

## Run

From this directory, with Dart and Zig 0.15.2 or 0.16.0 installed:

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```

Expected output: `Callback result: 42`.

## Follow the round trip

1. `zig/src/protocol.zig` declares the `add` and `askDart` calls. Generation
   creates `ProtocolApi` and their codecs.
2. `bin/main.dart` opens a session with one worker and registers a typed Dart
   callback. The callback invokes `api.add` with the received value twice.
3. Dart calls `api.askDart` with the callback ID and `21`.
4. `zig/src/application.zig` sends the value to that callback. When the Dart
   result arrives, Zig completes the original call with `42`.

The callback can make a native call while the original operation waits, even
with one worker. The example disposes its callback registration and then
closes the session. This project uses explicit routes in `protocol.zig` and a
matching dispatcher in `application.zig`; regenerate after changing routes.
