import 'dart:convert';
import 'dart:typed_data';

import 'integer_native.dart'
    if (dart.library.js_interop) 'integer_web.dart'
    as integers;

/// Bounded, explicitly little-endian encoding shared with the Zig codec.
final class BinaryWriter {
  /// Creates an encoder with a maximum encoded message size.
  ///
  /// Writes exceeding [maxBytes] throw [RangeError]. Discard the writer after
  /// a failed write because an earlier prefix may already have been appended.
  BinaryWriter({this.maxBytes = 8 * 1024 * 1024});

  /// Maximum encoded length, including length prefixes and tags.
  final int maxBytes;
  Uint8List _bytes = Uint8List(128);
  int _length = 0;

  void _reserve(int count) {
    if (count < 0 || count > maxBytes - _length) {
      throw RangeError('Encoded message exceeds $maxBytes bytes');
    }
    if (_length + count > _bytes.length) {
      final capacity = (_length + count) > _bytes.length * 2
          ? _length + count
          : _bytes.length * 2;
      final next = Uint8List(capacity);
      next.setRange(0, _length, _bytes);
      _bytes = next;
    }
  }

  /// Appends an unsigned byte; values outside 0–255 throw [RangeError].
  void u8(int value) {
    RangeError.checkValueInInterval(value, 0, 255);
    _reserve(1);
    _bytes[_length++] = value;
  }

  /// Appends a little-endian unsigned 32-bit value, checked for range.
  void u32(int value) {
    RangeError.checkValueInInterval(value, 0, 0xffffffff);
    _reserve(4);
    ByteData.sublistView(_bytes).setUint32(_length, value, Endian.little);
    _length += 4;
  }

  /// Appends a range-checked signed byte.
  void i8(int value) {
    RangeError.checkValueInInterval(value, -128, 127);
    u8(value & 255);
  }

  /// Appends a range-checked unsigned 16-bit integer.
  void u16(int value) {
    RangeError.checkValueInInterval(value, 0, 65535);
    _reserve(2);
    ByteData.sublistView(_bytes).setUint16(_length, value, Endian.little);
    _length += 2;
  }

  /// Appends a range-checked signed 16-bit integer.
  void i16(int value) {
    RangeError.checkValueInInterval(value, -32768, 32767);
    u16(value & 65535);
  }

  /// Appends a range-checked signed 32-bit integer.
  void i32(int value) {
    RangeError.checkValueInInterval(value, -2147483648, 2147483647);
    u32(value & 0xffffffff);
  }

  /// Appends a little-endian IEEE 754 single-precision value.
  void f32(double value) {
    _reserve(4);
    ByteData.sublistView(_bytes).setFloat32(_length, value, Endian.little);
    _length += 4;
  }

  /// Appends an exact signed 128-bit value on every backend.
  void i128(BigInt value) => _big(value, true);

  /// Appends an exact unsigned 128-bit value on every backend.
  void u128(BigInt value) => _big(value, false);
  void _big(BigInt value, bool signed) {
    final limit = BigInt.one << (signed ? 127 : 128);
    if (value < (signed ? -limit : BigInt.zero) || value >= limit) {
      throw RangeError('128-bit value out of range');
    }
    _reserve(16);
    var bits = value.toUnsigned(128);
    for (var i = 0; i < 16; i++) {
      _bytes[_length++] = (bits & BigInt.from(255)).toInt();
      bits >>= 8;
    }
  }

  /// Appends a little-endian signed 64-bit value.
  void i64(int value) {
    _reserve(8);
    integers.write64(ByteData.sublistView(_bytes), _length, value, true);
    _length += 8;
  }

  /// Encodes unsigned bits. Dart native integers use signed 64-bit representation.
  void u64(int value) {
    _reserve(8);
    integers.write64(ByteData.sublistView(_bytes), _length, value, false);
    _length += 8;
  }

  /// Appends an IEEE 754 double in little-endian order.
  void f64(double value) {
    _reserve(8);
    ByteData.sublistView(_bytes).setFloat64(_length, value, Endian.little);
    _length += 8;
  }

  /// Appends zero for false or one for true.
  void boolean(bool value) => u8(value ? 1 : 0);

  /// Copies bytes after their unsigned 32-bit length prefix.
  void bytes(Uint8List value) {
    u32(value.length);
    _reserve(value.length);
    _bytes.setRange(_length, _length + value.length, value);
    _length += value.length;
  }

  /// Appends length-prefixed UTF-8 bytes for [value].
  void string(String value) => bytes(Uint8List.fromList(utf8.encode(value)));

  /// Returns an independent encoded message.
  Uint8List finish() =>
      Uint8List.fromList(Uint8List.sublistView(_bytes, 0, _length));
}

/// Checked decoding with borrowed byte views and explicit trailing-byte checks.
final class BinaryReader {
  /// Borrows [data] for decoding; callers must keep it unchanged while reading.
  ///
  /// Truncated reads throw [FormatException]. Call [finish] after decoding a
  /// complete message to reject unexpected trailing data.
  BinaryReader(this.data, {this.maxCollectionLength = 1000000});

  /// Borrowed message storage; byte results share this allocation.
  final Uint8List data;

  /// Maximum element count accepted by [collectionLength].
  ///
  /// This limits lists, not the byte length of blobs or strings.
  final int maxCollectionLength;
  int _offset = 0;
  int _take(int length) {
    if (length < 0 || length > data.length - _offset) {
      throw const FormatException('Truncated native message');
    }
    final start = _offset;
    _offset += length;
    return start;
  }

  /// Reads one unsigned byte.
  int u8() => data[_take(1)];

  /// Reads a little-endian unsigned 32-bit value.
  int u32() => ByteData.sublistView(data).getUint32(_take(4), Endian.little);

  /// Reads a signed byte.
  int i8() => ByteData.sublistView(data).getInt8(_take(1));

  /// Reads a little-endian unsigned 16-bit integer.
  int u16() => ByteData.sublistView(data).getUint16(_take(2), Endian.little);

  /// Reads a little-endian signed 16-bit integer.
  int i16() => ByteData.sublistView(data).getInt16(_take(2), Endian.little);

  /// Reads a little-endian signed 32-bit integer.
  int i32() => ByteData.sublistView(data).getInt32(_take(4), Endian.little);

  /// Reads an IEEE 754 single-precision value.
  double f32() =>
      ByteData.sublistView(data).getFloat32(_take(4), Endian.little);

  /// Reads an exact signed 128-bit integer.
  BigInt i128() => _big().toSigned(128);

  /// Reads an exact unsigned 128-bit integer.
  BigInt u128() => _big();
  BigInt _big() {
    final start = _take(16);
    var value = BigInt.zero;
    for (var i = 15; i >= 0; i--) {
      value = (value << 8) | BigInt.from(data[start + i]);
    }
    return value;
  }

  /// Reads a little-endian signed 64-bit value.
  int i64() => integers.read64(ByteData.sublistView(data), _take(8), true);

  /// Reads unsigned bits using Dart native integer representation.
  int u64() => integers.read64(ByteData.sublistView(data), _take(8), false);

  /// Reads an IEEE 754 double in little-endian order.
  double f64() =>
      ByteData.sublistView(data).getFloat64(_take(8), Endian.little);

  /// Reads zero or one; other tags throw [FormatException].
  bool boolean() => switch (u8()) {
    0 => false,
    1 => true,
    _ => throw const FormatException('Invalid boolean'),
  };

  /// Reads a list length and rejects counts above [maxCollectionLength].
  int collectionLength() {
    final length = u32();
    if (length > maxCollectionLength) {
      throw const FormatException('Collection too large');
    }
    return length;
  }

  /// Reads a length-prefixed borrowed view into [data].
  Uint8List bytes() {
    final length = u32();
    final start = _take(length);
    return Uint8List.sublistView(data, start, start + length);
  }

  /// Reads a length-prefixed UTF-8 string, rejecting malformed encoding.
  String string() => utf8.decode(bytes());

  /// Rejects trailing bytes with [FormatException].
  void finish() {
    if (_offset != data.length) {
      throw const FormatException('Trailing native bytes');
    }
  }
}

/// Model-specific conversion generated from the shared schema.
abstract interface class BinaryCodec<T> {
  /// Encodes [value] into independently owned bytes.
  Uint8List encode(T value);

  /// Decodes one complete message; byte fields may borrow [bytes].
  ///
  /// Invalid input throws [FormatException].
  T decode(Uint8List bytes);
}
