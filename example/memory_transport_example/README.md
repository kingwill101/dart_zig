# In-memory transport example

This standalone project has its own Zig asset, but its Dart entry point injects
`MemoryTransport` so the same session call can run against a deterministic Dart
handler through the same generated typed API. Remove `transport:` to call the
matching Zig handler instead.

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```
