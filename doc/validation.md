# Validation record

On 2026-09-25, `zig build test` passed the eight native runtime tests with Zig
0.15.2 and 0.16.0. They cover event wakes, pending output order and capacity,
stream credit, cancellation cleanup, bounded signal backpressure, and mutex
contention.
`sh tool/verify.sh` passed on Linux x64 with Zig 0.15.2 and 0.16.0, covering the Zig test
step, Dart analysis, every standalone native example, and both Wasm runners.
The mutex contention test was added afterward and passed separately on both
Zig versions.
The native request example now separates its short request/reply entry point
from `bin/stress.dart`; the verification script runs both.
The `init` command was checked in a fresh Dart package under `/tmp`: it wrote
the Zig build, hook, FFI bindings, and typed API in one command. Dart analysis
and the initialized Zig build passed with Zig 0.15.2 and 0.16.0.
Cross-target builds of the calls example passed for macOS and Windows with
Zig 0.16.0, and for macOS and Windows with Zig 0.15.2. Android and iOS
cross-target builds were blocked by missing target libc or SDK headers in the
Linux environment before runtime validation.

On 2026-09-24, the standalone projects were checked on Linux x64:

- `zig build --build-file zig/build.zig` completed in the core package and the
  runtime feature and native request examples with Zig 0.15.2 and 0.16.0.
- `dart analyze lib bin` completed in the core package and those two examples.
- `dart run bin/main.dart` completed the portable runtime examples after their
  `bin/` cleanup.
- `dart run bin/main.dart` completed the native request/reply example.
- The minimal example generated its FFI binding, passed Dart analysis, built
  with Zig 0.15.2 and 0.16.0, and printed `20 + 22 = 42`.
- The feature example's Zig Wasm build completed with Zig 0.15.2 and 0.16.0;
  `sh tool/build_web.sh` compiled its JavaScript with the active 0.16.0 toolchain.
- `node tool/run_web.mjs` completed the portable examples against that Wasm asset.
- `dart run tool/build_docs.dart` generated the guides and Dart API reference.
- All 11 focused examples generated FFI bindings with
  `dart run dart_zig:dart_zig generate`; none uses generated Zig
  models.
- All 11 focused Zig projects built with Zig 0.15.2 and 0.16.0. Their Dart
  sources passed `dart analyze`.
- The calls, streams, signals/state, attachments, callbacks, native ownership,
  lifecycle, diagnostics, memory transport, and isolates examples ran on the
  Dart VM. The focused Web example compiled its Wasm and JavaScript and its
  Node runner printed `Web sum: 42`.
- The documentation build included all focused example pages.
- The shared native export source built with both Zig versions in all session
  examples. No session example keeps a local copy of the runtime export file.
- The native request and full feature examples regenerated separate bindings
  for their application-specific exports. Their native assets exposed those
  symbols alongside the shared runtime symbols, and both Dart VM runs passed.
- The focused Web and full feature Wasm builds passed with both Zig versions;
  their Node runners completed against the rebuilt assets.
- `sh tool/verify.sh` completed after the shared-export migration, covering
  Dart analysis, Zig 0.16.0 builds, native runs, and both Wasm runners.

These checks exercise the current Linux VM and Node Wasm paths. Browser UI and
other operating systems need separate runtime checks. Earlier records from
before the example split are historical and are not evidence for the current
layout.
