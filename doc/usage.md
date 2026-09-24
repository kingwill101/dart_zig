# Using the Dart API

[Back to the package guide](../README.md)

Import `package:dart_zig/dart_zig.dart`. The complete runnable example is
[bin/toolkit.dart](../bin/toolkit.dart); the region names below identify the
same snippets embedded in Dart API documentation.

## Start and close a session

The `session-setup` region creates a `NativeSession` and `GeneratedApi`.
The session starts native workers and initializes `dart_api_dl`; the facade
checks that the application schema matches the native library.

Use `try`/`finally` and always await `session.close()`. Pending calls fail when
shutdown starts. For graceful application shutdown, await the work you want to
preserve before closing. `isClosed` becomes true when shutdown starts, before
native cleanup necessarily finishes. Do not share handles or sessions across
Dart isolates; create an independently owned session for each isolate.

## Calls and signals

`api.sum` performs a typed asynchronous call on a native worker. `api.sumSync`
is a separate short synchronous operation that runs on the calling Dart thread.
Keep blocking or expensive operations on the asynchronous path.

The `typed-signals` region subscribes to `api.messages.first` before calling
`api.publish`. Signals are broadcast and have no replay: subscribing afterward
can miss the event. A paused subscriber has a bounded backlog; overflow fails
that subscriber with `signal_overflow`. Signal payloads are shared between
subscribers and should be treated as read-only.

## Streams

The `typed-stream` region collects `api.squares` with `toList()`. Use `await for`
for incremental consumption or a subscription when pause/resume is needed.
Listening starts the native call. Pause withholds production credit; an item
already in flight can still reach Dart and be held until resume. Cancelling the
subscription invalidates the native task.

The timeout covers the whole stream, including paused time. The bundled Zig
producer uses continuations, so pausing releases its worker for unrelated calls.
The existing executable exercises a paused stream alongside a call on one worker.
See [signals and cleanup](lifecycle.md) for typed bidirectional endpoints and state.

## Native objects

The `native-object` region opens, updates, and disposes a `NativeCounter`.
This is an application example built on the reusable Zig handle table. Handles
include a generation so a stale handle cannot resolve to a newly allocated
object in the same slot. Handles are valid only within their owning session.

Dispose objects explicitly when finished. The session releases remaining objects
at shutdown. Scoped native leases protect lifetime during a call; applications
must still synchronize mutable state. The counter uses atomic updates.

## Async Dart callbacks

The `typed-callback` region calls `api.transformWith`. This scoped helper registers
its callback, invokes the operation, and unregisters on success or failure.
The callback can await another native operation: native dispatch returns after
requesting the callback and resumes when its result arrives.

For persistent registrations, use `api.registerIntTransform` and later
`session.unregisterCallback(id)`. Unregistering prevents future invocations;
it cannot stop a Dart callback already executing. Cancellation or shutdown
causes late callback results to be discarded.

## Bytes and ownership

Ordinary calls return independently owned Dart bytes. `session.callBuffer`
returns a `NativeBuffer`, avoiding the final native-to-Dart result copy.
The `owned-buffer` region retains such a result; later in the same demo it is
read after session shutdown and explicitly disposed.

`buffer.view` borrows native storage. Keep `buffer` reachable and undisposed for
as long as the view is used. `buffer.copy()` creates independent Dart bytes.
Never access a borrowed view after disposal. Native finalizers are a fallback;
explicit `dispose()` gives predictable release timing.

The demo uses raw route 8 for this buffer operation. Its schema-generated
`api.echo` uses length-prefixed byte encoding, so the typed and raw payload
representations differ. Use the corresponding facade/codec consistently.

## Cancellation, deadlines, and errors

A raw `session.call` returns a `NativeCall` with a `result` future and `cancel`
action. Calling `cancel()` rejects pending results with `cancelled`; the native
handler must cooperate to stop work. Supply a positive `timeout` to bound queue
admission and execution. Typed calls forward this timeout to the session.

Await or otherwise handle result errors, including after cancellation. Invalid
arguments can throw synchronously on raw APIs; typed async facades report their
failures through futures. Stream admission errors are delivered to the stream.
See [failure categories](runtime.md#failure-categories) for error codes.

## Lower-level native requests

[bin/main.dart](../bin/main.dart) demonstrates `NativeBridge`: native code submits
requests that Dart consumes with `nextRequest()`. Reply with sequential awaited
`add()` writes, then `finish()`, `fail()`, or `cancel()`.

Only one `nextRequest()` read may be pending. Reply completion means the frame was
queued, not that native code consumed it. If native producers outlive synchronous
FFI calls, supply `stopNative` to stop/join them before bridge storage is freed.
