> Recorded results below predate the portable-transport refactor. Re-run the benchmark before using them to describe current performance.

# Local benchmark results

Measured on Linux x64, Intel Core i7-10510U (8 logical CPUs), Dart 3.13.4 JIT,
native ReleaseSafe libraries. These are observations from one shared workstation,
not a controlled comparison of compiler versions or competing libraries.

## Workload

Each compiler run uses batch sizes `1, 32, 32, 1`, with two native workers. Each
round warms the call/transfer paths before measuring:

- 100,000 synchronous sums.
- 500 serial async sums, reporting p50/p95/p99 latency.
- 4,096 async sums with concurrency 64.
- 100 sequential echoes per payload size (64 B, 64 KiB, 1 MiB) and result mode.

Build startup is excluded. Checks verify returned values and zero remaining
native buffers after session shutdown. Timing includes Dart dispatch, codecs,
transport, native execution, and result handling appropriate to each case.

## Observed ranges

Each range spans the two rounds for that compiler and batch size.

| Zig | Batch | Async calls/s (64 concurrent) | Serial p50 (µs) | Serial p99 (µs) | 1 MiB copied result (MiB/s) | 1 MiB owned result (MiB/s) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0.15.2 | 1 | 6,585–14,451 | 28–209 | 5,988–7,410 | 83–130 | 122–165 |
| 0.15.2 | 32 | 24,141–26,138 | 52–54 | 7,403–10,971 | 96–107 | 128–147 |
| 0.16.0 | 1 | 6,901–36,254 | 31–166 | 1,350–5,916 | 118–138 | 176–182 |
| 0.16.0 | 32 | 33,911–65,220 | 36–47 | 2,283–5,273 | 120–134 | 165–210 |

Raw measurements, including sync calls, smaller payloads, p95, and native
copy/wake counters: [Zig 0.15.2](results-zig-0.15.2.json),
[Zig 0.16.0](results-zig-0.16.0.json).

## Interpretation and limits

Batching generally improved concurrent call throughput, with overlapping ranges
in the 0.16.0 run. Serial latency and
tail latency varied substantially, so these figures are not performance promises.
The runs were not isolated from host scheduling, CPU frequency changes, or JIT
effects. Payload throughput counts one payload per completed echo, not both
directions of traffic.

Owned results avoid the final native-to-Dart payload copy; Dart input snapshots,
submission, and native response construction still copy. Explicit disposal is
included in the owned measurement. This is not end-to-end zero-copy.

No FRB/Rinf implementation was benchmarked. AOT, Flutter UI responsiveness,
other operating systems, sustained saturation, and production workloads require
separate measurements.

## Reproduce

```sh
# Put the desired Zig version on PATH, then force/verify its native build.
./tool/verify.sh
dart run benchmark/throughput.dart > benchmark/results-local.json
```

`tool/verify.sh` invalidates the package-local hook result because changing
compiler PATH alone is not tracked as a native build dependency.
