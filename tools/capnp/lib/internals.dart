// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library capnp.internals;

import 'dart:typed_data' show ByteData, Endianness;
import 'dart:collection' show ListMixin;
import 'dart:convert' show UTF8;

import 'message.dart';

class Pointer {
  Segment _segment;
  int _offset = 0;
}

abstract class Struct extends Pointer {
  int _pointersOffset = 0;
  int get declaredWords;
  int get declaredPointers;
}

abstract class StructList extends _List {
  int _elementSize = 0;
  int _elementDataSize = 0;

  int get _declaredElementKind => 7;
  int get declaredElementWords;
  int get declaredElementPointers;
}

abstract class StructBuilder extends Struct {
  int get declaredWords;
  int get declaredPointers;
  int get declaredSize;
}

abstract class StructListBuilder extends _ListBuilder {
  int get _declaredElementKind => 7;
  int get declaredElementWords;
  int get declaredElementPointers;
  int get declaredElementSize;
  void operator[]=(int index, value) => throw "Cannot modify.";
}

class Data extends _ListOfUInt8 {
}

class Text extends _ListOfUInt8 {
  int get length => _length - 1;
  toString() => UTF8.decode(this);
}

Struct readStructRoot(Struct out, Segment segment) {
  Struct base = new _StructRoot(segment);
  return readStruct(out, base, 0);
}

Struct readStruct(Struct out, Struct base, int index) {
  int offset = base._pointersOffset + index * 8;
  Segment segment = base._segment;

  while (true) {
    final ByteData bytes = segment.bytes;
    int lo = bytes.getInt32(offset + 0, Endianness.LITTLE_ENDIAN);
    int hi = bytes.getUint32(offset + 4, Endianness.LITTLE_ENDIAN);
    if (lo == 0 && hi == 0) throw "Cannot handle null structs yet.";

    // Struct pointer format.
    //
    // lsb                      struct pointer                       msb
    // +-+-----------------------------+---------------+---------------+
    // |A|             B               |       C       |       D       |
    // +-+-----------------------------+---------------+---------------+
    //
    // A (2 bits) = 0, to indicate that this is a struct pointer.
    // B (30 bits) = Offset, in words, from the end of the pointer to the
    //     start of the struct's data section.  Signed.
    // C (16 bits) = Size of the struct's data section, in words.
    // D (16 bits) = Size of the struct's pointer section, in words.

    int A = lo & 3;
    if (A == 0) {
      int B = lo >> 2;
      int target = offset + (B + 1) * 8;

      int words = hi & 0xffff;
      int pointers = hi >> 16;
      if (words < out.declaredWords) throw "Not enough words";
      if (pointers < out.declaredPointers) throw "Not enough pointers";

      out._segment = segment;
      out._offset = target;
      out._pointersOffset = target + words * 8;
      return out;
    }

    if (A != 2) throw new StateError("Not a struct");

    // Intersegment pointer format.
    //
    // lsb                        far pointer                        msb
    // +-+-+---------------------------+-------------------------------+
    // |A|B|            C              |               D               |
    // +-+-+---------------------------+-------------------------------+
    //
    // A (2 bits) = 2, to indicate that this is a far pointer.
    // B (1 bit) = 0 if the landing pad is one word, 1 if it is two words.
    //     See explanation below.
    // C (29 bits) = Offset, in words, from the start of the target segment
    //     to the location of the far-pointer landing-pad within that
    //     segment.  Unsigned.
    // D (32 bits) = ID of the target segment.  (Segments are numbered
    //     sequentially starting from zero.)

    int B = (lo >> 2) & 1;
    if (B != 0) throw "Cannot deal with double-far intersegment pointers";
    segment = segment.getSegment(hi);
    offset = lo & ~7;
  }
}

StructList readStructList(StructList out, Struct base, int index) {
  int offset = base._pointersOffset + index * 8;
  Segment segment = base._segment;

  while (true) {
    final ByteData bytes = segment.bytes;
    int lo = bytes.getInt32(offset + 0, Endianness.LITTLE_ENDIAN);
    int hi = bytes.getUint32(offset + 4, Endianness.LITTLE_ENDIAN);
    if (lo == 0 && hi == 0) return out;

    // Struct list pointer format.
    //
    // lsb                       list pointer                        msb
    // +-+-----------------------------+--+----------------------------+
    // |A|             B               |C |             D              |
    // +-+-----------------------------+--+----------------------------+
    //
    // A (2 bits) = 1, to indicate that this is a list pointer.
    // B (30 bits) = Offset, in words, from the end of the pointer to the
    //     start of the struct list tag.  Signed.
    // C (3 bits) = 7 (composite)
    // D (29 bits) = Total size (data and pointers) of the list in words.

    int A = lo & 3;
    if (A == 1) {
      int C = hi & 7;
      if (C != 7) throw new StateError("Not a struct list");

      // Read the tag struct pointer.
      int B = lo >> 2;
      int start = offset + (B + 1) * 8;
      lo = bytes.getUint32(start + 0, Endianness.LITTLE_ENDIAN);
      hi = bytes.getUint32(start + 4, Endianness.LITTLE_ENDIAN);
      if ((lo & 3) != 0) throw "Struct list tag must be a struct";

      out._segment = segment;
      out._offset = start + 8;
      out._length = lo >> 2;

      int words = hi & 0xffff;
      int pointers = hi >> 16;
      if (words < out.declaredElementWords) throw "Not enough words";
      if (pointers < out.declaredElementPointers) throw "Not enough pointers";

      int dataSize = words * 8;
      out._elementSize = dataSize + (pointers * 8);
      out._elementDataSize = dataSize;
      return out;
    }

    if (A != 2) throw new StateError("Not a struct list");

    // Intersegment pointer format.
    //
    // lsb                        far pointer                        msb
    // +-+-+---------------------------+-------------------------------+
    // |A|B|            C              |               D               |
    // +-+-+---------------------------+-------------------------------+
    //
    // A (2 bits) = 2, to indicate that this is a far pointer.
    // B (1 bit) = 0 if the landing pad is one word, 1 if it is two words.
    //     See explanation below.
    // C (29 bits) = Offset, in words, from the start of the target segment
    //     to the location of the far-pointer landing-pad within that
    //     segment.  Unsigned.
    // D (32 bits) = ID of the target segment.  (Segments are numbered
    //     sequentially starting from zero.)

    int B = (lo >> 2) & 1;
    if (B != 0) throw "Cannot deal with double-far intersegment pointers";
    segment = segment.getSegment(hi);
    offset = lo & ~7;
  }
}

_List _readNonStructList(_List out, Struct base, int index) {
  int offset = base._pointersOffset + index * 8;
  Segment segment = base._segment;

  while (true) {
    final ByteData bytes = segment.bytes;
    int lo = bytes.getInt32(offset + 0, Endianness.LITTLE_ENDIAN);
    int hi = bytes.getUint32(offset + 4, Endianness.LITTLE_ENDIAN);
    if (lo == 0 && hi == 0) return out;

    //  List pointer format.
    //
    // lsb                       list pointer                        msb
    // +-+-----------------------------+--+----------------------------+
    // |A|             B               |C |             D              |
    // +-+-----------------------------+--+----------------------------+
    //
    // A (2 bits) = 1, to indicate that this is a list pointer.
    // B (30 bits) = Offset, in words, from the end of the pointer to the
    //     start of the struct list tag.  Signed.
    // C (3 bits) = Size of each element:
    //     0 = 0 (e.g. List(Void))
    //     1 = 1 bit
    //     2 = 1 byte
    //     3 = 2 bytes
    //     4 = 4 bytes
    //     5 = 8 bytes (non-pointer)
    //     6 = 8 bytes (pointer)
    // D (29 bits) = Number of elements in the list.

    int A = lo & 3;
    if (A == 1) {
      int C = hi & 7;
      if (C != out._declaredElementKind) throw "Wrong element kind.";
      int B = lo >> 2;
      int D = hi >> 3;

      out._segment = segment;
      out._offset = offset + (B + 1) * 8;
      out._length = D;
      return out;
    }

    if (A != 2) throw new StateError("Not a non-struct list");

    // Intersegment pointer format.
    //
    // lsb                        far pointer                        msb
    // +-+-+---------------------------+-------------------------------+
    // |A|B|            C              |               D               |
    // +-+-+---------------------------+-------------------------------+
    //
    // A (2 bits) = 2, to indicate that this is a far pointer.
    // B (1 bit) = 0 if the landing pad is one word, 1 if it is two words.
    //     See explanation below.
    // C (29 bits) = Offset, in words, from the start of the target segment
    //     to the location of the far-pointer landing-pad within that
    //     segment.  Unsigned.
    // D (32 bits) = ID of the target segment.  (Segments are numbered
    //     sequentially starting from zero.)

    int B = (lo >> 2) & 1;
    if (B != 0) throw "Cannot deal with double-far intersegment pointers";
    segment = segment.getSegment(hi);
    offset = lo & ~7;
  }
}

Struct readStructListElement(Struct out, StructList base, int index) {
  final int offset = base._offset + (index * base._elementSize);
  out._segment = base._segment;
  out._offset = offset;
  out._pointersOffset = offset + base._elementDataSize;
  return out;
}

List<int> readUInt8List(Struct base, int index) {
  return _readNonStructList(new _ListOfUInt8(), base, index);
}

List<int> readUInt64List(Struct base, int index) {
  return _readNonStructList(new _ListOfUInt64(), base, index);
}

Text readText(Struct base, int index) {
  return _readNonStructList(new Text(), base, index);
}

Data readData(Struct base, int index) {
  return _readNonStructList(new Data(), base, index);
}

bool readBool(Pointer base, int offset, int mask) {
  return (readUInt8(base, offset) & mask) != 0;
}

int readUInt8(Pointer base, int offset) {
  ByteData bytes = base._segment.bytes;
  return bytes.getUint8(base._offset + offset);
}

int readUInt16(Pointer base, int offset) {
  ByteData bytes = base._segment.bytes;
  return bytes.getUint16(base._offset + offset, Endianness.LITTLE_ENDIAN);
}

int readUInt32(Pointer base, int offset) {
  ByteData bytes = base._segment.bytes;
  return bytes.getUint32(base._offset + offset, Endianness.LITTLE_ENDIAN);
}

int readUInt64(Pointer base, int offset) {
  ByteData bytes = base._segment.bytes;
  return bytes.getUint64(base._offset + offset, Endianness.LITTLE_ENDIAN);
}

int readInt8(Struct base, int offset) {
  ByteData bytes = base._segment.bytes;
  return bytes.getInt8(base._offset + offset);
}

int readInt16(Pointer base, int offset) {
  ByteData bytes = base._segment.bytes;
  return bytes.getInt16(base._offset + offset, Endianness.LITTLE_ENDIAN);
}

int readInt32(Pointer base, int offset) {
  ByteData bytes = base._segment.bytes;
  return bytes.getInt32(base._offset + offset, Endianness.LITTLE_ENDIAN);
}

int readInt64(Pointer base, int offset) {
  ByteData bytes = base._segment.bytes;
  return bytes.getInt64(base._offset + offset, Endianness.LITTLE_ENDIAN);
}

double readFloat32(Pointer base, int offset) {
  ByteData bytes = base._segment.bytes;
  return bytes.getFloat32(base._offset + offset, Endianness.LITTLE_ENDIAN);
}

double readFloat64(Pointer base, int offset) {
  ByteData bytes = base._segment.bytes;
  return bytes.getFloat64(base._offset + offset, Endianness.LITTLE_ENDIAN);
}

StructBuilder writeStructRoot(StructBuilder out, BuilderSegment segment) {
  Struct base = new _StructRoot(segment);
  if (segment.allocateLocally(8) != 0) throw "Must be first allocation";
  return writeStruct(out, base, 0);
}

StructBuilder writeStruct(StructBuilder out, Struct base, int index) {
  final int size = out.declaredSize;
  int offset = base._offset + (base.declaredWords + index) * 8;
  BuilderSegment segment = base._segment;

  while (true) {
    final ByteData bytes = segment.bytes;
    int target = segment.allocateLocally(size);
    if (target >= 0) {
      int A = 0;  // Struct pointer.
      int B = (target - (offset + 8)) ~/ 8;
      int C = out.declaredWords;
      int D = out.declaredPointers;

      int h32 = (D << 16) | C;
      int l32 = (B << 2) | A;
      bytes.setUint32(offset + 0, l32, Endianness.LITTLE_ENDIAN);
      bytes.setUint32(offset + 4, h32, Endianness.LITTLE_ENDIAN);

      out._segment = segment;
      out._offset = target;
      out._pointersOffset = target + C * 8;
      return out;
    }

    BuilderSegment other = segment._builder.findSegmentForBytes(size + 8);
    target = other.allocateLocally(8);
    assert(target >= 0);

    int A = 2;  // Intersegment pointer.
    int B = 0;
    int C = target ~/ 8;
    int D = other._id;

    int h32 = D;
    int l32 = (C << 3) | (B << 2) | A;
    bytes.setUint32(offset + 0, l32, Endianness.LITTLE_ENDIAN);
    bytes.setUint32(offset + 4, h32, Endianness.LITTLE_ENDIAN);

    // Update segment and offset to the target.
    segment = other;
    offset = target;
  }
}

StructListBuilder writeStructList(StructListBuilder out,
                                  Struct base,
                                  int index) {
  final int length = out.length;
  final int size = length * out.declaredElementSize;

  int offset = base._offset + (base.declaredWords + index) * 8;
  BuilderSegment segment = base._segment;

  while (true) {
    final ByteData bytes = segment.bytes;
    int target = segment.allocateLocally(size + 8);
    if (target >= 0) {
      int A = 1;  // List pointer.
      int B = (target - (offset + 8)) ~/ 8;
      int C = 7;
      int D = size ~/ 8;

      int hi = (D << 3) | C;
      int lo = (B << 2) | A;
      bytes.setInt32(offset + 0, lo, Endianness.LITTLE_ENDIAN);
      bytes.setUint32(offset + 4, hi, Endianness.LITTLE_ENDIAN);

      // TODO(kasperl): Can we write the tag with a struct write helper?
      A = 0;
      B = length;
      C = out.declaredElementWords;
      D = out.declaredElementPointers;

      hi = (D << 16) | C;
      lo = (B << 2) | A;
      bytes.setUint32(target + 0, lo, Endianness.LITTLE_ENDIAN);
      bytes.setUint32(target + 4, hi, Endianness.LITTLE_ENDIAN);

      out._segment = segment;
      out._offset = target + 8;
      return out;
    }

    BuilderSegment other = segment._builder.findSegmentForBytes(size + 8);
    target = other.allocateLocally(8);
    assert(target >= 0);

    int A = 2;  // Intersegment pointer.
    int B = 0;
    int C = target ~/ 8;
    int D = other._id;

    int lo = (C << 3) | (B << 2) | A;
    int hi = D;
    bytes.setUint32(offset + 0, lo, Endianness.LITTLE_ENDIAN);
    bytes.setUint32(offset + 4, hi, Endianness.LITTLE_ENDIAN);

    // Update segment and offset to the target.
    segment = other;
    offset = target;
  }
}

_ListBuilder _writeNonStructList(_ListBuilder out, Struct base, int index) {
  final int length = out.length;
  final int size = (length * out._declaredElementSize + 7) & ~7;
  int offset = base._offset + (base.declaredWords + index) * 8;
  BuilderSegment segment = base._segment;

  while (true) {
    final ByteData bytes = segment.bytes;
    int target = segment.allocateLocally(size);
    if (target >= 0) {
      int A = 1;  // List pointer.
      int B = (target - (offset + 8)) ~/ 8;
      int C = out._declaredElementKind;
      int D = length;

      int lo = (B << 2) | A;
      int hi = (D << 3) | C;
      bytes.setInt32(offset + 0, lo, Endianness.LITTLE_ENDIAN);
      bytes.setUint32(offset + 4, hi, Endianness.LITTLE_ENDIAN);

      out._segment = segment;
      out._offset = target;
      return out;
    }

    BuilderSegment other = segment._builder.findSegmentForBytes(size + 8);
     target = other.allocateLocally(8);
    assert(target >= 0);

    int A = 2;  // Intersegment pointer.
    int B = 0;
    int C = target ~/ 8;
    int D = other._id;

    int hi = D;
    int lo = (C << 3) | (B << 2) | A;
    bytes.setUint32(offset + 0, hi, Endianness.LITTLE_ENDIAN);
    bytes.setUint32(offset + 4, lo, Endianness.LITTLE_ENDIAN);

    // Update segment and offset to the target.
    segment = other;
    offset = target;
  }
}

StructBuilder writeStructListElement(StructBuilder out,
                                     StructListBuilder base,
                                     int index) {
  final int offset = base._offset + (index * base.declaredElementSize);
  out._segment = base._segment;
  out._offset = offset;
  return out;
}

void writeText(Struct base, int index, String value) {
  List<int> encoded = UTF8.encode(value);
  _ListOfUInt8Builder builder = new _ListOfUInt8Builder(encoded.length + 1);
  _writeNonStructList(builder, base, index);
  for (int i = 0; i < encoded.length; i++) builder[i] = encoded[i];
  assert(builder[encoded.length] == 0);
}

void writeBool(Pointer base, int offset, int mask, bool value) {
  throw "Unimplemented";
}

void writeUInt8(Pointer base, int offset, int value) {
  ByteData bytes = base._segment.bytes;
  bytes.setUint8(base._offset + offset, value);
}

void writeUInt16(Pointer base, int offset, int value) {
  ByteData bytes = base._segment.bytes;
  bytes.setUint16(base._offset + offset, value, Endianness.LITTLE_ENDIAN);
}

void writeUInt32(Pointer base, int offset, int value) {
  ByteData bytes = base._segment.bytes;
  bytes.setUint32(base._offset + offset, value, Endianness.LITTLE_ENDIAN);
}

void writeUInt64(Pointer base, int offset, int value) {
  ByteData bytes = base._segment.bytes;
  bytes.setUint64(base._offset + offset, value, Endianness.LITTLE_ENDIAN);
}

void writeInt8(Pointer base, int offset, int value) {
  ByteData bytes = base._segment.bytes;
  bytes.setInt8(base._offset + offset, value);
}

void writeInt16(Pointer base, int offset, int value) {
  ByteData bytes = base._segment.bytes;
  bytes.setInt16(base._offset + offset, value, Endianness.LITTLE_ENDIAN);
}

void writeInt32(Pointer base, int offset, int value) {
  ByteData bytes = base._segment.bytes;
  bytes.setInt32(base._offset + offset, value, Endianness.LITTLE_ENDIAN);
}

void writeInt64(Pointer base, int offset, int value) {
  ByteData bytes = base._segment.bytes;
  bytes.setInt64(base._offset + offset, value, Endianness.LITTLE_ENDIAN);
}

void writeFloat32(Pointer base, int offset, double value) {
  ByteData bytes = base._segment.bytes;
  bytes.setFloat32(base._offset + offset, value, Endianness.LITTLE_ENDIAN);
}

void writeFloat64(Pointer base, int offset, double value) {
  ByteData bytes = base._segment.bytes;
  bytes.setFloat64(base._offset + offset, value, Endianness.LITTLE_ENDIAN);
}

abstract class Segment {
  final ByteData bytes;
  Segment(this.bytes);

  int get capacity => bytes.lengthInBytes;
  int get length => bytes.lengthInBytes;

  Segment getSegment(int id);
}

class ReaderSegment extends Segment {
  final MessageReader reader;
  ReaderSegment(ByteData bytes, this.reader) : super(bytes);
  ReaderSegment getSegment(int id) => reader.getSegment(id);
}

class BuilderSegment extends Segment {
  final MessageBuilder _builder;
  final int _id;
  int _used = 0;

  BuilderSegment(ByteData bytes, this._builder, this._id) : super(bytes);
  BuilderSegment getSegment(int id) => throw "Unimplemented";

  int get length => _used;

  int allocateLocally(int size) {
    int result = _used;
    if (result + size > bytes.lengthInBytes) return -1;
    _used += size;
    return result;
  }

  bool hasCapacityForBytes(int size) {
    return (_used + size <= bytes.lengthInBytes);
  }
}


// Internal data structures.

class _StructRoot extends Struct {
  _StructRoot(Segment segment) {
    _segment = segment;
  }

  int get declaredWords => 0;
  int get declaredPointers => 0;
}

abstract class _List extends Pointer with ListMixin {
  int _length = 0;
  int get length => _length;
  int get _declaredElementKind;
  void set length(int value) => throw "Cannot modify.";
  void operator[]=(int index, value) => throw "Cannot modify.";
}

class _ListOfUInt8 extends _List implements List<int> {
  int get _declaredElementKind => 2;
  int operator[](int index) => readUInt8(this, index);
}

class _ListOfUInt64 extends _List implements List<int> {
  int get _declaredElementKind => 5;
  int operator[](int index) => readUInt64(this, index * 8);
}

abstract class _ListBuilder extends Pointer with ListMixin {
  int get _declaredElementKind;
  int get _declaredElementSize;
  void set length(int value) => throw "Cannot modify.";
}

class _ListOfUInt8Builder extends _ListBuilder implements List<int> {
  final int length;
  _ListOfUInt8Builder(this.length);

  int get _declaredElementKind => 2;
  int get _declaredElementSize => 1;

  int operator[](int index) => readUInt8(this, index);
  void operator[]=(int index, int value) => writeUInt8(this, index, value);
}
