import 'dart:typed_data';

import 'package:native_ownership_example/native_ownership_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession();
  NativeBuffer? buffer;
  try {
    final counter = await NativeCounter.open(session, 10);
    try {
      print('Counter: ${await counter.add(5)}');
    } finally {
      await counter.close();
    }
    buffer = await session
        .callBuffer(8, Uint8List.fromList([10, 20, 30]))
        .result;
  } finally {
    await session.close();
  }
  try {
    final slice = buffer.slice(1);
    try {
      print('Retained slice: ${slice.view}');
    } finally {
      slice.dispose();
    }
  } finally {
    buffer.dispose();
  }
}
