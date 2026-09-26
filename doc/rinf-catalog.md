> Research snapshot: the recommended implementation order below predates the follow-up. Current scope is Dart-first, with Web in the same package and host-controlled cleanup. See [feature coverage](gap-implementation.md).

# Rinf feature and API catalog

[Package guide](../README.md) · [Current implementation](PLAN.md)

## Scope and evidence

Reviewed on 2026-09-23: all 17 pages in the Rinf documentation sidebar, plus
public Dart/Rust APIs and generator source. The documentation website was fetched
directly after the browsing service could not open it. No Rinf app was built or
benchmarked during this review.

Source checks are pinned to commit
[`b995c99e60c31d32f16cd914d90395c4494a2771`](https://github.com/cunarist/rinf/tree/b995c99e60c31d32f16cd914d90395c4494a2771).
Both package manifests at that revision identify version **8.10.1**. This describes
the inspected source snapshot, not a claim about the latest published release.
The website has no version selector, and some FAQ material explicitly dates from
2024. Differences between the guide and source are called out below.

**Status labels:** “present” means visible in our current source; it does not imply
cross-platform certification. “Partial” means related primitives exist, but the
complete developer-facing capability is missing. Recommendations and proposed
names below are design proposals, not implemented APIs.

## 1. What Rinf offers as a framework

Rinf organizes Flutter applications around native business logic and a Dart UI.
Its boundary consists of two directional message streams. Native actors own
application state; Flutter observes view data. This is an architectural
recommendation, not an actor framework supplied by Rinf.
[Introduction](https://cunarist.github.io/rinf/introduction/),
[state management](https://cunarist.github.io/rinf/state-management/).

The useful target for our reusable package is broader: a Dart-compatible core,
with optional Flutter integration, supporting both request/response work and
independently produced events. Applications should be able to choose where their
state lives without adopting a prescribed application architecture.

## 2. Message and signal APIs

| Rinf surface | What it provides |
| --- | --- |
| `#[derive(RustSignal)]` | Declares a native-to-Dart typed endpoint. Requires serialization. |
| `send_signal_to_dart(&self)` | Emits a message on that endpoint. |
| `Type.rustSignalStream` | Generated Dart stream of `RustSignalPack<Type>`. |
| `Type.latestRustSignal` | Nullable cached most recent pack, available to newly mounted UI. |
| `#[derive(DartSignal)]` | Declares a Dart-to-native typed endpoint. Requires deserialization. |
| `message.sendSignalToRust()` | Generated Dart send method. |
| `Type::get_dart_signal_receiver()` | Obtains the receiver for that message type. |
| `receiver.recv().await` | Waits for the next `DartSignalPack<Type>`. |
| `SignalPiece` | Marks nested structs/enums used inside endpoint messages. |

Subscribe with `Stream.listen` when every message needs handling. `StreamBuilder`
may rebuild using only the latest snapshot within a render frame; that is widget
scheduling behavior, not an acknowledgment that every event was processed.
[Messaging](https://cunarist.github.io/rinf/messaging/),
[tutorial](https://cunarist.github.io/rinf/tutorial/).

### Receiver and broadcast semantics

The current Rust receiver is **single-active-consumer**: obtaining/cloning a newer
receiver supersedes the earlier one, whose pending/next receive returns `None`.
`SignalSender.send` appends to a `VecDeque`; this implementation has no capacity
budget or asynchronous admission wait. The sender's return type is `void`/`()`,
so it is not an application processing acknowledgment.
[Signal traits](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/rust_crate/src/signal_trait.rs),
[channel implementation](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/rust_crate/src/channel.rs).

Generated Dart endpoints use `asBroadcastStream()` and a separate latest-value
field. Reading that field is distinct from automatically replaying a value to a
new subscription. These endpoints and dispatch registration are generated as
static/top-level state.
[Generator](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/rust_crate_cli/src/tool/generate.rs).

### Binary attachments

`RustSignalBinary` and `DartSignalBinary` add a separate payload to the typed
message. Rust sends with `send_signal_to_dart(binary)`; generated Dart sends with
`sendSignalToRust(binary)`. Packs expose `message` and `binary` (`Vec<u8>` or
`Uint8List`). Attachments bypass model serialization.
[Messaging](https://cunarist.github.io/rinf/messaging/).

On native platforms, the inspected outbound implementation uses
`allo_isolate::ZeroCopyBuffer` for message bytes and binary bytes. Incoming binary
bytes are copied with `to_vec()`. Model serialization/deserialization still costs
work and allocations. Do not interpret this as end-to-end zero-copy, or extend
native transfer behavior to Web without separate evidence.
[Native transport](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/rust_crate/src/interface_os.rs),
[derive implementation](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/rust_crate_proc/src/lib.rs).

## 3. Serialization and type coverage

Rinf uses Serde/Bincode with matching generated Dart representations.

| Category | Documented Rust coverage | Current dart_zig example |
| --- | --- | --- |
| Signed integers | i8, i16, i32, i64, i128 | i64 |
| Unsigned integers | u8, u16, u32, u64, u128 | u32, u64 |
| Floating point | f32, f64 | f64 |
| Text and bool | char, String, &str, bool | string, bool |
| Collections | Fixed arrays, Vec, HashSet, BTreeSet | Lists and bytes |
| Maps | HashMap, BTreeMap | Missing |
| Wrappers | Option, Box | Nullable values; no separate box concept |
| Tuples | Unit through four-element tuples | void result; no tuple values |
| Structured data | Nested structs, plain and data-carrying enums | Models, enums, tagged unions |

This is an inventory, not a promise that every Rust representation maps directly
to a built-in Dart type. In particular, a future Zig 128-bit mapping needs an
explicit Dart representation and range policy.
[Field types](https://cunarist.github.io/rinf/field-types/).

`#[serde(skip)]` excludes fields/variants from transfer. Rinf rejects incompatible
custom serialization attributes rather than guessing the resulting wire shape.
The inspected banned set includes conditional/directional skipping, `with`,
custom serializer/deserializer functions, and `flatten`.
[Field attributes](https://cunarist.github.io/rinf/field-attributes/),
[attribute validation](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/rust_crate_proc/src/lib.rs).

**Design implication:** prioritize maps, fixed arrays, smaller numeric widths,
field documentation/naming, and clear unsupported-type errors. Runtime pointers,
allocators, locks, and process-local state must never become accidental message
fields. Wire projection metadata should explicitly select what crosses the boundary.

## 4. Lifecycle and low-level APIs

| API | Contract in the inspected source |
| --- | --- |
| `initializeRust(assignRustSignal, {compiledLibPath})` | Prepares transport/dispatch and starts native `main`; returns `Future<void>`. |
| `assignRustSignal` | Generated endpoint-name to decoder/delivery callback map. |
| `finalizeRust()` | Synchronously requests native shutdown and waits; Web implementation has no effect. |
| `sendDartSignal(endpointSymbol, messageBytes, binary)` | Public low-level byte send entry point used by generated methods. |
| `RustSignalPack<T>` | Dart container holding a decoded message and binary attachment. |
| `write_interface!()` | Emits native/Web entry glue once at the hub crate root. |
| `dart_shutdown().await` | Waits for the Dart shutdown signal; keeps native async main alive. |
| `DartSignalPack<T>` | Native container holding the decoded message and attachment. |
| `SignalReceiver<T>` / `SignalSender<T>` | Native queue receiver/sender types. |

Sources: [Dart entry points](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/flutter_package/lib/rinf.dart),
[Dart pack](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/flutter_package/lib/src/structure.dart),
[interface macro](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/rust_crate/src/macros.rs),
[shutdown future](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/rust_crate/src/shutdown.rs),
[native pack](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/rust_crate/src/interface.rs).

The crate also reexports low-level `signal_channel`, `start_rust_logic`,
`send_rust_signal`, and `AppError`; several are hidden from its normal API docs.
`AppError` covers missing isolate/bindings and encode/decode failures. They are
implementation-facing building blocks, not an automatic application error protocol.
[Exports](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/rust_crate/src/lib.rs),
[errors](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/rust_crate/src/error.rs).

### Flutter integration and restart

The documented native hot-restart behavior restarts Rust logic, not the compiled
native library. Rust source changes require rebuilding. Web restart behavior is
different. The guide connects `finalizeRust` to `AppLifecycleListener` for orderly
exit, while acknowledging that abrupt process termination cannot guarantee cleanup.
[FAQ](https://cunarist.github.io/rinf/frequently-asked-questions/#will-changes-made-to-rust-code-take-effect-upon-dart-s-hot-restart),
[graceful shutdown](https://cunarist.github.io/rinf/graceful-shutdown/).

For our package, use an optional Flutter adapter around explicit session ownership.
Retain asynchronous `close()`. Add restart generations, cancellation of old work,
and invalidation of old ports/handles so late results cannot reach a new session.
A restart demonstration must use actual Flutter hot restart; repeated Dart session
construction alone does not establish this behavior.

## 5. Tooling, configuration, and platform experience

| Command/configuration | Purpose |
| --- | --- |
| `flutter pub add rinf` + `cargo install rinf_cli` | Install runtime and developer tooling. |
| `rinf template` | Add the native hub/workspace and Flutter integration scaffolding. |
| `rinf gen` | Generate Dart types and signal endpoints from annotated Rust. |
| `rinf gen -w` / `--watch` | Regenerate after source edits. |
| `rinf config` | Show resolved configuration. |
| `rinf.gen_input_crates` | Select native crates scanned for messages; default hub. |
| `rinf.gen_output_dir` | Select the generated Dart output directory. |
| `rinf wasm [-r/--release]` | Build the WebAssembly module. |
| `rinf server [-r/--release]` | Provide the Flutter Web run command and required headers. |

Sources: [template](https://cunarist.github.io/rinf/applying-template/),
[messaging generation](https://cunarist.github.io/rinf/messaging/),
[configuration](https://cunarist.github.io/rinf/configuration/),
[CLI command definitions](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/rust_crate_cli/src/tool/entry.rs).

Native applications use normal `flutter run` / `flutter build` commands, with
Cargokit handling native compilation/linking. Web builds add wasm-bindgen/
wasm-pack and require appropriate cross-origin headers plus Wasm MIME handling.
Rinf documents Linux, Android, Windows, macOS, iOS, and Web support; eLinux is
experimental. Those are Rinf's documented support claims, not platforms exercised
by this review.
[Running and building](https://cunarist.github.io/rinf/running-and-building/),
[introduction](https://cunarist.github.io/rinf/introduction/).

The toolchain page provides a version matrix and setup checks (`rustc --version`,
`flutter doctor`). The migration guide requires coordinated Dart/native versions
and explains the v8 transition from Protobuf to Rust declarations and `rinf gen`.
[Toolchains](https://cunarist.github.io/rinf/installing-toolchains/),
[upgrading](https://cunarist.github.io/rinf/upgrading/).

Our analogue should build on the existing native-toolchain hook and CLI. A package
scaffold, generation watch mode, resolved configuration, toolchain diagnostics,
and CI generation-drift command are more useful than introducing a second FFI
binding generator.

## 6. Debugging, errors, testing, and ecosystem integration

- `debug_print!` delegates development output to Flutter; the docs describe it as
  debug-only. `show-backtrace` enables native panic backtraces.
  [Printing](https://cunarist.github.io/rinf/printing-for-debugging/),
  [configuration](https://cunarist.github.io/rinf/configuration/).
- Application error handling is explicit. The guide recommends Rust `Result`,
  contextual errors, and logging through libraries such as `tracing`. It does not
  define a general generated Dart exception mapping.
  [Error handling](https://cunarist.github.io/rinf/error-handling/).
- Native logic can be tested independently with `cargo test`. Boundary tests build
  a library, pass `compiledLibPath` to initialization, and use Flutter tests.
  [Unit testing](https://cunarist.github.io/rinf/unit-testing/).
- Actor examples use external `messages`/Tokio APIs. The `bevy` feature marks
  `DartSignalPack` as a Bevy event and is documented as experimental. These should
  inspire optional integrations, not mandatory dependencies of our core.
  [State management](https://cunarist.github.io/rinf/state-management/),
  [configuration](https://cunarist.github.io/rinf/configuration/).
- Rinf's FAQ limits its intended scope to Flutter GUI apps. Our standalone Dart
  package/CLI support is worth preserving alongside a Flutter adapter.
  [FAQ](https://cunarist.github.io/rinf/frequently-asked-questions/#can-i-use-this-in-pure-dart-projects).

### Documentation/source qualifications

1. The FAQ's custom-library snippet omits the positional dispatch map; current
   public `initializeRust` requires it. Use the source signature above.
2. Some Rust signal trait comments reverse the zero-copy direction. The messaging
   guide and transport implementation establish native Rust-to-Dart ownership
   transfer and incoming copies; use those as the stronger evidence.
3. The `debug_print!` source constructs its formatted string outside the debug-only
   send block. Do not infer that release builds necessarily avoid formatting cost.
4. Broad FAQ panic-recovery statements depend on target/runtime. They do not imply
   Zig traps can safely become Dart exceptions. Document Zig error-union handling
   and unrecoverable failures separately.

Evidence: [Dart API](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/flutter_package/lib/rinf.dart),
[signal traits](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/rust_crate/src/signal_trait.rs),
[native transfer](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/rust_crate/src/interface_os.rs),
[debug macro](https://github.com/cunarist/rinf/blob/b995c99e60c31d32f16cd914d90395c4494a2771/rust_crate/src/macros.rs),
[FAQ](https://cunarist.github.io/rinf/frequently-asked-questions/).

## 7. Gap assessment against dart_zig

This comparison is based on our [session](../lib/src/session.dart),
[signal bus](../lib/src/signal_bus.dart), [runtime](../zig/src/runtime/runtime.zig),
[example Dart API](../example/runtime_features_example/lib/src/models.dart), and
[build hook](../hook/build.dart). It is a source-level assessment.

| Capability | Status | Concrete gap/action |
| --- | --- | --- |
| Typed calls and results | Present in the example | Keep application wrappers alongside event APIs. |
| Typed native-to-Dart events | Partial | Add generated native emitters; remove raw route/codec work for users. |
| Independent Dart-to-native signals | Partial | `call(signal: true)` still creates a task/result obligation; add a true endpoint send/receive contract. |
| Latest-value state | Missing | Session-scoped snapshot and subscription semantics. |
| Typed message plus binary attachment | Missing | Byte calls/buffers exist, but frames have one payload and no typed attachment envelope. |
| Rich application types | Partial | Maps, sets, fixed arrays, tuples, smaller widths, f32, 128-bit policy. |
| Type-driven Zig authoring | Out of scope | Applications own their Dart and Zig models and codecs. |
| Streams, callbacks, cancellation, deadlines | Present | Preserve; Rinf's guides do not expose equivalent first-class RPC surfaces. |
| Native object handles and owned buffers | Present | Preserve ownership semantics; avoid forcing objects into serialized messages. |
| Bounded admission and delivery | Present | Expose configurable event/state policies without removing budgets. |
| Nonblocking native task scheduling | Partial | Blocking worker pool; paused streams can occupy workers. |
| Async shutdown | Present | Add lifecycle coordination for independently owned producers. |
| Flutter lifecycle / hot restart | Missing | Adapter and actual device/desktop restart verification. |
| Standalone Dart usage | Present | Keep Flutter dependencies outside the core. |
| Multiple native assets | Partial | Injectable generated adapter; only same-library alternate adapter exercised. |
| CLI workflow | Partial | Scripts exist; no reusable package scaffold/watch/doctor experience. |
| Platform distribution | Partial | Linux validated; other native targets and Web remain unverified/unsupported here. |
| Developer diagnostics | Partial | Logs/counters exist; add sink adapters, queue pressure, and task tracing. |
| Testing support | Partial | Demos and benchmarks exist; reusable harness/fake transport not supplied. |

## 8. Recommended design direction

### A. Make endpoints the next public abstraction

Proposed names, subject to API design:

| Abstraction | Intended semantics |
| --- | --- |
| `Signal<T>` | Ephemeral events; typed send/receive; no request result expected. |
| `StateSignal<T>` | Latest snapshot plus subscriptions; explicit cache and replay semantics. |
| `SignalPack<T>` | Typed metadata plus an optional binary attachment. |
| `NativeCall<T>` | Existing correlated operation/result/cancellation semantics, optionally typed by a facade. |
| Native `Receiver(T)` | Typed mailbox integration usable by an application dispatcher or scheduler. |

Keep endpoints session-owned. Specify whether a send future means admission or
processing; use admission for signals and an explicit call when processing needs
acknowledgment. Define native single-consumer versus broadcast behavior explicitly.
State subscription needs an atomic snapshot/subscription boundary or sequence
numbers to avoid missing an update between reading the latest value and listening.

Offer distinct overflow policies: wait/reject for commands, coalesce-latest for
state, and configurable drop/error for telemetry. Bound bytes as well as item
counts. Dropping command messages should require an explicit application choice.

### B. Make binary transfer ergonomic and safe

Add an envelope with metadata and attachment ownership separated. Start with a
safe copied `Uint8List` mode and an explicit owned-buffer mode. For broadcast
attachments, define per-listener leases or immutable shared ownership; one
subscriber must not invalidate another subscriber's view by disposing a buffer.
Latest-value caching must release the previous attachment on replacement/close.
This is a protocol change and should increment the transport version.

### C. Keep execution pluggable

A useful general package should supply bounded mailboxes, cancellation scopes,
completion callbacks, timers/deadlines, and a dispatcher contract that can suspend
work without occupying a worker. Keep the existing worker pool as one backend.
Permit applications to integrate their own event loop. Building a full Tokio-like
runtime is a separate project and is unnecessary for the first useful endpoint API.

### D. Improve authoring and packaging together

Applications maintain Dart and Zig models, codecs, and typed wrappers alongside
their dispatch code. Preserve the CLI for Dart FFI declarations.

The eventual separate repository can contain a Zig core, a plain Dart package,
an optional Flutter adapter, and generation/tooling support. Avoid splitting into
many published packages until the boundaries have been exercised by consumers.

## 9. Suggested implementation order and acceptance criteria

These are proposed future checks, not tests executed by this research task.

1. **Typed endpoints and state.** Generate both directions; prove independent
   unsolicited emission, multiple Dart listeners, receiver ownership, late state
   subscription without missed updates, and bounded overload behavior.
2. **Binary signal packs.** Prove metadata/attachment separation, ownership after
   session close, multiple listeners, replacement/disposal of cached state, and
   zero outstanding native allocations. Benchmark copy costs by direction.
3. **Lifecycle and scheduling.** Exercise Flutter hot restart repeatedly with
   work in flight; reject stale-generation results; close external producers;
   prove paused streams do not starve unrelated work on the selected backend.
4. **Generation ergonomics.** Add watch/config/doctor/scaffold workflows, richer
   types, useful source-location diagnostics, API evolution rules, and
   reproducible output. Exercise a truly separate consumer/native library.
5. **Distribution and integrations.** Validate native platform packaging and
   debug/release behavior. Add a fake transport and reusable boundary-test
   harness. Treat Web as a separate transport/backend project with explicit
   ownership, scheduling, and lifecycle constraints.

**Recommended first slice:** typed bidirectional endpoints plus latest-value state.
It addresses a visible Rinf usability gap with the primitives we already have.
Design attachment ownership alongside it, then implement attachments as the next
protocol increment. Flutter lifecycle support should follow before claiming a
comparable Flutter development experience.

## Documentation navigation inventory

| Page | Contribution to this catalog |
| --- | --- |
| [Introduction](https://cunarist.github.io/rinf/introduction/) | Architecture and platform scope |
| [Installing toolchains](https://cunarist.github.io/rinf/installing-toolchains/) | Requirements and diagnostics |
| [Applying template](https://cunarist.github.io/rinf/applying-template/) | Scaffold and workspace integration |
| [Running and building](https://cunarist.github.io/rinf/running-and-building/) | Native/Web build paths |
| [Messaging](https://cunarist.github.io/rinf/messaging/) | Signal APIs and attachments |
| [Field types](https://cunarist.github.io/rinf/field-types/) | Serializable type coverage |
| [Field attributes](https://cunarist.github.io/rinf/field-attributes/) | Wire projection constraints |
| [Tutorial](https://cunarist.github.io/rinf/tutorial/) | End-to-end UI/event usage |
| [State management](https://cunarist.github.io/rinf/state-management/) | Actor guidance versus core features |
| [Error handling](https://cunarist.github.io/rinf/error-handling/) | Application error responsibilities |
| [Printing](https://cunarist.github.io/rinf/printing-for-debugging/) | Debug output integration |
| [Graceful shutdown](https://cunarist.github.io/rinf/graceful-shutdown/) | Exit integration and limitations |
| [Configuration](https://cunarist.github.io/rinf/configuration/) | Generator settings and optional features |
| [Unit testing](https://cunarist.github.io/rinf/unit-testing/) | Native and boundary-test workflows |
| [Upgrading](https://cunarist.github.io/rinf/upgrading/) | Version coordination and migration history |
| [FAQ](https://cunarist.github.io/rinf/frequently-asked-questions/) | Restart, loading, scope, and dated caveats |
| [Contribution](https://cunarist.github.io/rinf/contribution/) | Upstream references and project contribution paths |
