import 'dart:ffi';
import 'dart:typed_data';

import 'generated/runtime_bindings.g.dart';

/// An owned reference to native bytes, independent of the session lifetime.
///
/// Dispose explicitly. A native finalizer is a fallback for unreachable buffers.
/// Views must not be accessed after disposal; use [copy] for independent Dart data.
final class NativeBuffer implements Finalizable {
  /// Adopts one existing native reference from the runtime transport.
  ///
  /// The owner, data pointer, length, and [bindings] must come from the same
  /// native asset and allocation. This constructor does not retain another
  /// reference. Prefer obtaining buffers through a session call.
  NativeBuffer.fromOwned(
    this._owner,
    this._data,
    this.length, {
    this.bindings = const GeneratedRuntimeBindings(),
  }) {
    bindings.bufferFinalizer.attach(
      this,
      _owner,
      detach: this,
      externalSize: bindings.dz_buffer_capacity(_owner),
    );
  }

  /// Native asset responsible for releasing this allocation.
  NativeBuffer.fromBytes(Uint8List bytes)
    : bindings = const GeneratedRuntimeBindings(),
      _owner = nullptr,
      _data = nullptr,
      length = bytes.length,
      _managed = Uint8List.fromList(bytes);
  NativeBuffer._managed(Uint8List bytes)
    : bindings = const GeneratedRuntimeBindings(),
      _owner = nullptr,
      _data = nullptr,
      length = bytes.length,
      _managed = bytes;
  Uint8List? _managed;
  final RuntimeBindings bindings;
  final Pointer<Void> _owner;
  final Pointer<Uint8> _data;

  /// Number of readable payload bytes, excluding spare allocation capacity.
  final int length;
  bool _disposed = false;

  /// Borrowed view; valid only while this buffer remains undisposed and reachable.
  Uint8List get view {
    if (_disposed) throw StateError('Native buffer is disposed');
    return _managed ?? _data.asTypedList(length);
  }

  /// Retains an independent lease; disposing either lease leaves the other valid.
  NativeBuffer retain() {
    if (_disposed) throw StateError('Native buffer is disposed');
    if (_managed != null) return NativeBuffer._managed(_managed!);
    bindings.dz_buffer_retain(_owner);
    return NativeBuffer.fromOwned(_owner, _data, length, bindings: bindings);
  }

  /// Retains a subrange without copying. It keeps the entire allocation alive.
  NativeBuffer slice(int start, [int? end]) {
    final stop = end ?? length;
    RangeError.checkValidRange(start, stop, length);
    if (_disposed) throw StateError('Native buffer is disposed');
    if (_managed != null) {
      return NativeBuffer._managed(
        Uint8List.sublistView(_managed!, start, stop),
      );
    }
    bindings.dz_buffer_retain(_owner);
    return NativeBuffer.fromOwned(
      _owner,
      _data + start,
      stop - start,
      bindings: bindings,
    );
  }

  /// Copies the payload into independent Dart memory.
  ///
  /// Throws [StateError] after disposal.
  Uint8List copy() => Uint8List.fromList(view);

  /// Whether this owned reference has been released.
  bool get isDisposed => _disposed;

  /// Releases ownership and invalidates all borrowed views.
  ///
  /// Repeated calls have no effect.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_managed != null) {
      _managed = null;
      return;
    }
    bindings.bufferFinalizer.detach(this);
    bindings.dz_buffer_release(_owner);
  }
}
