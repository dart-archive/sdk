// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.typed_data;

class ByteData extends TypedData {
  ByteData(int length) : super._create(length);

  ByteData.view(ByteBuffer buffer, [int offsetInBytes = 0, int length])
      : super._wrap(buffer, offsetInBytes, length);

  int get elementSizeInBytes => 1;
}
