# Dart-first feature coverage

[Documentation home](index.md) · [Rinf research snapshot](rinf-catalog.md)

The core is a plain Dart package with no Flutter SDK dependency. Native FFI and
Web/Wasm live in the same package behind conditional exports. Hosts own startup,
cancellation, cleanup, and restart. The toolkit lives in its own repository; Dart FFI declarations come from the existing toolchain CLI.

## Implementation ledger

| Area | Implemented | Practical boundary |
| --- | --- | --- |
| Calls and streams | Typed futures, credited streams, cancellation, deadlines, async callbacks, short sync calls | Application handlers must cooperate; arbitrary CPU work cannot be interrupted |
| Endpoints | Typed one-way input, native emitters, Dart broadcast delivery | Send completion means admission; native dispatch is a shared consumer queue |
| State | Session-local latest snapshot, atomic subscription/replay, four overflow policies | Shared model collections are read-only by contract |
| Attachments | Typed metadata plus bytes, per-listener leases, owned native slices | Web copies out of Wasm; both backends copy input |
| Scheduling | Native stream continuations release workers while paused; fair input/continuation selection | Web uses the host event loop, not a dedicated worker; output must fit each invocation |
| Cleanup | Parent cancellation scopes, LIFO async cleanup, failure aggregation, serialized restart | Hosts trigger lifecycle events; no Flutter integration in the core |
| Types | Numeric widths, exact BigInt128, maps, sets, arrays, tuples, models, enums, unions | Restricted scalar map/set keys; Web int64 precision checked explicitly |
| Authoring | Application-owned Dart and Zig models/codecs; generated FFI declarations | Applications keep their own wire formats aligned |
| Tooling | Config, generate, watch, doctor, standalone scaffold, Web build | Local Python/shell tooling; scaffold preserves the configured Git toolchain dependency |
| Consumers | Injected native/Web/memory transports; standalone example assets; Dart isolate example | In-memory handlers supply behavior; they do not execute Zig |
| Diagnostics | Structured logs, host log adapter, queue metrics, call traces, one-way failure events | Logs/failure events are best effort under output pressure |
| Documentation | Progressive guides, existing-example regions, Dartdoc, searchable static site | Local site build; no hosting/deployment performed |

This covers the identified paths with concrete initial implementations. It is an
incubating toolkit, not a claim of complete Rinf/FRB platform or API parity.

## Reproducible checks

`tool/verify.sh` checks static analysis, native builds, the example programs,
independent Dart isolates, and compiled JavaScript with Wasm execution in Node.
Run it with the desired Zig version on PATH. It does not run a unit-test suite.

Additional commands:

- Standalone example packages: separate native assets importing the shared Zig module.
- `dart run tool/build_docs.dart`: Dartdoc and Markdown website generation.
- `sh tool/check_targets.sh`: cross-compilation only, not target-device execution.
- `dart run bin/main.dart` in `example/runtime_features_example`: portable API exercise.

Local run results are recorded in [validation](validation.md). Previous benchmark
and native-baseline logs predate this refactor and do not describe its current
performance.

## Remaining validation and future extensions

- Browser UI execution and browser-specific CSP/CORS behavior need a browser host.
- Windows/macOS/mobile runtime behavior needs the actual target or device.
- Android requires an NDK/toolchain setup; iOS distribution requires Apple tooling.
- Worker-hosted Wasm, automatic arbitrary-function inference,
  and framework-specific lifecycle adapters are extensions, not current features.
- Review API stability and add a dedicated automated regression suite before a
  production release. The current checks are executable examples and build checks.
