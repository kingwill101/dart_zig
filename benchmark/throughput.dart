import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_zig/dart_zig.dart';

Future<void> main() async {
  final zig = await Process.run('zig', ['version']);
  final results = <Map<String, Object>>[];
  var round = 0;
  for (final batch in [1, 32, 32, 1]) {
    final resultStart = results.length;
    round++;
    final session = NativeSession(batchSize: batch, workers: 2);
    final api = GeneratedApi(session);
    try {
      for (var i = 0; i < 200; i++) {
        await api.sum(const SumArgs(a: 20, b: 22));
      }
      // Warm every measured path before collecting timings.
      for (var i = 0; i < 10000; i++) {
        api.sumSync(20, 22);
      }
      for (var i = 0; i < 4; i++) {
        await Future.wait(
          List.generate(64, (_) => api.sum(const SumArgs(a: 20, b: 22))),
        );
      }
      final warmBytes = Uint8List(1048576);
      for (var i = 0; i < 10; i++) {
        await session.call(8, warmBytes).result;
        (await session.callBuffer(8, warmBytes).result).dispose();
      }
      var watch = Stopwatch()..start();
      const syncCount = 100000;
      for (var i = 0; i < syncCount; i++) {
        if (api.sumSync(20, 22) != 42) {
          throw StateError('Incorrect sync result');
        }
      }
      watch.stop();
      results.add({
        'case': 'sync_sum',
        'batch': batch,
        'operations': syncCount,
        'elapsed_us': watch.elapsedMicroseconds,
      });
      final latency = <int>[];
      for (var i = 0; i < 500; i++) {
        watch = Stopwatch()..start();
        final result = await api.sum(const SumArgs(a: 20, b: 22));
        watch.stop();
        if (result != 42) throw StateError('Incorrect async result');
        latency.add(watch.elapsedMicroseconds);
      }
      latency.sort();
      results.add({
        'case': 'async_sum_latency',
        'batch': batch,
        'p50_us': latency[250],
        'p95_us': latency[475],
        'p99_us': latency[495],
      });
      watch = Stopwatch()..start();
      const count = 4096;
      for (var i = 0; i < count; i += 64) {
        final values = await Future.wait(
          List.generate(64, (_) => api.sum(const SumArgs(a: 20, b: 22))),
        );
        if (values.any((value) => value != 42)) {
          throw StateError('Incorrect batch result');
        }
      }
      watch.stop();
      results.add({
        'case': 'async_sum_concurrency_64',
        'batch': batch,
        'operations': count,
        'elapsed_us': watch.elapsedMicroseconds,
        'operations_per_second': count * 1000000 / watch.elapsedMicroseconds,
      });
      for (final size in [64, 65536, 1048576]) {
        final bytes = Uint8List(size)..fillRange(0, size, 42);
        for (final owned in [false, true]) {
          const iterations = 100;
          watch = Stopwatch()..start();
          for (var i = 0; i < iterations; i++) {
            if (owned) {
              final buffer = await session.callBuffer(8, bytes).result;
              if (buffer.length != size || buffer.view[size - 1] != 42) {
                throw StateError('Incorrect owned bytes');
              }
              buffer.dispose();
            } else {
              final result = await session.call(8, bytes).result;
              if (result.length != size || result[size - 1] != 42) {
                throw StateError('Incorrect copied bytes');
              }
            }
          }
          watch.stop();
          results.add({
            'case': owned ? 'echo_owned_result' : 'echo_copied_result',
            'batch': batch,
            'payload_bytes': size,
            'operations': iterations,
            'elapsed_us': watch.elapsedMicroseconds,
            'payload_mib_per_second':
                size *
                iterations *
                1000000 /
                watch.elapsedMicroseconds /
                1048576,
          });
        }
      }
      final stats = session.stats;
      results.add({
        'case': 'session_counters',
        'batch': batch,
        'submitted': stats.submitted,
        'delivered': stats.delivered,
        'wakes': stats.wakes,
        'native_copied_bytes': stats.copiedBytes,
      });
      for (var i = resultStart; i < results.length; i++) {
        results[i]["round"] = round;
      }
    } finally {
      await session.close();
    }
    if (NativeSession.liveBuffers != 0) {
      throw StateError('Native buffers remain after benchmark');
    }
  }
  print(
    const JsonEncoder.withIndent('  ').convert({
      'os': Platform.operatingSystem,
      'dart': Platform.version,
      'zig': zig.stdout.toString().trim(),
      'mode': 'dart run JIT, native ReleaseSafe build hook',
      'results': results,
    }),
  );
}
