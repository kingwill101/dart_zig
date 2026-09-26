# dart_zig

Dart runtime primitives and Zig modules for calls, signals, streams, callbacks,
owned buffers, and cleanup. The core package has no Flutter dependency or
application protocol. Native Dart applications use a build hook to compile their
own Zig asset; Web applications use the Wasm transport.

## Getting started

Start in an existing Dart package, or create one with `dart create -t console my_app`.
Use Zig 0.15.2 or 0.16.0. A direct Zig export needs only
`native_toolchain_zig`: generate its FFI binding and call it like a Dart
function. It does not need a `dart_zig` session or a binary codec. The
[direct FFI setup](doc/generation.md#direct-ffi) gives the files and commands
for a new or existing package.

Add `dart_zig` when the application needs native workers, calls with
cancellation, streams, signals, callbacks, or Web/Wasm. From the package root:

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

The generator writes FFI declarations, an asset-specific `createSession()`
factory, and typed endpoints from public functions in `zig/src/handlers.zig`.
The initialized handler accepts two numbers:

```dart
final sum = await ZigApi(session).add((a: 20, b: 22));
```

Import `ZigApi` from your generated `lib/src/generated/api.g.dart`.
The [session setup](doc/generation.md#session-setup) shows the Zig handler,
session cleanup, and integration with an existing build. Add public handler
functions in `zig/src/handlers.zig`, then rerun `generate`.

## Run the examples

Each example is a standalone Dart package with its own `zig/` and `hook/`:

```sh
cd example/minimal_example
dart pub get
dart run bin/main.dart
```

The [minimal example](example/minimal_example/README.md) shows one generated
direct FFI call. For a session-based application:

```sh
cd example/calls_example
dart pub get
dart run bin/main.dart
```

The [calls example](example/calls_example/README.md) is the smallest
session-based project. The [runtime feature example](example/runtime_features_example/README.md)
combines calls, streams, signals, callbacks, native objects, Web, and cleanup
as an advanced integration case. The [native request example](example/native_requests_example/README.md)
demonstrates native-to-Dart request/reply using `dart_api_dl`:

```sh
cd example/native_requests_example
dart pub get
dart run bin/main.dart
```

Run `./tool/verify.sh` from the repository root for the current validation
commands. See [the documentation](doc/index.md) for the API and platform guides.

Focused, standalone projects each have their own `pubspec.yaml`, `zig/`, and
build hook. CLI examples use `bin/main.dart`; Flutter examples use
`lib/main.dart`:

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

The calls, streams, diagnostics, lifecycle, transport, isolates, Web, signals,
state, attachments, and Flutter examples derive dispatch and typed codecs from
one Zig handler module. Callbacks and native ownership use Zig route declarations to
generate typed codecs. Native requests show the lower-level bridge API. Each compiles the shared
Zig export source and uses `createSession()` from its generated Dart binding.
No runtime export file is copied into an application.

The Dart dependency on `native_toolchain_zig` points to
[the `cimport-generator-wip` fork](https://github.com/kingwill101/native_toolchain_zig.dart/tree/cimport-generator-wip).
