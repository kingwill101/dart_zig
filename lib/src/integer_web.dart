import 'dart:typed_data';

const maxSafe = 9007199254740991;
void write64(ByteData data, int offset, int value, bool signed) {
  if (value < (signed ? -maxSafe : 0) || value > maxSafe) {
    throw RangeError(
      'Web int values must be exactly representable; use BigInt for wider values',
    );
  }
  var bits = BigInt.from(value).toUnsigned(64);
  for (var i = 0; i < 8; i++) {
    data.setUint8(offset + i, (bits & BigInt.from(255)).toInt());
    bits >>= 8;
  }
}

int read64(ByteData data, int offset, bool signed) {
  var bits = BigInt.zero;
  for (var i = 7; i >= 0; i--) {
    bits = (bits << 8) | BigInt.from(data.getUint8(offset + i));
  }
  if (signed) bits = bits.toSigned(64);
  if (bits.abs() > BigInt.from(maxSafe)) {
    throw const FormatException('64-bit value exceeds Web int precision');
  }
  return bits.toInt();
}
