# Attachments example

This standalone project sends typed text and byte metadata with a separate
binary attachment. Its Zig event declaration generates the Dart codec and
endpoint. Its field name supplies the stable route ID. Two Dart listeners
receive independent attachment leases, so disposing one does not invalidate
the other. The shared handler dispatcher validates and relays the typed frame.

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```
