// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.typed_data;

// TODO(ajohnsen): Mixin List<int> members.
class Uint8List extends TypedData implements List<int> {

  Uint8List(int length) : super._create(length);

  Uint8List.view(ByteBuffer buffer, [int offsetInBytes = 0, int length])
      : super._wrap(buffer, offsetInBytes, length);

  int operator[](int index) => _foreign.getUint8(offsetInBytes + index);
  void operator[]=(int index, int value) {
    _foreign.setUint8(offsetInBytes + index, value);
  }

  int get length => lengthInBytes;
  int get elementSizeInBytes => 1;
}
