# dart_zig

Use Zig from Dart and Flutter through generated, typed APIs. Write your handlers
in Zig, generate their Dart methods and codecs, and call them from a session
that manages communication and cleanup.

`dart_zig` supports asynchronous calls, streams, signals, callbacks, and native
resources. Your application owns its Zig source: a Dart build hook compiles it
into a native library, while Web applications use a WebAssembly module. The core
package has no Flutter dependency and does not prescribe an application protocol.

## What you can build

- **Request/response APIs** with typed results and cancellation.
- **Continuous data flows** with streams that follow the listener's pace,
  signals for notifications, and shared state updates.
- **Work that crosses both ways** with callbacks from Zig into Dart.
- **Resource-owning integrations** with binary attachments, native handles,
  buffers, and session cleanup.

For a short synchronous native function, direct FFI may be all you need.
That path uses `native_toolchain_zig` without a `dart_zig` session or binary
codec; see the [direct FFI setup](doc/generation.md#direct-ffi).
Use the session-based setup below for workers, asynchronous communication,
resource management, or Web/Wasm.

## Quick start

### 1. Set up your package

Start in an existing Dart package, or create one with
`dart create -t console my_app`. You need Dart 3.13 or later and Zig 0.15.2 or
0.16.0 available on your path.

The package is under active development and is not published to pub.dev.
The setup below uses a local checkout and the same `native_toolchain_zig` fork
as this repository.

1. Add `dart_zig`, `ffi`, `hooks`, `logging`, and `native_toolchain_zig` to
   `pubspec.yaml`. Until `dart_zig` is published, use a local checkout:

   ```yaml
   dependencies:
     dart_zig:
       path: /path/to/dart_zig
     ffi: ^2.2.0
     hooks: ^2.2.0
     logging: ^1.3.0
     native_toolchain_zig:
       git:
         url: https://github.com/kingwill101/native_toolchain_zig.dart.git
         ref: cimport-generator-wip
   ```

2. Initialize the Zig build, Dart build hook, and bindings:

   ```sh
   dart pub get
   dart run dart_zig:dart_zig init
   ```

   `init` creates `zig/build.zig.zon`, `zig/build.zig`,
   `zig/src/handlers.zig`, and `hook/build.dart` for your package name.
   It points the Zig dependency at the same `dart_zig` checkout used by Dart.
   It then generates the Dart bindings. It stops if one of those files already
   exists, so it does not replace an existing Zig build or build hook.

### 2. Define your Zig API

`init` creates `zig/src/handlers.zig` with this working handler. Edit that file
to define the operations your application needs:

```zig
pub const AddRequest = struct {
    a: i64,
    b: i64,
};

pub fn add(request: AddRequest) !i64 {
    const sum = @addWithOverflow(request.a, request.b);
    if (sum[1] != 0) return error.Overflow;
    return sum[0];
}
```

Public handler functions become typed Dart methods. The request struct becomes
a Dart record, so the generated `add` method accepts `(a: int, b: int)` and
returns an `int`.
The generator creates the route and codecs; you do not write those by hand.
After changing a handler signature, regenerate from the package root:

```sh
dart run dart_zig:dart_zig generate
```

### 3. Call it from Dart

Create `bin/main.dart` in a console package (or call this code from your
application's Dart code). Replace `my_app` with the name in your `pubspec.yaml`:

```dart
import 'package:my_app/src/generated/generated.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession();
  try {
    final api = ZigApi(session);
    final result = await api.add((a: 20, b: 22));
    print(result); // 42
  } finally {
    await session.close();
  }
}
```

Run it with `dart run bin/main.dart`. The build hook compiles the Zig library
for the native target. `initializeZig()` is a no-op on the Dart VM; on Web it
loads the generated Wasm module before `createSession()`. Keep a session open
across repeated calls and close it when the application is done.

The generator writes FFI declarations, the typed `ZigApi`, and the stable
`lib/src/generated/generated.dart` import. If the package has a `web/`
directory, it also builds `web/<package_name>.wasm` and selects the Web session
factory automatically. For an existing Zig project, integrate the shared
module and build hook as described in [session setup](doc/generation.md#session-setup).

## Examples

Start with the [calls example](example/calls_example/README.md) for the smallest
session-based project:

```sh
cd example/calls_example
dart pub get
dart run bin/main.dart
```

Each example is an independent package with its own Zig source and build hook.
CLI examples use `bin/main.dart`; Flutter examples use `lib/main.dart` and run
with `flutter run`.

| Start here | Example |
| --- | --- |
| One synchronous call, using direct FFI | [minimal_example](example/minimal_example/README.md) |
| Calls, streams, signals, callbacks, native objects, Web, and cleanup together | [runtime_features_example](example/runtime_features_example/README.md) |
| Native-to-Dart request/reply through `dart_api_dl` | [native_requests_example](example/native_requests_example/README.md) |

Explore a specific feature:

| Feature | Example |
| --- | --- |
| Calls | [calls_example](example/calls_example/README.md) |
| Credited streams | [streams_example](example/streams_example/README.md) |
| Signals and state | [signals_state_example](example/signals_state_example/README.md) |
| Binary attachments | [attachments_example](example/attachments_example/README.md) |
| Async callbacks | [callbacks_example](example/callbacks_example/README.md) |
| Native handles and buffers | [native_ownership_example](example/native_ownership_example/README.md) |
| Cancellation, cleanup, restart | [lifecycle_example](example/lifecycle_example/README.md) |
| Logs and diagnostics | [diagnostics_example](example/diagnostics_example/README.md) |
| Injectable transport | [memory_transport_example](example/memory_transport_example/README.md) |
| Independent isolates | [isolates_example](example/isolates_example/README.md) |
| Web/Wasm | [web_example](example/web_example/README.md) |
| Flutter native compute | [fractal_flutter_example](example/fractal_flutter_example/README.md) |
| Continuous Flutter stream | [particle_stream_flutter_example](example/particle_stream_flutter_example/README.md) |
| Typed signal in Flutter | [typed_signal_flutter_example](example/typed_signal_flutter_example/README.md) |

## Documentation

- [Why dart_zig?](docs/why-dart-zig.mdx): direct bindings versus sessions, runtime costs, and Dart C API integration.
- [Getting started](docs/getting-started.mdx): a guided setup and first call.
- [Project layout](docs/project-layout.mdx): Zig source, build hooks, and generated files.
- [Handlers and events](docs/handlers-and-events.mdx) and
  [message types](docs/message-types.mdx): define your typed API.
- [Buffers and ownership](docs/buffers-and-ownership.mdx) and
  [cleanup and restart](docs/cleanup-and-restart.mdx): manage resources and session lifetimes.
- [Dart and Flutter](docs/dart-and-flutter.mdx),
  [Web and Wasm](docs/web-and-wasm.mdx), and
  [isolates](docs/isolates.mdx): integrate with your application.
- [Guide index](docs/index.mdx): all user guides.
- [Technical notes](doc/index.md): runtime internals and lower-level integration.

## Development

From the repository root, run:

```sh
sh tool/verify.sh
```

This runs Dart analysis and tests, Zig builds and runtime tests, standalone
Dart examples, and Web/Wasm runners. Flutter demos are separate from this script.

The build tooling currently uses the
[`cimport-generator-wip` fork of native_toolchain_zig](https://github.com/kingwill101/native_toolchain_zig.dart/tree/cimport-generator-wip).
