import 'dart:typed_data';

import 'native_buffer.dart';

/// One owned output frame; consumers must dispose [buffer].
final class TransportFrame {
  const TransportFrame(this.id, this.route, this.kind, this.code, this.buffer);
  final int id, route, kind, code;
  final NativeBuffer buffer;
}

/// Counts and occupancy independent of a native ABI.
final class TransportStats {
  const TransportStats({
    this.submitted = 0,
    this.delivered = 0,
    this.wakes = 0,
    this.copiedBytes = 0,
    this.logDrops = 0,
    this.inputMessages = 0,
    this.outputMessages = 0,
    this.inputBytes = 0,
    this.outputBytes = 0,
  });
  final int submitted, delivered, wakes, copiedBytes, logDrops;
  final int inputMessages, outputMessages, inputBytes, outputBytes;
}

/// Portable runtime boundary implemented by native, Web, and in-memory backends.
///
/// Methods are synchronous admission operations. Status 1 means capacity is full;
/// [onWake] must eventually notify when retry or output processing can progress.
abstract interface class SessionTransport {
  int get protocolVersion;
  int get liveBuffers;
  int get liveBufferBytes;
  void Function()? get onWake;
  set onWake(void Function()? callback);
  ({int status, int id}) submit(
    int route,
    int kind,
    Uint8List bytes,
    int timeoutNs,
  );
  int sendSignal(int route, Uint8List bytes);
  int callbackReply(int id, int callbackId, int code, Uint8List bytes);
  void cancel(int id);
  void grant(int id);
  List<TransportFrame> poll(int capacity);
  TransportStats get stats;
  bool get stopped;
  bool get readyToDestroy;
  void stop();
  void destroy();
}
