import 'dart:convert';
import 'dart:ffi';

import 'package:dart_zig/dart_zig.dart';
import 'package:ffi/ffi.dart';

import 'ffi_app.g.dart' as native;

/// Starts the example's native request producer.
int submitExampleRequest(NativeBridge bridge) =>
    native.dz_demo_submit(bridge.nativeHandle.cast());

/// Cancels a request from the example's native producer.
bool cancelExampleRequest(NativeBridge bridge, int id) =>
    native.dz_demo_cancel(bridge.nativeHandle.cast(), id);

/// Verifies that the example's native side consumed a Dart reply.
void consumeExampleReply(
  NativeBridge bridge,
  int id,
  ReplyKind kind,
  String text,
) {
  final bytes = utf8.encode(text);
  final pointer = calloc<Uint8>(bytes.isEmpty ? 1 : bytes.length);
  try {
    pointer.asTypedList(bytes.length).setAll(0, bytes);
    if (!native.dz_demo_consume(
      bridge.nativeHandle.cast(),
      id,
      kind.index + 1,
      pointer,
      bytes.length,
    )) {
      throw StateError('Native reply did not match $kind / $text');
    }
  } finally {
    calloc.free(pointer);
  }
}
