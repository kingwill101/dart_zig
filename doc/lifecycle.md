# Signals, ownership, and cleanup

[Documentation home](index.md) · [Existing executable examples](../bin/toolkit.dart)

## Choose a call, signal, or stream

Use generated calls when the sender needs a correlated result or processing
acknowledgment. Use `SignalEndpoint<T>.send` for one-way input: its future completes
on **queue admission**, not application processing. Waiting signals share the
session's pending count and byte budgets. Use streams for a sequence whose
producer must follow the receiver's pace.

`GeneratedApi.updates` demonstrates a bidirectional endpoint. Its native dispatcher
receives one input at a time; multiple native workers may execute different
messages concurrently, so worker completion order is not guaranteed. Generated
`emitUpdates` also permits unsolicited native output. Native emitters report
`Full`; applications choose retry/drop behavior. They must stop external producers
before the session is destroyed.

Dart listeners receive broadcasts. `SignalBus` supplies error, drop-newest,
drop-oldest, and coalesce-latest overflow policies, bounded by messages and bytes.
The session's raw broadcast boundary also has a 64-message/1-MiB per-subscriber
budget. Application endpoint limits do not increase that upstream limit.

## Latest value and binary attachments

A state endpoint retains one latest value and replays it when a new subscriber
registers. Registration and snapshot enqueue happen on the same Dart event loop,
so an update cannot slip between those steps. This intentionally provides replay;
Rinf's separate latest-value getter does not imply identical replay behavior.
Latest state belongs to a session and is discarded on close/restart.

Each `SignalPack<T>` contains typed metadata and an owned binary attachment.
Dispose **every received pack**, including values obtained through `latest`.
`retain()` acquires another independent lease. The `state-attachments` region in
`bin/toolkit.dart` demonstrates sending, receiving, snapshots, and replay.

On the VM, attachment slices retain the received native allocation without copying
its binary payload into Dart. Broadcast subscribers have separate leases over the
same storage. Model byte fields may also borrow that allocation: keep the pack
alive while using those fields. On Web the whole frame first copies out of Wasm;
subscribers then share the Dart allocation. Sending input still copies on both
backends. This is not an end-to-end zero-copy protocol.

`session.ownedSignals` is an advanced raw stream. Dispose every event, including
ones you ignore. A plain `where` filter would discard ownership without disposal;
prefer generated endpoints, which handle routing and disposal together.

## Host-controlled cleanup

`CancellationScope` links related Dart work through an optional parent, a
cancelled future, synchronous observers, and `check()`. Cancellation is cooperative.
It cannot interrupt arbitrary CPU work.

`CleanupScope` registers synchronous or asynchronous disposers. Closing cancels
its scope and runs disposers in reverse order, attempts every disposer, and
reports aggregated failures. Repeated closes share the same future. Register a
runtime before its producers so the producers stop first.

`NativeSession.cleanup` closes endpoint registrations and host resources before
runtime storage is freed. `stopExternal` stops application-owned native producers.
If either cleanup path fails, close reports the failures and retains native
storage, because external users may still hold pointers.

`RestartableResource<T>` serializes explicit restart and close operations. It
finishes disposing the old resource before creating its replacement; failed
disposal prevents replacement. Each new session has separate pending calls,
callbacks, state caches, and native handles. Late callbacks from a closed session
cannot deliver into its replacement.

These primitives have no widget or Flutter lifecycle dependencies. CLI programs,
servers, packages, and Web hosts decide when to invoke them. The `cleanup` region
in the existing executable demonstrates LIFO cleanup and session replacement.

## Diagnostics

Pass `onDiagnostic` to observe payload-free started/admitted/completed/failed,
backpressure, and signal events. `session.stats` reports queue occupancy and
transport counters. `forwardNativeLogs(session, sink)` connects structured Zig
logs to the host logger and registers its own cleanup.

`session.signalErrors` reports one-way handler failures; typed endpoints route
those errors to `endpoint.errors`. Delivery is best effort when diagnostic output
is full. Dropped diagnostic frames contribute to the runtime's drop counter.
