# Small feature examples

Run these from the repository root after `dart pub get` with Zig 0.15.2 or 0.16.0
on PATH. Each file has its own `main` and can run independently:

```sh
dart run example/calls.dart
dart run example/streams.dart
dart run example/run_all.dart
```

| Example | Demonstrates |
| --- | --- |
| [calls.dart](calls.dart) | Generated synchronous and asynchronous calls |
| [signals.dart](signals.dart) | Typed event broadcast and two subscribers |
| [state_and_attachments.dart](state_and_attachments.dart) | Bidirectional one-way endpoint, latest state, replay, independent binary leases |
| [streams.dart](streams.dart) | Credited streams, pause/resume, cancellation, a call while one worker's stream is paused |
| [callbacks.dart](callbacks.dart) | Async Zig → Dart callback, nested Dart → Zig call, scoped registration |
| [native_objects.dart](native_objects.dart) | Session-owned object handles and explicit disposal |
| [owned_buffers.dart](owned_buffers.dart) | Retention after session close, slices, copies, release |
| [collections.dart](collections.dart) | Maps, sets, arrays, tuples, exact BigInt128, models, enums, optionals, lists, bytes, unions |
| [errors_and_cancellation.dart](errors_and_cancellation.dart) | Cancellation, deadline, malformed input, one-way errors |
| [cleanup_and_restart.dart](cleanup_and_restart.dart) | Parent cancellation, LIFO cleanup, serialized restart |
| [diagnostics.dart](diagnostics.dart) | Native logging, host sink, call traces, queue/transfer metrics |
| [in_memory.dart](in_memory.dart) | Generated facade with a bounded application-supplied transport |
| [overflow_policies.dart](overflow_policies.dart) | Bounded latest-value coalescing while paused |
| [isolates.dart](isolates.dart) | Independent native sessions in Dart isolates (VM only) |
| [native_requests.dart](native_requests.dart) | Low-level `dart_api_dl` request/reply, streaming replies, cancellation (VM only) |
| [backend_injection.dart](backend_injection.dart) | CLI-generated native asset adapter (VM only) |

`run_all.dart` runs the portable examples. For Web:

```sh
sh tool/build_web.sh
python3 -m http.server 8080 --directory build/web
```

Open `http://localhost:8080/`; results appear in the console. For runtime checks
without a browser, run `node tool/run_web.mjs` after building. VM-only examples
run separately. `python3 tool/check_consumer.py` demonstrates a separately compiled
native library using the shared Dart runtime and generated adapter.

## Authoring and validation

[authoring/messages.zig](../authoring/messages.zig) demonstrates the optional
comptime model frontend. The [generation guide](../doc/generation.md) covers
schema/config/watch/scaffold commands. [bin/toolkit.dart](../bin/toolkit.dart)
contains the broader executable assertions; these examples focus on one concept
at a time and print their results.

All examples use generated Dart bindings. The package stays Dart-first with no
Flutter dependency. See [backend differences](../doc/platforms.md) for ownership,
Web integer precision, and scheduling details.
