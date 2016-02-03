// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino._system' as dartino;
import 'dart:dartino._system' show patch;
import 'dart:collection';
import 'dart:dartino.ffi';

@patch class Uint8List {
  @patch factory Uint8List(int length) {
    return new _Uint8List(length);
  }

  @patch factory Uint8List.fromList(List<int> elements) {
    return new _Uint8List.fromList(elements);
  }
}

class _Uint8List extends _TypedList<int> implements Uint8List {

  _Uint8List(int length) : super._create(length);

  _Uint8List.fromList(List<int> elements)
      : super._create(elements.length) {
    this.setRange(0, elements.length, elements);
  }

  _Uint8List._view(ByteBuffer buffer, int offsetInBytes, int length)
      : super._wrap(buffer, offsetInBytes, length);

  int operator[](int index) => _foreign.getUint8(offsetInBytes + index);
  void operator[]=(int index, int value) {
    _foreign.setUint8(offsetInBytes + index, value);
  }

  int get length => lengthInBytes;
  int get elementSizeInBytes => 1;
}

@patch class Uint8ClampedList {
  @patch factory Uint8ClampedList(int length) {
    return new _Uint8ClampedList(length);
  }

  @patch factory Uint8ClampedList.fromList(List<int> elements) {
    return new _Uint8ClampedList.fromList(elements);
  }
}

class _Uint8ClampedList extends _TypedList<int> implements Uint8ClampedList {

  _Uint8ClampedList(int length) : super._create(length);

  _Uint8ClampedList.fromList(List<int> elements)
      : super._create(elements.length) {
    this.setRange(0, elements.length, elements);
  }

  _Uint8ClampedList._view(ByteBuffer buffer, int offsetInBytes, int length)
      : super._wrap(buffer, offsetInBytes, length);

  int operator[](int index) => _foreign.getUint8(offsetInBytes + index);
  void operator[]=(int index, int value) {
    if (value < 0) value = 0;
    else if (value > 0xFF) value = 0xFF;
    _foreign.setUint8(offsetInBytes + index, value);
  }

  int get length => lengthInBytes;
  int get elementSizeInBytes => 1;
}

@patch class Int8List {
  @patch factory Int8List(int length) {
    return new _Int8List(length);
  }

  @patch factory Int8List.fromList(List<int> elements) {
    return new _Int8List.fromList(elements);
  }
}

class _Int8List extends _TypedList<int> implements Int8List {

  _Int8List(int length) : super._create(length);

  _Int8List.fromList(List<int> elements)
      : super._create(elements.length) {
    this.setRange(0, elements.length, elements);
  }

  _Int8List._view(ByteBuffer buffer, int offsetInBytes, int length)
      : super._wrap(buffer, offsetInBytes, length);

  int operator[](int index) => _foreign.getInt8(offsetInBytes + index);
  void operator[]=(int index, int value) {
    _foreign.setInt8(offsetInBytes + index, value);
  }

  int get length => lengthInBytes;
  int get elementSizeInBytes => 1;
}

@patch class Uint16List {
  @patch factory Uint16List(int length) {
    return new _Uint16List(length);
  }

  @patch factory Uint16List.fromList(List<int> elements) {
    return new _Uint16List.fromList(elements);
  }
}

class _Uint16List extends _TypedList<int> implements Uint16List {
  static const int _elementSizeInBytes = 2;

  _Uint16List(int length)
       : super._create(length * _elementSizeInBytes);

  _Uint16List.fromList(List<int> elements)
      : super._create(elements.length * _elementSizeInBytes) {
    this.setRange(0, elements.length, elements);
  }

  _Uint16List._view(ByteBuffer buffer, int offsetInBytes, int length)
      : super._wrap(buffer, offsetInBytes,
          length == null ? null : length * _elementSizeInBytes);

  int operator[](int index) =>
      _foreign.getUint16(offsetInBytes + (index * elementSizeInBytes));
  void operator[]=(int index, int value) {
    _foreign.setUint16(offsetInBytes + (index * elementSizeInBytes), value);
  }

  // Number of elements in the list.
  int get length => lengthInBytes ~/ _elementSizeInBytes;
  int get elementSizeInBytes => _elementSizeInBytes;
}

@patch class Int16List {
  @patch factory Int16List(int length) {
    return new _Int16List(length);
  }

  @patch factory Int16List.fromList(List<int> elements) {
    return new _Int16List.fromList(elements);
  }
}

class _Int16List extends _TypedList<int> implements Int16List {
  static const int _elementSizeInBytes = 2;

  _Int16List(int length)
       : super._create(length * _elementSizeInBytes);

  _Int16List.fromList(List<int> elements)
      : super._create(elements.length * _elementSizeInBytes) {
    this.setRange(0, elements.length, elements);
  }

  _Int16List._view(ByteBuffer buffer, int offsetInBytes, int length)
      : super._wrap(buffer, offsetInBytes,
          length == null ? null : length * _elementSizeInBytes);

  int operator[](int index) =>
      _foreign.getInt16(offsetInBytes + (index * elementSizeInBytes));
  void operator[]=(int index, int value) {
    _foreign.setInt16(offsetInBytes + (index * elementSizeInBytes), value);
  }

  // Number of elements in the list.
  int get length => lengthInBytes ~/ _elementSizeInBytes;
  int get elementSizeInBytes => _elementSizeInBytes;
}

@patch class Uint32List {
  @patch factory Uint32List(int length) {
    return new _Uint32List(length);
  }

  @patch factory Uint32List.fromList(List<int> elements) {
    return new _Uint32List.fromList(elements);
  }
}

class _Uint32List extends _TypedList<int> implements Uint32List {
  static const int _elementSizeInBytes = 4;

  _Uint32List(int length)
      : super._create(length * _elementSizeInBytes);

  _Uint32List.fromList(List<int> elements)
      : super._create(elements.length * _elementSizeInBytes) {
    this.setRange(0, elements.length, elements);
  }

  _Uint32List._view(ByteBuffer buffer, int offsetInBytes, int length)
      : super._wrap(buffer, offsetInBytes,
           length == null ? null : length * _elementSizeInBytes);

  int operator[](int index) =>
      _foreign.getUint32(offsetInBytes + (index * elementSizeInBytes));
  void operator[]=(int index, int value) {
    _foreign.setUint32(offsetInBytes + (index * elementSizeInBytes), value);
  }

  // Number of elements in the list.
  int get length => lengthInBytes ~/ _elementSizeInBytes;
  int get elementSizeInBytes => _elementSizeInBytes;
}

@patch class Int32List {
  @patch factory Int32List(int length) {
    return new _Int32List(length);
  }

  @patch factory Int32List.fromList(List<int> elements) {
    return new _Int32List.fromList(elements);
  }
}

class _Int32List extends _TypedList<int> implements Int32List {
  static const int _elementSizeInBytes = 4;

  _Int32List(int length)
      : super._create(length * _elementSizeInBytes);

  _Int32List.fromList(List<int> elements)
      : super._create(elements.length * _elementSizeInBytes) {
    this.setRange(0, elements.length, elements);
  }

  _Int32List._view(ByteBuffer buffer, int offsetInBytes, int length)
      : super._wrap(buffer, offsetInBytes,
           length == null ? null : length * _elementSizeInBytes);

  int operator[](int index) =>
      _foreign.getInt32(offsetInBytes + (index * elementSizeInBytes));
  void operator[]=(int index, int value) {
    _foreign.setInt32(offsetInBytes + (index * elementSizeInBytes), value);
  }

  // Number of elements in the list.
  int get length => lengthInBytes ~/ _elementSizeInBytes;
  int get elementSizeInBytes => _elementSizeInBytes;
}

@patch class Uint64List {
  @patch factory Uint64List(int length) {
    return new _Uint64List(length);
  }

  @patch factory Uint64List.fromList(List<int> elements) {
    return new _Uint64List.fromList(elements);
  }
}

class _Uint64List extends _TypedList<int> implements Uint64List {
  static const int _elementSizeInBytes = 8;

  _Uint64List(int length)
      : super._create(length * _elementSizeInBytes);

  _Uint64List.fromList(List<int> elements)
      : super._create(elements.length * _elementSizeInBytes) {
    this.setRange(0, elements.length, elements);
  }

  _Uint64List._view(ByteBuffer buffer, int offsetInBytes, int length)
      : super._wrap(buffer, offsetInBytes,
           length == null ? null : length * _elementSizeInBytes);

  int operator[](int index) =>
      _foreign.getUint64(offsetInBytes + (index * elementSizeInBytes));
  void operator[]=(int index, int value) {
    _foreign.setUint64(offsetInBytes + (index * elementSizeInBytes), value);
  }

  // Number of elements in the list.
  int get length => lengthInBytes ~/ _elementSizeInBytes;
  int get elementSizeInBytes => _elementSizeInBytes;
}

@patch class Int64List {
  @patch factory Int64List(int length) {
    return new _Int64List(length);
  }

  @patch factory Int64List.fromList(List<int> elements) {
    return new _Int64List.fromList(elements);
  }
}

class _Int64List extends _TypedList<int> implements Int64List {
  static const int _elementSizeInBytes = 8;

  _Int64List(int length)
      : super._create(length * _elementSizeInBytes);

  _Int64List.fromList(List<int> elements)
      : super._create(elements.length * _elementSizeInBytes) {
    this.setRange(0, elements.length, elements);
  }

  _Int64List._view(ByteBuffer buffer, int offsetInBytes, int length)
      : super._wrap(buffer, offsetInBytes,
           length == null ? null : length * _elementSizeInBytes);

  int operator[](int index) =>
      _foreign.getInt64(offsetInBytes + (index * elementSizeInBytes));
  void operator[]=(int index, int value) {
    _foreign.setInt64(offsetInBytes + (index * elementSizeInBytes), value);
  }

  // Number of elements in the list.
  int get length => lengthInBytes ~/ _elementSizeInBytes;
  int get elementSizeInBytes => _elementSizeInBytes;
}

@patch class Float32List {
  @patch factory Float32List(int length) {
    return new _Float32List(length);
  }

  @patch factory Float32List.fromList(List<double> elements) {
    return new _Float32List.fromList(elements);
  }
}

class _Float32List extends _TypedList<double> implements Float32List {
  static const int _elementSizeInBytes = 4;

  _Float32List(int length)
      : super._create(length * _elementSizeInBytes);

  _Float32List.fromList(List<double> elements)
      : super._create(elements.length * _elementSizeInBytes) {
    this.setRange(0, elements.length, elements);
  }

  _Float32List._view(ByteBuffer buffer, int offsetInBytes, int length)
      : super._wrap(buffer, offsetInBytes,
           length == null ? null : length * _elementSizeInBytes);

  double operator[](int index) =>
      _foreign.getFloat32(offsetInBytes + (index * elementSizeInBytes));
  void operator[]=(int index, double value) {
    _foreign.setFloat32(offsetInBytes + (index * elementSizeInBytes), value);
  }

  // Number of elements in the list.
  int get length => lengthInBytes ~/ _elementSizeInBytes;
  int get elementSizeInBytes => _elementSizeInBytes;
}

@patch class Float64List {
  @patch factory Float64List(int length) {
    return new _Float64List(length);
  }

  @patch factory Float64List.fromList(List<double> elements) {
    return new _Float64List.fromList(elements);
  }
}

class _Float64List extends _TypedList<double> implements Float64List {
  static const int _elementSizeInBytes = 8;

  _Float64List(int length)
      : super._create(length * _elementSizeInBytes);

  _Float64List.fromList(List<double> elements)
      : super._create(elements.length * _elementSizeInBytes) {
    this.setRange(0, elements.length, elements);
  }

  _Float64List._view(ByteBuffer buffer, int offsetInBytes, int length)
      : super._wrap(buffer, offsetInBytes,
           length == null ? null : length * _elementSizeInBytes);

  double operator[](int index) =>
      _foreign.getFloat64(offsetInBytes + (index * elementSizeInBytes));
  void operator[]=(int index, double value) {
    _foreign.setFloat64(offsetInBytes + (index * elementSizeInBytes), value);
  }

  // Number of elements in the list.
  int get length => lengthInBytes ~/ _elementSizeInBytes;
  int get elementSizeInBytes => _elementSizeInBytes;
}

abstract class _TypedData {
  final ForeignMemory _foreign;
  final int offsetInBytes;
  final int lengthInBytes;

  _TypedData._create(int sizeInBytes)
    : _foreign = new ForeignMemory.allocatedFinalized(sizeInBytes),
      offsetInBytes = 0,
      lengthInBytes = sizeInBytes;

  _TypedData._wrap(_ByteBuffer other, int offsetInBytes, int lengthInBytes)
    : _foreign = other.getForeign(),
      this.offsetInBytes = offsetInBytes,
      this.lengthInBytes = (lengthInBytes == null)
          ? other.lengthInBytes - offsetInBytes
          : lengthInBytes;

  ByteBuffer get buffer => new _ByteBuffer._from(_foreign);

  int get elementSizeInBytes;
}

abstract class _TypedList<E> extends _TypedData with ListMixin<E> {
  _TypedList._create(int sizeInBytes) : super._create(sizeInBytes);

  _TypedList._wrap(_ByteBuffer other, int offsetInBytes, int lengthInBytes)
      : super._wrap(other, offsetInBytes, lengthInBytes);

  int get length;
  void set length(int value) {
    throw new UnsupportedError("A typed data list cannot change length");
  }

  void setRange(int start, int end, Iterable source, [int skipCount = 0]) {
    if (0 > start || start > end || end > length) {
      RangeError.checkValidRange(start, end, length);  // Always throws.
      assert(false);
    }
    if (skipCount < 0) {
      throw new ArgumentError(skipCount);
    }

    final count = end - start;
    if (count == 0) return;
    if ((source.length - skipCount) < count) {
      throw new StateError('Not enough elements in source');
    }

    if (!(source is List)) {
      // Since the source is not a list there cannot be any overlap with this
      // list's buffer. Just copy from the beginning using an iterator.
      Iterator it = source.iterator;
      while (skipCount > 0) {
        if (!it.moveNext()) return;
        skipCount--;
      }
      for (int i = start; i < end; i++) {
        if (!it.moveNext()) return;
        this[i] = it.current;
      }
      return;
    }

    // Check for the buffers being the same and if they overlap. If so determine
    // whether an intermediate buffer is needed or which end of the source to
    // start copying from.
    bool startFromEnd = false;
    if (source is _TypedList && source.buffer == this.buffer) {
      int dstStartInBytes =
          this.offsetInBytes + start * this.elementSizeInBytes;
      int dstEndInBytes = dstStartInBytes + count * this.elementSizeInBytes;
      int srcStartInBytes =
          source.offsetInBytes + skipCount * source.elementSizeInBytes;
      int srcEndInBytes = srcStartInBytes + count * source.elementSizeInBytes;
      // NOTE: it is IMO easier to convince yourself the negated condition
      // implies no overlap, than the actual implying an overlap.
      if (dstEndInBytes > srcStartInBytes && dstStartInBytes < srcEndInBytes) {
        // Check if the element sizes are identical. If not the destination
        // could overtake the source independent of which direction the copy is
        // done. In that case we use an intermediate buffer to ensure no
        // premature source corruption.
        if (source.elementSizeInBytes == this.elementSizeInBytes) {
          startFromEnd = srcStartInBytes < dstStartInBytes;
        } else {
          final temp = new List(count);
          for (var i = 0; i < count; i++) {
            temp[i] = source[skipCount + i];
          }
          for (int i = 0; i < count; ++i) {
            this[start + i] = temp[i];
          }
          return;
        }
      }
    }
    if (startFromEnd) {
      for (int i = count - 1; i >= 0; --i) {
        this[start + i] = (source as List)[skipCount + i];
      }
    } else {
      for (int i = 0; i < count; ++i) {
        this[start + i] = (source as List)[skipCount + i];
      }
    }
  }

  bool remove(Object element) => throw new UnsupportedError(
      "Cannot remove elements from a typed data list");
  E removeAt(int index) => throw new UnsupportedError(
      "Cannot remove elements from a typed data list");
  E removeLast() => throw new UnsupportedError(
      "Cannot remove elements from a typed data list");
  void removeRange(int start, int end) => throw new UnsupportedError(
      "Cannot remove elements from a typed data list");
  void removeWhere(bool test(E element)) => throw new UnsupportedError(
      "Cannot remove elements from a typed data list");
  void replaceRange(int start, int end, Iterable<E> newContents) =>
      throw new UnsupportedError(
          "Cannot remove elements from a typed data list");
  void retainWhere(bool test(E element)) => throw new UnsupportedError(
      "Cannot modify the size of a typed data list");
}

@patch class ByteData {
  @patch factory ByteData(int length) {
    return new _ByteData(length);
  }
}

class _ByteData extends _TypedData implements ByteData {
  _ByteData(int length) : super._create(length);

  _ByteData._view(ByteBuffer buffer, int offsetInBytes, int length)
      : super._wrap(buffer, offsetInBytes, length);

  int get elementSizeInBytes => 1;

  int getInt8(int byteOffset) => _foreign.getInt8(offsetInBytes + byteOffset);

  void setInt8(int byteOffset, int value) {
    _foreign.setInt8(offsetInBytes + byteOffset, value);
  }

  int getUint8(int byteOffset) => _foreign.getUint8(offsetInBytes + byteOffset);

  void setUint8(int byteOffset, int value) {
    _foreign.setUint8(offsetInBytes + byteOffset, value);
  }

  int getInt16(int byteOffset, [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    return _foreign.getInt16(offsetInBytes + byteOffset);
  }


  void setInt16(int byteOffset,
                int value,
                [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    _foreign.setInt16(offsetInBytes + byteOffset, value);
  }

  int getUint16(int byteOffset, [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    return _foreign.getUint16(offsetInBytes + byteOffset);
  }


  void setUint16(int byteOffset,
                 int value,
                 [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    _foreign.setUint16(offsetInBytes + byteOffset, value);
  }

  int getInt32(int byteOffset, [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    return _foreign.getInt32(offsetInBytes + byteOffset);
  }


  void setInt32(int byteOffset,
                int value,
                [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    _foreign.setInt32(offsetInBytes + byteOffset, value);
  }

  int getUint32(int byteOffset, [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    return _foreign.getUint32(offsetInBytes + byteOffset);
  }


  void setUint32(int byteOffset,
                 int value,
                 [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    _foreign.setUint32(offsetInBytes + byteOffset, value);
  }

  int getInt64(int byteOffset, [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    return _foreign.getInt64(offsetInBytes + byteOffset);
  }


  void setInt64(int byteOffset,
                int value,
                [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    _foreign.setInt64(offsetInBytes + byteOffset, value);
  }

  int getUint64(int byteOffset, [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    return _foreign.getUint64(offsetInBytes + byteOffset);
  }


  void setUint64(int byteOffset,
                 int value,
                 [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    _foreign.setUint64(offsetInBytes + byteOffset, value);
  }

  double getFloat32(int byteOffset,
                    [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    return _foreign.getFloat32(offsetInBytes + byteOffset);
  }


  void setFloat32(int byteOffset,
                  double value,
                  [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    _foreign.setFloat32(offsetInBytes + byteOffset, value);
  }

  double getFloat64(int byteOffset,
                    [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    return _foreign.getFloat64(offsetInBytes + byteOffset);
  }

  void setFloat64(int byteOffset,
                  double value,
                  [Endianness endian = Endianness.BIG_ENDIAN]) {
    if (endian != Endianness.HOST_ENDIAN) {
      throw new UnimplementedError("Only host endianness is supported");
    }
    _foreign.setFloat64(offsetInBytes + byteOffset, value);
  }
}

class _ByteBuffer implements ByteBuffer {
  final ForeignMemory _foreign;

  _ByteBuffer._from(this._foreign);

  ForeignMemory getForeign() => _foreign;

  int get lengthInBytes => _foreign.length;

  int get hashCode => _foreign.hashCode;

  bool operator==(ByteBuffer other) => this.hashCode == other.hashCode;

  Uint8List asUint8List([int offsetInBytes = 0, int length]) {
    return new _Uint8List._view(this, offsetInBytes, length);
  }

  Int8List asInt8List([offsetInBytes = 0, length]) {
    return new _Int8List._view(this, offsetInBytes, length);
  }

  Uint8ClampedList asUint8ClampedList([offsetInBytes = 0, length]) {
    return new _Uint8ClampedList._view(this, offsetInBytes, length);
  }

  Uint16List asUint16List([offsetInBytes = 0, length]) {
    return new _Uint16List._view(this, offsetInBytes, length);
  }

  Int16List asInt16List([offsetInBytes = 0, length]) {
    return new _Int16List._view(this, offsetInBytes, length);
  }

  Uint32List asUint32List([offsetInBytes = 0, length]) {
    return new _Uint32List._view(this, offsetInBytes, length);
  }

  Int32List asInt32List([offsetInBytes = 0, length]) {
    return new _Int32List._view(this, offsetInBytes, length);
  }

  Uint64List asUint64List([offsetInBytes = 0, length]) {
    return new _Uint64List._view(this, offsetInBytes, length);
  }

  Int64List asInt64List([offsetInBytes = 0, length]) {
    return new _Int64List._view(this, offsetInBytes, length);
  }

  asInt32x4List([offsetInBytes = 0, length]) {
    throw "asInt32x4List([offsetInBytes, length]) isn't implemented";
  }

  Float32List asFloat32List([offsetInBytes = 0, length]) {
    return new _Float32List._view(this, offsetInBytes, length);
  }

  Float64List asFloat64List([offsetInBytes = 0, length]) {
    return new _Float64List._view(this, offsetInBytes, length);
  }

  asFloat32x4List([offsetInBytes = 0, length]) {
    throw "asFloat32x4List([offsetInBytes, length]) isn't implemented";
  }

  asFloat64x2List([offsetInBytes = 0, length]) {
    throw "asFloat64x2List([offsetInBytes, length]) isn't implemented";
  }

  ByteData asByteData([offsetInBytes = 0, length]) {
    return new _ByteData._view(this, offsetInBytes, length);
  }
}
