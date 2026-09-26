# Web example

This standalone package builds the same typed Zig handler for native Dart
and WebAssembly. Conditional exports choose the native FFI adapter or Web stub;
`initializeZig` selects the Wasm asset on Web.

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
sh tool/build_web.sh
node tool/run_web.mjs
```

The Node run exercises WebAssembly; use `dart run tool/serve_web.dart` to inspect
the browser page at `http://localhost:8080/`.
