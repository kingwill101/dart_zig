// ignore_for_file: non_constant_identifier_names
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'native_buffer.dart';
import 'runtime_error.dart';
import 'transport.dart';

@JS('fetch')
external JSPromise<WebResponse> _fetch(JSString uri);

@JS()
extension type WebResponse(JSObject _) implements JSObject {
  external bool get ok;
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

@JS('WebAssembly.instantiate')
external JSPromise<WasmResult> _instantiate(JSArrayBuffer bytes);

@JS()
extension type WasmResult(JSObject _) implements JSObject {
  external WasmInstance get instance;
}

@JS()
extension type WasmInstance(JSObject _) implements JSObject {
  external WasmApi get exports;
}

@JS()
extension type WasmMemory(JSObject _) implements JSObject {
  external JSArrayBuffer get buffer;
}

@JS()
extension type WasmApi(JSObject _) implements JSObject {
  external WasmMemory get memory;
  external int dz_web_protocol();
  external int dz_web_schema();
  external int dz_web_alloc(int length);
  external void dz_web_free(int pointer, int length);
  external int dz_web_create(int count, int bytes, int tasks);
  external void dz_web_destroy(int runtime);
  external void dz_web_stop(int runtime);
  external int dz_web_stopped(int runtime);
  external double dz_web_submit(
    int runtime,
    int route,
    int kind,
    int data,
    int length,
  );
  external int dz_web_send(int runtime, int route, int data, int length);
  external int dz_web_callback(
    int runtime,
    double id,
    int route,
    int code,
    int data,
    int length,
  );
  external void dz_web_cancel(int runtime, double id);
  external void dz_web_grant(int runtime, double id);
  external int dz_web_pump(int runtime, int budget);
  external int dz_web_work(int runtime);
  external int dz_web_poll(int runtime);
  external double dz_web_frame_field(int frame, int field);
  external void dz_web_frame_release(int frame);
  external double dz_web_stats(int runtime, int field);
  external double dz_web_live(int field);
  external double dz_web_sum(double a, double b);
}

WasmApi? _defaultApi;

/// Loads the browser's Wasm asset before constructing sessions.
///
/// A custom URL supports subpath hosting; bytes can be supplied by a host loader.
/// Existing sessions keep their original module when another module is loaded.
Future<void> initializeZig({Uri? wasmUri, Uint8List? wasmBytes}) async {
  JSArrayBuffer bytes;
  if (wasmBytes != null) {
    bytes = Uint8List.fromList(wasmBytes).buffer.toJS;
  } else {
    final response = await _fetch(
      (wasmUri ?? Uri.parse('dart_zig.wasm')).toString().toJS,
    ).toDart;
    if (!response.ok) throw StateError('Unable to fetch Zig WebAssembly');
    bytes = await response.arrayBuffer().toDart;
  }
  _defaultApi = (await _instantiate(bytes).toDart).instance.exports;
}

/// A Wasm runtime driven cooperatively by the browser event loop.
final class WebTransport implements SessionTransport {
  WebTransport({
    required int queueCapacity,
    required int maxBytes,
    required int maxPending,
    WasmApi? api,
  }) : api =
           api ??
           _defaultApi ??
           (throw StateError(
             'Await initializeZig before creating a Web session',
           )) {
    _handle = this.api.dz_web_create(queueCapacity, maxBytes, maxPending);
    if (_handle == 0) {
      throw const NativeException('allocation', 'Cannot create Wasm runtime');
    }
  }
  final WasmApi api;
  late final int _handle;
  bool _destroyed = false, _scheduled = false;
  @override
  void Function()? onWake;
  @override
  int get protocolVersion => api.dz_web_protocol();
  @override
  int get schemaFingerprint => api.dz_web_schema().toUnsigned(32);
  void _schedule() {
    if (_scheduled || _destroyed || stopped) return;
    _scheduled = true;
    Timer.run(() {
      _scheduled = false;
      if (_destroyed || stopped) return;
      api.dz_web_pump(_handle, 32);
      onWake?.call();
      if (!_destroyed && !stopped && api.dz_web_work(_handle) != 0) _schedule();
    });
  }

  T _input<T>(Uint8List bytes, T Function(int) call) {
    final length = bytes.isEmpty ? 1 : bytes.length;
    final pointer = api.dz_web_alloc(length);
    if (pointer == 0) {
      throw const NativeException('allocation', 'Wasm input allocation failed');
    }
    try {
      api.memory.buffer.toDart
          .asUint8List(pointer, bytes.length)
          .setAll(0, bytes);
      return call(pointer);
    } finally {
      api.dz_web_free(pointer, length);
    }
  }

  @override
  ({int status, int id}) submit(
    int route,
    int kind,
    Uint8List bytes,
    int timeoutNs,
  ) {
    final value = _input(
      bytes,
      (pointer) =>
          api.dz_web_submit(_handle, route, kind, pointer, bytes.length),
    );
    _schedule();
    return value < 0
        ? (status: -value.toInt(), id: 0)
        : (status: 0, id: value.toInt());
  }

  @override
  int sendSignal(int route, Uint8List bytes) {
    final status = _input(
      bytes,
      (pointer) => api.dz_web_send(_handle, route, pointer, bytes.length),
    );
    _schedule();
    return status;
  }

  @override
  int callbackReply(int id, int callbackId, int code, Uint8List bytes) {
    final status = _input(
      bytes,
      (pointer) => api.dz_web_callback(
        _handle,
        id.toDouble(),
        callbackId,
        code,
        pointer,
        bytes.length,
      ),
    );
    _schedule();
    return status;
  }

  @override
  void cancel(int id) {
    api.dz_web_cancel(_handle, id.toDouble());
  }

  @override
  void grant(int id) {
    api.dz_web_grant(_handle, id.toDouble());
    _schedule();
  }

  @override
  List<TransportFrame> poll(int capacity) {
    final output = <TransportFrame>[];
    for (var i = 0; i < capacity; i++) {
      final frame = api.dz_web_poll(_handle);
      if (frame == 0) break;
      int field(int n) => api.dz_web_frame_field(frame, n).toInt();
      try {
        final length = field(4);
        final bytes = length == 0
            ? Uint8List(0)
            : api.memory.buffer.toDart.asUint8List(field(5), length);
        output.add(
          TransportFrame(
            field(0),
            field(1),
            field(2),
            field(3),
            NativeBuffer.fromBytes(bytes),
          ),
        );
      } finally {
        api.dz_web_frame_release(frame);
      }
    }
    return output;
  }

  @override
  TransportStats get stats {
    int read(int field) => api.dz_web_stats(_handle, field).toInt();
    return TransportStats(
      submitted: read(0),
      delivered: read(1),
      wakes: read(2),
      copiedBytes: read(3),
      logDrops: read(4),
      inputMessages: read(5),
      outputMessages: read(6),
      inputBytes: read(7),
      outputBytes: read(8),
    );
  }

  @override
  bool get stopped => _destroyed || api.dz_web_stopped(_handle) != 0;
  @override
  bool get readyToDestroy => stopped;
  @override
  void stop() {
    if (!_destroyed) api.dz_web_stop(_handle);
  }

  @override
  void destroy() {
    if (_destroyed) return;
    _destroyed = true;
    onWake = null;
    api.dz_web_destroy(_handle);
  }
}

SessionTransport createTransport({
  Object? bindings,
  required int queueCapacity,
  required int maxBytes,
  required int maxPending,
  required int workers,
  required int batchSize,
}) {
  if (bindings != null) {
    throw ArgumentError(
      'Supply a WebTransport through transport for a custom Wasm asset',
    );
  }
  return WebTransport(
    queueCapacity: queueCapacity,
    maxBytes: maxBytes,
    maxPending: maxPending,
  );
}

int get liveBuffers => _defaultApi?.dz_web_live(0).toInt() ?? 0;
int get liveBufferBytes => _defaultApi?.dz_web_live(1).toInt() ?? 0;
int webSum(int a, int b, {WasmApi? api}) {
  final result =
      (api ?? _defaultApi ?? (throw StateError('Await initializeZig')))
          .dz_web_sum(a.toDouble(), b.toDouble());
  if (!result.isFinite) {
    throw const NativeException(
      'sync_error',
      'Integer sum exceeds the Web safe range',
    );
  }
  return result.toInt();
}
