# dart_zig

A general Dart ↔ Zig interoperability toolkit, inspired by
[flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) and
[Rinf](https://github.com/cunarist/rinf).

A standalone, Dart-first package for VM and Web consumers. Its runtime has no
Flutter or application-protocol dependency. The included application shows
computation, typed signals, streaming, native objects, and callbacks.

## Run

From this directory, with Zig 0.15.2 or 0.16.0 on PATH:

```sh
dart pub get
dart run example/calls.dart
dart run example/run_all.dart
```

The demo exercises the generated APIs, error/cancellation paths, stream pause and
resume, asynchronous callbacks, owned buffers, and repeated session shutdown.
The earlier low-level native-to-Dart request example remains in `bin/main.dart`.

See [the example catalog](example/README.md) for small programs covering every
public feature area. The larger `bin/toolkit.dart` executable remains the boundary
validation harness.

## Calling Zig

```dart
await initializeZig(); // Loads Wasm on Web; native assets use build hooks.
final session = NativeSession(workers: 2);
final api = GeneratedApi(session);
try {
  final answer = await api.sum(const SumArgs(a: 20, b: 22));
  final counter = await NativeCounter.open(api, initial: answer);
  await counter.add(1);
  await counter.dispose();

  await for (final square in api.squares(const CountArgs(count: 5))) {
    print(square);
  }
} finally {
  await session.close();
}
```

`GeneratedApi` is the demonstration application's generated facade. Define your
own messages and operations in `schema.json`, regenerate, and implement their
handlers in `zig/src/application.zig`.

## Capabilities

| Capability | Implementation |
| --- | --- |
| Async calls | Bounded native worker pool, generated typed futures, request IDs |
| Sync calls | Explicit short native operation (`api.sumSync`) |
| Signals | Bidirectional typed endpoints, latest-value replay, binary attachments, bounded subscriptions |
| Streams | Production credits and resumable producers; pause/resume/cancel propagation |
| Native objects | Generation-checked `HandleTable(T)` with scoped lifetime leases |
| Callbacks | Async Dart callbacks and native continuations; native threads never wait synchronously on Dart |
| Types | Numeric widths and exact BigInt128, strings/bytes, maps/sets/arrays/tuples, models and unions |
| Errors | Native failures with operation/request IDs, admission errors, cancellation and deadlines |
| Memory | Reference-counted buffers, bounded reuse pool, native-buffer result ownership |
| Lifecycle | Cancellation scopes, ordered cleanup, explicit restart, asynchronous shutdown |
| Diagnostics | Host log sinks, call tracing, queue/transfer/wake and live-allocation counters |

| Backends | Native FFI, Web/Wasm via conditional exports, injectable in-memory transport |

The matching Dart/Zig models and codecs are generated from one schema. The
runtime checks both its protocol version and the application's schema fingerprint.
The binary codec uses explicit little-endian fields, checked lengths, validated
UTF-8, tag validation, and trailing-byte checks; it does not serialize Zig struct
memory layouts.

## Guides

[Documentation home](doc/index.md) introduces the toolkit. Build and preview the
site with `python3 tool/build_docs.py` and `python3 tool/serve_docs.py`.

- [Using the Dart API](doc/usage.md): calls, events, streams, callbacks, and objects.
- [Native and Web](doc/platforms.md): platform setup, isolates, and backend differences.
- [Signals and cleanup](doc/lifecycle.md): state, attachment leases, and host lifecycle.
- [Runtime and ownership](doc/runtime.md): memory, limits, errors, and shutdown.
- [Schema and generation](doc/generation.md): adding operations and native assets.
- [Documentation maintenance](doc/documentation.md): API docs and example regions.
- [Benchmarks](benchmark/README.md): measurements, workload, and limitations.
- [Implementation status](doc/PLAN.md): completed work and remaining limitations.
- [Rinf feature catalog](doc/rinf-catalog.md): API inventory, gaps, and proposed priorities.

## Verification

```sh
./tool/verify.sh
dart run benchmark/throughput.dart
```

Verification regenerates bindings, checks analysis/formatting, builds Zig, and
runs the existing demos. Linux x64 with Zig 0.15.2 and 0.16.0 has been validated.
The same portable example also runs as compiled JavaScript against Wasm. Browser
UI and runtime behavior on other operating systems remain separate validation. This private repository is an early-stage toolkit.

## Toolchain dependency

The package uses the fork at
`https://github.com/kingwill101/native_toolchain_zig.dart`, ref
`cimport-generator-wip`. No local sibling checkout is required.
