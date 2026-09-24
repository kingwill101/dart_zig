# Native, Web, and in-memory consumers

[Documentation home](index.md) · [Runtime ownership](runtime.md)

## One Dart package

Import `package:dart_zig/dart_zig.dart` from CLI programs, packages, isolate entry
points, or Web applications. The package has no Flutter SDK dependency.
Conditional exports select FFI on the Dart VM and JavaScript interop on Web.
`NativeSession`, generated models, calls, signals, streams, callbacks, and cleanup
are shared. The historical name `NativeSession` also represents Wasm sessions.
The raw-pointer `NativeBridge` API is VM-only.

## Start on the Web

```dart
await initializeZig(wasmUri: Uri.parse('assets/dart_zig.wasm'));
final session = NativeSession();
final api = GeneratedApi(session);
try {
  print(await api.sum(const SumArgs(a: 20, b: 22)));
} finally {
  await session.close();
}
```

`initializeZig()` is a no-op on the VM. Web callers can supply `wasmBytes` instead
of a URL. Loading another module does not change existing sessions. A custom
`WebTransport` (from `package:dart_zig/web.dart`) can be supplied through `NativeSession(transport: ...)`.

Build and run the existing portable example:

```sh
sh tool/build_web.sh
python3 -m http.server 8080 --directory build/web
# Visit http://localhost:8080/ and inspect the console.
```

`web/main.dart` invokes the small portable examples in `example/run_all.dart`.
`web/verify.dart` runs the larger boundary validation harness.
`node tool/run_web.mjs` executes its compiled JavaScript against real WebAssembly
without a browser. This validates runtime behavior; it does not validate browser
security policy, rendering, or device behavior.

## Scheduling and ownership differences

| Concern | Dart VM | Web/Wasm |
| --- | --- | --- |
| Zig execution | Configurable native workers | Cooperative main-event-loop pump |
| Paused streams | Continuations release workers | Continuations await credits |
| Native callbacks | Dart port notification through `dart_api_dl` | Event-loop delivery through JS interop |
| Owned output | Reference-counted native buffer lease | Copy out of Wasm, then shared Dart leases |
| Long work | Check cancellation in native loops | Split work into short continuations to avoid blocking the host |
| Cleanup | Stop and join workers/producers | Stop pump and release runtime allocations |
| 64-bit `int` fields | Signed 64-bit representation | Exact integers only, within ±(2^53−1); unsigned values nonnegative |
| 128-bit fields | `BigInt`, exact | `BigInt`, exact |

Web handlers cannot synchronously wait for output capacity. They must fit their
emissions within the configured queue budget per invocation, or use continuations.
An overflowing call reports a failure after queued output drains. One-way handler
failures appear on `signalErrors` when diagnostic capacity is available. Web does
not yet move Wasm execution to a dedicated worker, and `workers` does not add Web
threads. Browser tab suspension can delay callbacks and deadlines.

Treat all shared views as read-only. Web Wasm memory growth cannot detach buffers
already returned to Dart because the boundary copy has completed first. Disposing
a `NativeBuffer` releases its lease; other retained leases remain usable.

## In-memory applications

`MemoryTransport(schemaFingerprint: ..., handler: ...)` implements the same
session boundary with bounded queues, cancellation, credited streams, callbacks,
and caller-supplied behavior. It is useful for fakes and previews. It does not
execute Zig and does not implement application-specific synchronous functions.
The existing toolkit executable contains a generated-facade example using it.

## Isolates and native assets

Run `dart run bin/isolates.dart` for independent sessions in two Dart isolates.
Each isolate owns its session and callback registrations. Send ordinary Dart
messages between isolates; do not pass runtime pointers or object handles.

Run `python3 tool/check_consumer.py` to scaffold a disposable package, generate its
FFI with the toolchain CLI, compile its separate native asset, and use that asset
through the shared package's session and generated facade. It checks synchronous
and asynchronous calls, independent allocation counters, and releasing a retained
buffer after session shutdown. All temporary files stay under `build/`.

Cross-compilation proves a target builds, not that it runs on the target device.
See the [acceptance ledger](gap-implementation.md) for current evidence.
