# In-memory transport example

This standalone project has its own Zig asset, but its Dart entry point injects
`MemoryTransport` so the same session call can run against a deterministic Dart
handler through the same generated typed API. Remove `transport:` to call the
matching Zig handler instead.

## Run

From this directory, with Dart and Zig 0.15.2 or 0.16.0 installed:

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```

Expected output: `In-memory sum: 42`.

## Follow the code

`zig/src/handlers.zig` defines the real `add` operation, and generation
creates `ZigApi.add` plus its request and response codecs. `bin/main.dart`
constructs a `MemoryTransport` whose Dart handler checks `ZigApi.addRoute`,
decodes the request, and completes it with the encoded sum. Passing that
transport to `createSession` lets the unchanged typed API call the Dart
implementation.

This is useful for deterministic consumers of the session API. The example
does not invoke Zig while the injected transport is active. Remove
`transport: transport` from `createSession` to use the compiled Zig handler;
the Dart call site stays the same. The session closes in `finally`.
