import 'dart:convert';
import 'dart:typed_data';

/// Reply frame kinds shared with the native protocol.
enum ReplyKind {
  /// A nonterminal payload chunk.
  chunk,

  /// Successful completion after any preceding chunks.
  end,

  /// Terminal failure with a UTF-8 diagnostic payload.
  failure,

  /// Cooperative cancellation observed by native code.
  cancelled,
}

/// A native request with an independently owned Dart payload.
final class NativeRequest {
  /// Creates a request using a transport-provided reply writer.
  NativeRequest(this.id, this.bytes, this._send, {required this.isPending});

  /// Monotonic identifier scoped to one bridge.
  final int id;

  /// Request bytes copied from native memory.
  final Uint8List bytes;
  final Future<void> Function(int, ReplyKind, Uint8List) _send;

  /// Transport predicate used to observe native cancellation.
  final bool Function(int) isPending;
  bool _busy = false;
  bool _finished = false;

  /// Whether a terminal reply has been queued successfully.
  bool get isFinished => _finished;

  /// Whether native cancellation or bridge shutdown ended this unfinished request.
  ///
  /// Long-running handlers may check this between application work units.
  bool get isCancelled => !_finished && !isPending(id);

  /// Queues a body chunk, waiting for native capacity when necessary.
  ///
  /// Await each write before starting another write on this request.
  Future<void> add(Uint8List bytes) => _write(ReplyKind.chunk, bytes);

  /// Queues successful completion after all body chunks.
  Future<void> finish() => _write(ReplyKind.end, Uint8List(0));

  /// Queues a terminal error encoded as UTF-8.
  Future<void> fail(String message) =>
      _write(ReplyKind.failure, Uint8List.fromList(utf8.encode(message)));

  /// Queues cooperative cancellation for the native application to observe.
  Future<void> cancel() => _write(ReplyKind.cancelled, Uint8List(0));

  Future<void> _write(ReplyKind kind, Uint8List bytes) async {
    if (_finished) throw StateError('Request $id is already complete.');
    if (_busy) throw StateError('Await the previous write for request $id.');
    _busy = true;
    try {
      await _send(id, kind, bytes);
      if (kind != ReplyKind.chunk) _finished = true;
    } finally {
      _busy = false;
    }
  }
}
