# Dart and Zig, working together.

A reusable toolkit for typed communication, native resource ownership, and
application lifecycles. Start with a small native operation, then grow into
signals, streams, callbacks, and stateful objects.

> **Prototype / in development**
> This is a standalone Dart-first toolkit. Native and Web share one package;
> see the [validation record](validation.md) for executed and build-only checks.

## Your first steps

1. [Run the existing example](../README.md#run). Call real Zig code through the
   generated Dart API and native build hook.
2. [Explore the Dart API](usage.md). Follow calls, events, streams, and ownership
   using the same runnable example.
3. [Define an operation](generation.md#adding-an-operation). Generate matching
   models and implement the native handler.

## Several ways to communicate

| You need to… | Start with… |
| --- | --- |
| Get a result from native work | A generated asynchronous call |
| Observe native events | Typed signal subscriptions |
| Consume incremental results | A native stream with production credits |
| Let Zig request Dart work | An asynchronous callback |
| Keep state in native memory | A generation-checked native object handle |
| Avoid the final result payload copy | An explicitly owned native buffer |

The runtime supplies bounded queues, cancellation, deadlines, batch delivery,
and `dart_api_dl` wake notifications. Application code supplies its own operations.
Read [runtime and ownership](runtime.md) before integrating long-running work or
retaining native memory.

## Ready today, growing tomorrow

[Implementation status](PLAN.md) records completed work and its verification
scope. [Performance notes](../benchmark/README.md) report local measurements
without promising production throughput.

We are studying endpoint ergonomics, latest-value state, binary attachments,
and Flutter lifecycle integration. The [Rinf research catalog](rinf-catalog.md)
records these proposals; they are not yet available APIs.

## A living guide

Add a focused tutorial when a workflow is ready, a reference page when an API
stabilizes, and a design note while decisions are still being explored. Keep
examples connected to executable code and mark unverified behavior clearly.

[Contribute a page](documentation.md#add-a-page), or follow the API reference in
the navigation for individual Dart classes and methods.
