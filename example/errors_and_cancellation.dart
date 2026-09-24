/// Handles cancellation, deadlines, malformed input, and one-way failures.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dart_zig/dart_zig.dart';

Future<void> main() async {
  await initializeZig();
  final session = NativeSession();
  try {
    final call = session.call(8, Uint8List(8));
    call.cancel();
    try {
      await call.result;
    } on NativeException catch (error) {
      print(error.code);
    }
    try {
      await session.call(1, Uint8List(3)).result;
    } on NativeException catch (error) {
      print('Invalid payload: ${error.message}');
    }
    final lateReply = Completer<int>();
    try {
      await GeneratedApi(session).transformWith(
        value: 1,
        callback: (_) => lateReply.future,
        timeout: const Duration(milliseconds: 20),
      );
    } on NativeException catch (error) {
      print('Deadline: ${error.code}');
    } finally {
      lateReply.complete(1);
    }
    final failure = session.signalErrors.first;
    await session.sendSignal(999, Uint8List(0));
    print('One-way failure: ${(await failure).message}');
  } finally {
    await session.close();
  }
}
