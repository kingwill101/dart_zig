# Dart and Zig, working together.

A reusable toolkit for typed communication, native resource ownership, and
application lifecycles. Start with a small native operation, then grow into
signals, streams, callbacks, and stateful objects.

> **Prototype / in development**
> This is a standalone Dart-first toolkit. Native and Web share one package;
> see the [validation record](validation.md) for executed and build-only checks.

## Your first steps

1. [Set up your package](../README.md#quick-start). Call Zig code through
   generated FFI bindings and a native build hook.
2. [Explore the Dart API](usage.md). Follow calls, events, streams, and ownership
   using the same runnable example.
3. [Explore project setup](generation.md#project-setup-and-generation). Define
   application models, codecs, and native handlers.

## Several ways to communicate

| You need to… | Start with… |
| --- | --- |
| Get a result from native work | An asynchronous session call |
| Observe native events | Typed signal subscriptions |
| Consume incremental results | A native stream with production credits |
| Let Zig request Dart work | An asynchronous callback |
| Keep state in native memory | A generation-checked native object handle |
| Avoid the final result payload copy | An explicitly owned native buffer |

Start with the [minimal example](../example/minimal_example/README.md) for one
generated FFI call, then use the [runtime feature example](../example/runtime_features_example/README.md)
for sessions and events.

The runtime supplies bounded queues, cancellation, deadlines, batch delivery,
and `dart_api_dl` wake notifications. Application code supplies its own operations.
Read [runtime and ownership](runtime.md) before integrating long-running work or
retaining native memory.

## Ready today, growing tomorrow

[Implementation status](PLAN.md) records completed work and its verification
scope. [Performance notes](../example/runtime_features_example/benchmark/README.md) report local measurements
without promising production throughput.

The [Rinf research catalog](rinf-catalog.md) records the feature inventory and
remaining proposals. Flutter lifecycle integration stays outside the core package.

## A living guide

Add a focused tutorial when a workflow is ready, a reference page when an API
stabilizes, and a design note while decisions are still being explored. Keep
examples connected to executable code and mark unverified behavior clearly.

[Contribute a page](documentation.md#writing-and-previewing-documentation), or follow the API reference in
the navigation for individual Dart classes and methods.
