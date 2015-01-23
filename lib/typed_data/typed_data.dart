// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.typed_data;

import 'dart:ffi';

part 'byte_data.dart';
part 'int8_list.dart';

class ByteBuffer {
  final Foreign _foreign;
  ByteBuffer._create(int length)
    : _foreign = new Foreign.allocatedFinalize(length);
  ByteBuffer._from(this._foreign);

  int get lengthInBytes => _foreign.length;
}

abstract class TypedData {
  final Foreign _foreign;
  final int offsetInBytes;
  final int lengthInBytes;

  TypedData._create(int sizeInBytes)
    : _foreign = new Foreign.allocatedFinalize(sizeInBytes),
      offsetInBytes = 0,
      lengthInBytes = sizeInBytes;

  TypedData._wrap(ByteBuffer other, int offsetInBytes, int lengthInBytes)
    : _foreign = other._foreign,
      this.offsetInBytes = offsetInBytes,
      this.lengthInBytes = (lengthInBytes == null)
          ? other.lengthInBytes - offsetInBytes
          : lengthInBytes;

  ByteBuffer get buffer => new ByteBuffer._from(_foreign);

  int get elementSizeInBytes;
}
