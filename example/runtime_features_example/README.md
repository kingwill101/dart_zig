# Runtime feature example

This directory is a standalone Dart package. Its `zig/build.zig.zon` depends on
the reusable `dart_zig` Zig package at `../../../zig`; `zig/build.zig` imports
its runtime module and shared exports. The package owns its Dart and Zig
models, codecs, dispatcher, two extra synchronous exports, build hook, and
generated FFI bindings.

From this directory:

```sh
dart pub get
dart run dart_zig:dart_zig generate
dart run bin/main.dart
dart run demo/toolkit.dart
```

`bin/main.dart` runs the portable feature sequence and ends with
`All portable examples completed.` Run one `demo/*.dart` file directly when
you want to focus on a single API.

To regenerate FFI bindings after changing native exports:

```sh
dart run dart_zig:dart_zig generate
```

The command uses `native_toolchain_zig` for FFI declarations. The typed
`FeatureApi` and Dart codecs are application source in `lib/src/models.dart`;
their Zig counterparts are in `zig/src/models.zig`. Keep their wire formats
aligned when editing either side.

## Follow the code

`lib/runtime_features_example.dart` exports the generated session entrypoint
and the application's models. `demo/run_all.dart` invokes the portable demos
in order; each file shows one consumer pattern and its cleanup. The Zig
`application.zig` dispatcher implements the operations declared in
`zig/src/models.zig`. This example deliberately keeps a larger, hand-authored
protocol to exercise runtime boundaries; the smaller examples show the
generated handler route used for ordinary applications.

| Entry point | Demonstrates |
| --- | --- |
| `demo/calls.dart` | Synchronous and asynchronous calls |
| `demo/signals.dart` | Typed broadcasts |
| `demo/state_and_attachments.dart` | State replay and binary attachments |
| `demo/streams.dart` | Credit-based streams and pause/resume |
| `demo/callbacks.dart` | Async Dart callbacks |
| `demo/native_objects.dart` | Session-owned handles |
| `demo/owned_buffers.dart` | Buffer ownership and release |
| `demo/collections.dart` | Maps, sets, arrays, tuples, models, and unions |
| `demo/errors_and_cancellation.dart` | Errors, cancellation, and deadlines |
| `demo/cleanup_and_restart.dart` | Ordered cleanup and restart |
| `demo/diagnostics.dart` | Logging and counters |
| `demo/in_memory.dart` | Injectable transport |
| `demo/overflow_policies.dart` | Bounded coalescing |
| `demo/isolates.dart` | Independent VM isolates |
| `demo/backend_injection.dart` | Application-owned native asset adapter |

`bin/main.dart` runs the portable examples. For Web, run
`sh tool/build_web.sh` and `dart run tool/serve_web.dart`; the same Wasm
build can be exercised with `node tool/run_web.mjs`.
