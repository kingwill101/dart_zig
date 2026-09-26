/// Retains byte storage beyond its session lifetime and releases it explicitly.
library;

import 'dart:typed_data';

import 'package:runtime_features_example/runtime_features_example.dart';

Future<void> main() async {
  await initializeZig();
  final session = createSession();
  NativeBuffer? buffer;
  try {
    // Route 8 is the sample application's raw echo operation.
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
    print('Independent copy: ${buffer.copy()}');
  } finally {
    buffer.dispose();
  }
}
