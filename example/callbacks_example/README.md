# Callbacks example

This standalone project lets Zig ask Dart for asynchronous work. The callback
makes another native call while the original task waits, even with one native
worker. Zig route declarations generate the call API and codecs, including the
codec reused for callback payloads. Registration and unregistration belong to
the Dart session; `registerTypedCallback` handles the byte conversion and its
registration is cleaned up on session close.

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```
