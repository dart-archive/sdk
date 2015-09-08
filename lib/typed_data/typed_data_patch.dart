// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:_fletch_system' as fletch;
import 'dart:collection';
import 'dart:fletch.ffi';

const patch = "patch";

@patch class Uint8List {
  @patch factory Uint8List(int length) {
    return new _Uint8List(length);
  }

  @patch factory Uint8List.fromList(List<int> elements) {
    return new _Uint8List.fromList(elements);
  }
}

class _Uint8List extends _TypedList implements Uint8List {

  _Uint8List(int length) : super._create(length);

  _Uint8List._fromList(List<int> elements)
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

@patch class Uint16List {
  @patch factory Uint16List(int length) {
    return new _Uint16List(length);
  }

  @patch factory Uint16List.fromList(List<int> elements) {
    return new _Uint16List.fromList(elements);
  }
}

class _Uint16List extends _TypedList implements Uint16List {
  static const int _elementSizeInBytes = 2;

  _Uint16List(int length)
       : super._create(length * _elementSizeInBytes);

  _Uint16List._fromList(List<int> elements)
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

@patch class Uint32List {
  @patch factory Uint32List(int length) {
    return new _Uint32List(length);
  }

  @patch factory Uint32List.fromList(List<int> elements) {
    return new _Uint32List.fromList(elements);
  }
}

class _Uint32List extends _TypedList implements Uint32List {
  static const int _elementSizeInBytes = 4;

  _Uint32List(int length)
      : super._create(length * _elementSizeInBytes);

  _Uint32List._fromList(List<int> elements)
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

abstract class _TypedList extends _TypedData with ListMixin<int> {
  _TypedList._create(int sizeInBytes) : super._create(sizeInBytes);

  _TypedList._wrap(_ByteBuffer other, int offsetInBytes, int lengthInBytes)
      : super._wrap(other, offsetInBytes, lengthInBytes);

  int get length;
  void set length(int value) {
    throw new UnsupportedError("A typed data list cannot change length");
  }

  void setRange(int start, int end, Iterable iterable, [int skipCount = 0]) {
    int length = this.length;
    if (start < 0 || start > length) {
      throw new RangeError.range(start, 0, length);
    }
    if (end < start || end > length) {
      throw new RangeError.range(end, start, length);
    }
    if ((end - start) == 0) return;
    if (iterable is List) {
      int count = end - start;
      for (int i = 0; i < count; i++) {
        this[start + i] = iterable[skipCount + i];
      }
    } else {
      Iterator it = iterable.iterator;
      while (skipCount > 0) {
        if (!it.moveNext()) return;
        skipCount--;
      }
      for (int i = start; i < end; i++) {
        if (!it.moveNext()) return;
        this[i] = it.current;
      }
    }
  }
}

class _ByteBuffer implements ByteBuffer {
  final ForeignMemory _foreign;

  _ByteBuffer._from(this._foreign);

  ForeignMemory getForeign() => _foreign;

  int get lengthInBytes => _foreign.length;

  Uint8List asUint8List([int offsetInBytes = 0, int length]) {
    return new _Uint8List._view(this, offsetInBytes, length);
  }

  asInt8List([offsetInBytes, length]) {
    throw "asInt8List([offsetInBytes, length]) isn't implemented";
  }

  asUint8ClampedList([offsetInBytes, length]) {
    throw "asUint8ClampedList([offsetInBytes, length]) isn't implemented";
  }

  Uint16List asUint16List([offsetInBytes = 0, length]) {
    return new _Uint16List._view(this, offsetInBytes, length);
  }

  asInt16List([offsetInBytes, length]) {
    throw "asInt16List([offsetInBytes, length]) isn't implemented";
  }

  Uint32List asUint32List([offsetInBytes = 0, length]) {
    return new _Uint32List._view(this, offsetInBytes, length);
  }

  asInt32List([offsetInBytes, length]) {
    throw "asInt32List([offsetInBytes, length]) isn't implemented";
  }

  asUint64List([offsetInBytes, length]) {
    throw "asUint64List([offsetInBytes, length]) isn't implemented";
  }

  asInt64List([offsetInBytes, length]) {
    throw "asInt64List([offsetInBytes, length]) isn't implemented";
  }

  asInt32x4List([offsetInBytes, length]) {
    throw "asInt32x4List([offsetInBytes, length]) isn't implemented";
  }

  asFloat32List([offsetInBytes, length]) {
    throw "asFloat32List([offsetInBytes, length]) isn't implemented";
  }

  asFloat64List([offsetInBytes, length]) {
    throw "asFloat64List([offsetInBytes, length]) isn't implemented";
  }

  asFloat32x4List([offsetInBytes, length]) {
    throw "asFloat32x4List([offsetInBytes, length]) isn't implemented";
  }

  asFloat64x2List([offsetInBytes, length]) {
    throw "asFloat64x2List([offsetInBytes, length]) isn't implemented";
  }

  asByteData([offsetInBytes, length]) {
    throw "asByteData([offsetInBytes, length]) isn't implemented";
  }
}
