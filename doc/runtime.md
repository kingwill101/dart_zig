# Runtime and ownership

[Back to the package guide](../README.md)

## Native architecture

```text
Dart calls / callbacks
         │ generated FFI
         ▼
bounded input queue → native worker pool → application dispatch
                                                │
                                                ▼
Dart futures / streams ← batch descriptors ← bounded output queue
         ▲
         └── coalesced dart_api_dl wake notifications
```

`zig/src/root.zig` exports reusable runtime primitives. `application.zig` and
`generated/models.zig` are separate application modules supplied by `build.zig`.
The application provides `Application.create`, `Application.destroy`, and
`dispatch`. `exports.zig` exposes the FFI entry points around those modules.

A dispatch handler receives a `Context` and can:

- `complete(bytes)` or `fail(code, message)` to settle a call.
- `item(bytes)` and `end()` to produce a stream.
- `signal(route, bytes)` to emit an event.
- `callback(callbackId, bytes)` to request Dart work and return immediately.
  A later `callback_result` frame resumes application dispatch.
- `check()` to cooperate with cancellation/shutdown during long work.

A `Context` and its input bytes are borrowed for the dispatch invocation. Copy
any data needed after returning; use callback frames to resume work later.

Unsolicited events use `Runtime.trySignal`. Native logging uses
`logging.write`, which is bounded and best-effort; a full queue drops the log
record and increments the native drop counter.

`HandleTable(T)` protects resource lifetime. A lease does not serialize access to
mutable application state; the demo counter uses atomic operations for that.

## dart_api_dl usage

1. Dart supplies `NativeApi.initializeApiDLData` through generated `dz_initialize`.
2. `zig/src/api.zig` imports `dart_api_dl.h` and calls `Dart_InitializeApiDL`.
3. Native threads use `Dart_PostInteger_DL` to wake the Dart `ReceivePort`.
4. `zig/build.zig` compiles the vendored `dart_api_dl.c` into the library.

Payloads remain in bounded native queues until Dart polls a batch. Wake messages
contain no pointers. Acknowledgment and queue notification share synchronization,
so the runtime can coalesce wakes without relying on periodic Dart polling.

## Ownership and performance

- Native queue slots and Dart batch descriptors are allocated once per session.
- Dart reuses an input scratch allocation; native payload buffers use a bounded
  reuse pool. Native worker waits use OS condition variables rather than spinning.
- Regular results are copied into independent Dart bytes before user callbacks.
- `session.callBuffer(...).result` returns a `NativeBuffer` without copying the
  result payload into Dart memory. Its `view` is borrowed; use `copy()` for an
  independent Dart allocation. Dispose buffers explicitly; a native finalizer is
  a fallback. Leased buffers remain valid after their session closes.
- The owned-result path is **not end-to-end zero-copy**: input submission and
  native response construction still copy. Counters report native-side copies.
- `maxPending` bounds Dart calls; `maxPendingBytes` bounds payload snapshots
  awaiting native admission. Both fail admission explicitly when exceeded.
- Queue limits count queued payloads. In-flight operations, leased result buffers,
  cached storage, and Dart model allocations contribute additional memory.
- Each native stream has one outstanding production credit. Continuation-based
  producers release their worker while paused. `Context.deferStream` owns producer
  state and resumes it once per credit. Legacy handlers that loop in `item` can
  still block a worker; the bundled stream uses continuations.

## Cancellation and shutdown

`NativeCall.cancel()` and stream subscription cancellation invalidate the native
request and wake blocked producers. `timeout` covers admission and execution.
Application CPU loops must call `Context.check`; arbitrary native work cannot be
forcibly interrupted safely. Dart callbacks already executing are allowed to
finish; results for closed/cancelled requests are discarded.

`await session.close()` stops admission, rejects pending Dart calls, wakes native
workers, and waits asynchronously for them to exit before freeing session storage.
Native objects remaining in the session are destroyed after workers finish.
Repeated close calls share one future. Always close sessions explicitly.

If an application starts additional native producers, supply `stopExternal` to
stop and join them during close, before runtime storage is freed. If that hook
fails, storage is retained to avoid freeing memory still used by those producers.

Fresh sessions can be created through `RestartableResource`. See [cleanup](lifecycle.md)
and [Web/platform behavior](platforms.md). The core is Dart-only; hosts own lifecycle integration.


## Failure categories

| Code | Meaning |
| --- | --- |
| `protocol`, `schema` | Native asset and Dart facade are incompatible. |
| `allocation` | Native session allocation failed. |
| `busy` | Dart pending-call count or payload budget is exhausted. |
| `too_large` | A payload exceeds the session limit. |
| `cancelled`, `deadline`, `closed` | Explicit cancellation, timeout, or shutdown. |
| `submit_N`, `callback_N` | A native transport status prevented delivery. |
| `native_N` | The application or runtime returned a failure frame. |
| `signal_overflow` | A paused signal subscriber exceeded its backlog budget. |
| `disposed` | A native object facade is already disposed or its session closed. |
| `sync_error` | A synchronous native operation returned nonzero status. |

Catch `NativeException` for transport/application failures. Invalid Dart arguments
can throw `ArgumentError`; malformed codec input throws `FormatException`.
Treat message text as diagnostic detail, not a stable error identifier.
A failed call does not imply that application side effects were rolled back.
