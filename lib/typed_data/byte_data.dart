// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.typed_data;

class Endianness {
  final bool _littleEndian;
  const Endianness._create(this._littleEndian);

  static const Endianness BIG_ENDIAN = const Endianness._create(false);
  static const Endianness LITTLE_ENDIAN = const Endianness._create(true);
  // We only support LITTLE_ENDIAN for now.
  static final Endianness HOST_ENDIAN = LITTLE_ENDIAN;
}

class ByteData extends TypedData {
  ByteData(int length) : super._create(length);

  ByteData.view(ByteBuffer buffer, [int offsetInBytes = 0, int length])
      : super._wrap(buffer, offsetInBytes, length);

  int get elementSizeInBytes => 1;


  // Signed nt getters.
  int getInt8(int byteOffset) => _foreign.getInt8(byteOffset);
  int getInt16(int byteOffset, [Endianness endian = Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    return _foreign.getInt16(byteOffset);
  }
  int getInt32(int byteOffset, [Endianness endian = Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    return _foreign.getInt32(byteOffset);
  }
  int getInt64(int byteOffset, [Endianness endian = Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    return _foreign.getInt64(byteOffset);
  }

  // Unsigned int getters.
  int getUint8(int byteOffset) => _foreign.getUint8(byteOffset);
  int getUint16(int byteOffset, [Endianness endian = Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    return _foreign.getUint16(byteOffset);
  }
  int getUint32(int byteOffset, [Endianness endian = Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    return _foreign.getUint32(byteOffset);
  }
  int getUint64(int byteOffset, [Endianness endian = Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    return _foreign.getUint64(byteOffset);
  }

  // Float getters.
  double getFloat32(int byteOffset, [Endianness endian=Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    return _foreign.getFloat32(byteOffset);
  }
  double getFloat64(int byteOffset, [Endianness endian=Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    return _foreign.getFloat64(byteOffset);
  }

  // Int setters.
  void setInt8(int byteOffset, int value) {
    _foreign.setInt8(byteOffset, value);
  }
  void setInt16(int byteOffset,
                int value,
                [Endianness endian = Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    _foreign.setInt16(byteOffset, value);
  }
  void setInt32(int byteOffset,
                int value,
                [Endianness endian = Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    _foreign.setInt32(byteOffset, value);
  }
  void setInt64(int byteOffset,
                int value,
                [Endianness endian = Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    _foreign.setInt64(byteOffset, value);
  }

  // Uint setters.
  void setUint8(int byteOffset, int value) {
    _foreign.setUint8(byteOffset, value);
  }
  void setUint16(int byteOffset,
                 int value,
                 [Endianness endian = Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    _foreign.setUint16(byteOffset, value);
  }
  void setUint32(int byteOffset,
                 int value,
                 [Endianness endian = Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    _foreign.setUint32(byteOffset, value);
  }
  void setUint64(int byteOffset,
                 int value,
                 [Endianness endian = Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    _foreign.setUint64(byteOffset, value);
  }

  // Float setters.
  void setFloat32(int byteOffset,
                  double value,
                  [Endianness endian=Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    _foreign.setFloat32(byteOffset, value);
  }
  void setFloat64(int byteOffset,
                  double value,
                  [Endianness endian=Endianness.BIG_ENDIAN]) {
    _checkEndianness(endian);
    _foreign.setFloat64(byteOffset, value);
  }

  static void _checkEndianness(Endianness endian) {
    if (endian != Endianness.LITTLE_ENDIAN) {
      throw new UnimplementedError("Only LITTLE_ENDIAN is implemented");
    }
  }
}
