import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'runtime_abi.g.dart' as abi;
import 'request.dart';
import 'runtime_bindings.dart';

/// Owns a bounded native request/reply bridge and its Dart notification port.
///
/// Call [close] explicitly. Native code may borrow [nativeHandle] until the
/// shutdown callback completes; it must never destroy the handle itself.
final class NativeBridge {
  /// Creates queues limited independently by [maxMessages] and [maxBytes].
  ///
  /// [maxRequests] bounds requests whose terminal reply has not been consumed.
  /// [stopNative] must join or detach all native users during [close], after
  /// admission stops and before native memory is freed. Omit it only when no
  /// native users can outlive a synchronous call (as in the bundled demo).
  NativeBridge({
    int maxMessages = 64,
    this.maxBytes = 1024 * 1024,
    int maxRequests = 64,
    this.stopNative,
    required this.bindings,
  }) {
    if (maxMessages <= 0 || maxBytes <= 0 || maxRequests <= 0) {
      throw ArgumentError('Queue and request limits must be positive.');
    }
    if (!bindings.dz_initialize(NativeApi.initializeApiDLData)) {
      throw StateError('Unable to initialize the Dart dynamic API.');
    }
    _port = ReceivePort('dart_zig');
    _handle = bindings.dz_create(
      _port.sendPort.nativePort,
      maxMessages,
      maxBytes,
      maxRequests,
    );
    if (_handle == nullptr) {
      _port.close();
      throw StateError('Unable to allocate native bridge.');
    }
    _port.listen((_) {
      if (_closing) return;
      bindings.dz_acknowledge(_handle);
      _signal();
    });
  }

  /// Maximum queued payload bytes in each direction.
  final int maxBytes;

  /// Adapter for the same native asset that owns this bridge.
  final RuntimeBindings bindings;

  /// Stops and joins native users before the bridge storage is freed.
  final Future<void> Function()? stopNative;
  late final ReceivePort _port;
  late final Pointer<abi.dz_Bridge> _handle;
  Completer<void> _changed = Completer<void>();
  bool _closing = false;
  bool _reading = false;
  Future<void>? _closeFuture;

  /// Borrowed native bridge pointer for the consuming application's FFI calls.
  ///
  /// Throws [StateError] after shutdown starts. Never cache it past [close].
  Pointer<Void> get nativeHandle {
    _ensureOpen();
    return _handle.cast();
  }

  void _ensureOpen() {
    if (_closing) throw StateError('Native bridge is closed.');
  }

  void _signal() {
    final previous = _changed;
    _changed = Completer<void>();
    previous.complete();
  }

  /// Waits for one native request, without buffering requests in a Dart stream.
  ///
  /// Only one read may be pending. Returns null when [close] starts.
  Future<NativeRequest?> nextRequest() async {
    if (_reading) throw StateError('Only one nextRequest may be pending.');
    _reading = true;
    final output = calloc<Pointer<abi.dz_Packet>>();
    try {
      while (!_closing) {
        final status = bindings.dz_take_request(_handle, output);
        if (status == 2) {
          await close();
          return null;
        }
        if (status == 4) throw StateError('Native packet allocation failed.');
        if (status == 0) {
          final packet = output.value;
          try {
            final bytes = Uint8List.fromList(
              bindings
                  .dz_packet_bytes(packet)
                  .asTypedList(bindings.dz_packet_length(packet)),
            );
            return NativeRequest(
              bindings.dz_packet_id(packet),
              bytes,
              sendReply,
              isPending: (id) =>
                  !_closing && bindings.dz_is_pending(_handle, id),
            );
          } finally {
            bindings.dz_packet_free(packet);
          }
        }
        await _changed.future;
      }
      return null;
    } finally {
      calloc.free(output);
      _reading = false;
    }
  }

  /// Sends a protocol reply, waiting asynchronously when native capacity is full.
  ///
  /// Normally called through [NativeRequest]. Copies [bytes] before waiting;
  /// completion means queued, not yet consumed by the native application.
  Future<void> sendReply(int id, ReplyKind kind, Uint8List bytes) async {
    _ensureOpen();
    if (bytes.length > maxBytes) {
      throw ArgumentError.value(
        bytes.length,
        'bytes.length',
        'Exceeds maxBytes',
      );
    }
    final pointer = calloc<Uint8>(bytes.isEmpty ? 1 : bytes.length);
    pointer.asTypedList(bytes.length).setAll(0, bytes);
    try {
      while (true) {
        _ensureOpen();
        final status = bindings.dz_reply(
          _handle,
          id,
          kind.index + 1,
          pointer,
          bytes.length,
        );
        switch (status) {
          case 0:
            return;
          case 1:
            await _changed.future;
          case 2:
            throw StateError('Native bridge is closed.');
          case 3:
            throw StateError('Unknown or completed native request: $id');
          case 4:
            throw StateError('Native allocation failed.');
          default:
            throw StateError('Native reply rejected (status $status).');
        }
      }
    } finally {
      calloc.free(pointer);
    }
  }

  /// Stops admission, wakes Dart waiters, joins native users, and frees storage.
  ///
  /// Repeated calls return the same future. If [stopNative] supplied to the
  /// constructor fails, memory is retained to avoid freeing a live native handle.
  /// Queued replies are discarded; finish application work before graceful close.
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _closing = true;
    bindings.dz_close(_handle);
    _signal();
    _port.close();
    await stopNative?.call();
    bindings.dz_destroy(_handle);
  }
}
