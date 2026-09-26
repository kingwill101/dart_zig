# Native ownership example

This standalone project demonstrates a session-owned Zig counter handle and an
explicitly owned native output buffer. It releases the handle before session
shutdown and retains a buffer slice after shutdown. Generated typed calls
power the example's `NativeCounter` object, whose `close()` releases its Zig
handle. The raw buffer call demonstrates explicit buffer ownership.

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```
