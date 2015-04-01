// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:_fletch_system' as fletch;
import 'dart:collection';
import 'dart:ffi';

const patch = "patch";

@patch class Uint8List {
  @patch factory Uint8List(int length) {
    return new _Uint8List(length);
  }
}

// TODO(ajohnsen): Mixin List<int> members.
class _Uint8List extends _TypedData implements Uint8List {

  _Uint8List(int length) : super._create(length);

  _Uint8List.view(ByteBuffer buffer, [int offsetInBytes = 0, int length])
      : super._wrap(buffer, offsetInBytes, length);

  int operator[](int index) => _foreign.getUint8(offsetInBytes + index);
  void operator[]=(int index, int value) {
    _foreign.setUint8(offsetInBytes + index, value);
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
      // TODO(ajohnsen): Use memcpy for Uint8List
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

  int get length => lengthInBytes;
  int get elementSizeInBytes => 1;
}

abstract class _TypedData {
  final Foreign _foreign;
  final int offsetInBytes;
  final int lengthInBytes;

  _TypedData._create(int sizeInBytes)
    : _foreign = new Foreign.allocatedFinalize(sizeInBytes),
      offsetInBytes = 0,
      lengthInBytes = sizeInBytes;

  _TypedData._wrap(ByteBuffer other, int offsetInBytes, int lengthInBytes)
    : _foreign = other._foreign,
      this.offsetInBytes = offsetInBytes,
      this.lengthInBytes = (lengthInBytes == null)
          ? other.lengthInBytes - offsetInBytes
          : lengthInBytes;

  ByteBuffer get buffer => new ByteBuffer._from(_foreign);

  int get elementSizeInBytes;
}
