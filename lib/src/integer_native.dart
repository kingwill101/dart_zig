import 'dart:typed_data';

void write64(ByteData data, int offset, int value, bool signed) {
  if (signed) {
    data.setInt64(offset, value, Endian.little);
  } else {
    data.setUint64(offset, value, Endian.little);
  }
}

int read64(ByteData data, int offset, bool signed) => signed
    ? data.getInt64(offset, Endian.little)
    : data.getUint64(offset, Endian.little);
