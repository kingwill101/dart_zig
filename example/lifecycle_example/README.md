# Lifecycle example

This standalone project demonstrates parent cancellation, reverse-order async
cleanup, and serialized native session restart. The app's Zig operation is a
small sum used to prove the replacement session is live.

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```
