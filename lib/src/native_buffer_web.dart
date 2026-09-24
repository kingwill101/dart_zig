import 'dart:typed_data';

/// An explicitly owned byte result on the Web backend.
///
/// Web results currently copy out of Wasm memory so memory growth cannot detach
/// existing views. The ownership API matches native without claiming zero-copy.
final class NativeBuffer {
  NativeBuffer.fromBytes(Uint8List bytes) : _bytes = Uint8List.fromList(bytes);
  NativeBuffer._(this._bytes);
  Uint8List? _bytes;
  int get length => view.length;
  bool get isDisposed => _bytes == null;
  Uint8List get view => _bytes ?? (throw StateError('Buffer is disposed'));
  Uint8List copy() => Uint8List.fromList(view);
  NativeBuffer retain() => NativeBuffer._(view);

  /// Retains a shared Dart-owned subrange of the copied Wasm result.
  NativeBuffer slice(int start, [int? end]) =>
      NativeBuffer._(Uint8List.sublistView(view, start, end));
  void dispose() {
    _bytes = null;
  }
}
