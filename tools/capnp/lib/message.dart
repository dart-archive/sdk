// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library capnp.message;

import 'dart:typed_data' show ByteData;
import 'internals.dart';

abstract class MessageReader {
  Struct getRoot(Struct struct);
  Segment getSegment(int id);
}

abstract class MessageBuilder {
  StructBuilder initRoot(StructBuilder builder);
  Segment findSegmentForBytes(int bytes);
  ByteData toFlatList();
}
