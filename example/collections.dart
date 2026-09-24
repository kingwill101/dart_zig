/// Round-trips rich values with generated, checked little-endian codecs.
library;

import 'dart:typed_data';

import 'package:dart_zig/dart_zig.dart';

Future<void> main() async {
  await initializeZig();
  final session = NativeSession();
  try {
    final api = GeneratedApi(session);
    final value = RichValues(
      scores: {'alpha': 42},
      labels: {'one', 'two'},
      coordinates: [1.5, 2.0, -3.0],
      pair: ('signed 128-bit', -(BigInt.one << 100)),
      huge: (BigInt.one << 128) - BigInt.one,
      small: -128,
      medium: 65535,
    );
    final result = await api.roundTripRich(value);
    print('Map: ${result.scores}; set: ${result.labels}');
    print('Fixed array: ${result.coordinates}; tuple: ${result.pair}');
    print('Exact unsigned 128-bit value: ${result.huge}');
    final record = await api.roundTripRecord(
      Record(
        label: 'Structured values',
        tags: ['lists', 'enums', 'optional'],
        score: null,
        importance: Importance.high,
        data: Uint8List.fromList([1, 2]),
        flags: [true, false],
      ),
    );
    print(
      'Model: ${record.label}, ${record.importance}, optional score ${record.score}',
    );
    final variant = await api.roundTripValue(const ValueText('Tagged union'));
    print(switch (variant) {
      ValueText(:final value) => value,
      _ => 'Another variant',
    });
  } finally {
    await session.close();
  }
}
