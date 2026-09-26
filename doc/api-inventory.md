# Dart and Zig API inventory

This inventory describes the active workspace on 2026-09-25. “Used” means a
reference in this repository, excluding generated FFI declarations where noted.
It does not prove that an API has no external consumers. The standalone examples
and the advanced integration fixture are application code, not core library API.

## Dart surface

| API | Current use | Recommendation |
| --- | --- | --- |
| `dart run dart_zig:dart_zig init`, `generate` | `init` creates Zig and hook files and generates bindings; `generate` refreshes FFI and typed APIs. All session examples use the output. | Keep both. They are the setup path. |
| Generated `createSession`, `ZigApi`, `ProtocolApi`, request/response codecs | Every session example uses a generated session factory. Calls, streams, events, diagnostics, isolates, and Web use `ZigApi`; callbacks and native ownership still use `ProtocolApi`. | Keep generated APIs. Consolidate the two Zig declaration forms before retiring `ProtocolApi` and its dump files. |
| `NativeSession`, `CallEndpoint`, `StreamEndpoint`, `TypedCall` | Generated APIs and the examples use calls, credited streams, cancellation, and session closure. | Keep as the main Dart API. |
| `NativeSession.call`, `stream`, `sendSignal`, `callBuffer` and their raw result types | Typed endpoints build on the raw methods. The advanced fixture also uses raw calls to exercise invalid input, cancellation, and owned buffers. | Keep as advanced APIs; do not force ordinary applications to use them. |
| `SignalEndpoint`, `SignalPack`, `NativeBuffer` | Generated event APIs, attachment example, and owned-buffer example use them. State replay depends on constructing its endpoint before an update. | Keep. Explicit ownership and eager endpoint construction are functional requirements. |
| `registerTypedCallback`, `CallbackRegistration`, raw `registerCallback` | Focused callback example uses typed registration; the advanced fixture still uses the raw method to test a stalled callback. | Keep typed and raw forms. The raw form is an escape hatch. |
| `NativeBridge`, `NativeRequest`, `ReplyKind`, generated `createBridge` | Native request example uses all of these for Zig-to-Dart work and replies. No session example needs the bridge. | Keep the feature, but document it as native-only and optional. Consider a separate native entrypoint and bridge-only exports if package/asset size matters. |
| `BinaryWriter`, `BinaryReader`, `MessageEncoder`, `MessageDecoder`, `BinaryCodec` | Generator output and raw integration fixture use them; `MemoryTransport` uses generated codecs. | Keep as the wire-extension contract. Generated applications should not need to hand-write them. |
| `SessionTransport`, `MemoryTransport`, `NativeTransport`, `WebTransport` | Session implementation uses the transport interface. In-memory and advanced examples inject transports; the advanced fixture inspects native/Web backends for synchronous app-specific FFI. | Keep transport injection as advanced API. Keep implementation types out of the default entrypoint. |
| `RuntimeBindings` and the native ABI types | Generated asset adapter, native transport, bridge, and native buffers use this contract. Application code does not implement it. | Keep the contract in `native.dart` and the generated adapter's internal import; it is no longer re-exported by `dart_zig.dart`. |
| `CancellationScope`, `CleanupScope`, `RestartableResource` | Lifecycle and advanced examples use each. They were requested as general cleanup facilities. | Keep even though the session does not depend on every type. |
| `RuntimeDiagnostic`, `forwardNativeLogs`, `NativeException`, `SessionStats` | Diagnostics example and error scenarios use them. | Keep. |
| `SignalBus`, `OverflowPolicy` | Typed event layer uses the bus; overflow example uses the public policy and bus. | Keep the bus as an advanced reusable primitive. |

### Dart exposure cleanup

The shared Web transport no longer assumes an application-specific `dz_web_sum`
export; the advanced example owns that binding. `PendingCall` and
`SignalListener` are private implementation types. `native.dart` and `web.dart`
are the platform entrypoints; the duplicate entrypoints and the unused shared
Web binding stub were removed. `RuntimeBindings` remains available from
`native.dart` for advanced consumers and generated code, but not from the
default entrypoint.

Further boundary decisions:

1. Keep `TransportFrame` and `TransportStats` visible while `SessionTransport`
   stays public: implementers need those types. Consider moving all three to
   an advanced transport entrypoint instead of hiding only the data classes.
2. `NativeBuffer.fromOwned` and its `bindings` property serve the native
   transport and expose raw FFI ownership details. Narrow them only after the
   transport is moved behind an internal/advanced boundary; `fromBytes` is
   needed by Web and memory transports.

## Zig surface

| API | Current use | Recommendation |
| --- | --- | --- |
| `handlers.dispatch`, route hashing, and handler introspection | Shared native/Web exports and the handler dumper use these; typed calls and streams depend on them. | Keep the handler path. Helper functions used only by the dumper can be treated as tooling API. |
| `protocol.Text`, `Empty`, `RouteKind`; `codec.Reader`/`Writer`; `events.emit`/`id` | Handler and explicit-protocol examples use typed payloads, enum route kinds, and event emission. | Keep. The explicit protocol form remains used by callbacks and native ownership. |
| `Context`, `Runtime`, `frames`, `Buffer`, `api`, buffer metrics | Shared native/Web ABI exporters and application dispatchers require these. | Keep implementation modules. Consider narrower root exports after moving ABI exporters to direct internal imports. |
| `HandleTable`, `Atomic`, `allocator`, `logging` | Counter ownership and logging examples use these; native and Web roots provide platform-specific implementations. | Keep as practical cross-platform primitives. |
| `Bridge`, `Limits`, `Notifier`, mailbox `Kind`/`Packet` | Native-to-Dart request implementation and shared FFI exporter use them. The native-request example directly uses `Bridge`; `Notifier` supports native response wakes. | Keep the bridge feature, but expose it as an advanced/native module rather than making every consumer read it as part of the session API. |
| Native `dz_*` and Web `dz_web_*` exports | Generated binding adapter and Web transport call these. Native exports currently include both session and bridge functions for each asset. | Keep the ABI stable until bridge and session assets can be generated separately. |

### Zig root export cleanup

The unused `BufferPool`, `RuntimeOptions`, `Event`, `Mutex`, `Mailbox`, and
`CancellationToken` root aliases were removed. Their implementation files and
direct internal imports remain. `Mutex` is still needed for the Zig 0.15/0.16
adaptation.

`handlers.requestType`/`responseType`/`isStream`/`hasBorrowedRequest`,
`events.nameId`/`relayRoute`, and the dump modules are generator/runtime
plumbing rather than application features. Zig requires cross-module `pub`
for these calls; removing them from the root-facing modules would take a
separate internal module split. There is no reason to delete their behavior.

## Remaining design work

1. Migrate callbacks and native ownership from explicit `protocol.zig` plus
   dispatcher to a unified handler declaration only when the typed handler
   contract supports deferred callbacks and session-local state. Remove
   `ProtocolApi`/`protocol_dump*` only after those examples and downstream users
   have a replacement.
2. Decide separately whether to split bridge ABI generation from session ABI;
   it is a packaging change, not dead-code cleanup.
