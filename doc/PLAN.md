> This records the earlier native baseline. See the [current coverage ledger](gap-implementation.md) for the Dart-first, Web, endpoint, and tooling follow-up.

# General Dart/Zig interoperability toolkit

## Goal and boundaries

Provide function calls, typed signals, streams, native objects, and asynchronous
Dart callbacks inspired by flutter_rust_bridge and Rinf. All implementation,
generated files, documentation, and measurements stay in this example directory.
The existing toolchain CLI generates every Dart FFI declaration. The package
remains standalone, with a Git dependency on the fork's cimport-generator-wip branch.

## Design

- A reusable Zig runtime accepts application dispatch handlers; examples supply
  their own operations. No HTTP or other application protocol in the runtime.
- A bounded native executor handles asynchronous calls off the Dart isolate.
  Short synchronous calls have a separate explicit API.
- Versioned frames identify calls, results, signals, stream items, errors,
  cancellations, and callback requests/results.
- Reusable batch descriptors and coalesced Dart API wake notifications amortize
  FFI overhead. Queues have count and byte budgets. Consumers retain explicit
  ownership of native buffers.
- Typed codecs and application wrappers are generated from a shared schema;
  low-level FFI declarations come from native_toolchain_zig's CLI.
- Native objects use generation-checked handles and scoped leases.
- Cancellation and shutdown are explicit, session scoped, and observable.
  No native code synchronously waits on an asynchronous Dart callback.
- Diagnostics expose queue/transfer counters. Performance claims require actual
  benchmark results, with workload, toolchain, and copy behavior documented.

## Implementation sequence

1. Foundation: owned buffers, checked binary codecs, generation-checked handles,
   cancellation, ABI/status/frame definitions, portable blocking wake primitive.
2. Runtime: bounded input/output, native worker, application dispatch, batching,
   protocol handshake, calls/signals/stream/callback frames, orderly shutdown.
3. Dart: generated FFI, session ownership, futures, typed streams/signals,
   cancellation/deadlines, native objects, asynchronous callback registry.
4. Generation: shared schema, Zig model/dispatch metadata and Dart typed codecs
   and API wrappers; reproducible scripts for both schema and FFI generation.
5. Demonstrations: general computation, typed events, stateful native object,
   streaming, native-to-Dart callback, cancellation, repeated session lifecycle.
6. Verification: standalone analysis/build/demo on Zig 0.15.2 and 0.16.0,
   binding regeneration drift checks, throughput/latency measurements.

## Implementation status

All six implementation stages are present:

- `zig/src/runtime/`: buffers and bounded pool, generation-checked handles,
  cancellation tokens, codecs, frame queues, worker executor, and OS wakeups.
- `zig/src/api.zig`: Dart API DL initialization and coalesced port notifications.
- `lib/src/session.dart`: calls, streams, callbacks, deadlines, batch delivery,
  payload admission budgets, and asynchronous shutdown.
- `lib/src/native_buffer.dart` and `native_object.dart`: explicit ownership and
  a sample typed native object facade.
- `schema.json` and `tool/`: generated Dart/Zig models and typed application APIs;
  CLI-generated FFI and generated runtime adapters. Six generated artifacts are
  checked for reproducibility.
- `bin/toolkit.dart`: typed calls/signals, stream pause/resume, callback reentry,
  malformed input, stale handles, concurrent counter updates, paused signal
  overflow, cancellation, deadlines, retained buffers, repeated sessions, and
  shutdown inside a signal listener. `bin/main.dart` retains the lower-level
  native-request/streamed-reply demonstration.

## Verification and measurement

Run `./tool/verify.sh` with each compiler on PATH. It checks generated-file drift,
Dart analysis and formatting, Zig formatting/build, then executes both demos.
The full verification passed on Linux x64 with both Zig 0.15.2 and 0.16.0
using Dart 3.13.4. The per-compiler transcripts are `validation-zig-0.15.2.log` and
`validation-zig-0.16.0.log`. These are executable demonstration checks, not a
new unit-test suite.

`benchmark/throughput.dart` measures synchronous calls, serial async latency,
concurrent async calls, copied/owned byte results, and batch sizes 1/32. It checks
results and verifies that buffer counts return to zero. Raw results and measured
ranges are in `../benchmark/`; no FRB/Rinf performance comparison is claimed.

## Remaining limitations

- This is a prototype, temporarily using the parent toolchain through a path
  dependency. The shared schema is explicit; arbitrary Zig API inference is not
  implemented. Synchronous schema generation currently supports one signature.
- The executor uses blocking workers. Paused native streams occupy workers;
  application work must cooperate with cancellation.
- Linux x64 is the validated runtime environment. Windows/macOS runtime behavior,
  Flutter hot restart, Web, and a separately compiled custom native asset remain
  unverified. The alternate adapter demo uses the same example library.
- Borrowed native-buffer views require their owner to remain reachable and
  undisposed. Finalizers are a fallback; explicit disposal is preferred.
- No publication, extraction into another repository, or commit is part of this
  implementation. All source changes are confined to this example directory.
