# Web example

This standalone package builds the same typed Zig handler for native Dart
and WebAssembly. Conditional exports choose the native FFI adapter or Web stub;
the generated `initializeZig()` entrypoint loads `web_example.wasm` on Web.

## Run

From this directory, with Dart, Zig 0.15.2 or 0.16.0, and Node installed:

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
sh tool/build_web.sh
node tool/run_web.mjs
```

The native command prints `20 + 22 = 42`; the Node runner prints `Web sum: 42`.
The Node run exercises WebAssembly through compiled Dart JavaScript. To inspect
the browser page instead, start `dart run tool/serve_web.dart` after the Web
build and visit `http://localhost:8080/`.

## Follow the code

`zig/src/handlers.zig` defines the `add` handler. Generation writes its typed
`ZigApi.add` method, the conditional `createSession()` entrypoint, and
`web/web_example.wasm`. Both `bin/main.dart` and `web/main.dart` import
`package:web_example/web_example.dart`, call `initializeZig()`, create a
session, invoke `ZigApi.add`, and close the session.

`tool/build_web.sh` compiles the Zig module and the browser Dart entrypoint
into `build/web/`. `tool/run_web.mjs` serves the Wasm bytes to the compiled
JavaScript under Node. These `tool/` scripts belong to this example; they are
not files created by `dart_zig init` in an application project.
