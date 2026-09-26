# Isolates example

This standalone project creates a separate native session inside each Dart
isolate. Each session owns its own ports, task IDs, and native state.

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```
