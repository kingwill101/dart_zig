# Native ownership example

This standalone project demonstrates a session-owned Zig counter handle and an
explicitly owned native output buffer. It releases the handle before session
shutdown and retains a buffer slice after shutdown. Generated typed calls
power the example's `NativeCounter` object, whose `close()` releases its Zig
handle. The raw buffer call demonstrates explicit buffer ownership.

## Run

From this directory, with Dart and Zig 0.15.2 or 0.16.0 installed:

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
```

The output includes `Counter: 15` and `Retained slice: [20, 30]`.

## Follow the code

`zig/src/protocol.zig` declares the counter calls. `zig/src/application.zig`
stores counters in a handle table and implements create, add, and release.
Generation writes `ProtocolApi` and the call codecs. On the Dart side,
`lib/src/native_counter.dart` wraps the generated calls in an object with
`open`, `add`, and `close` methods.

`bin/main.dart` opens a counter at 10, adds 5, and closes the handle before
closing the session. It also makes a low-level buffer call, retains a slice,
closes the session, and reads the retained slice afterward. The slice and
buffer are disposed separately. This shows why a Dart buffer lease can
outlive a session while a native counter handle must be released explicitly.
