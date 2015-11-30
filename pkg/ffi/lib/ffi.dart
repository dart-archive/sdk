// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library ffi;

import 'dart:fletch.ffi';

part 'utf.dart';

final ForeignFunction _strlen = ForeignLibrary.main.lookup('strlen');

/// Converts a c string to a String in the fletch heap.
String cStringToString(ForeignPointer ptr) {
  int length = _strlen.icall$1(ptr);
  return memoryToString(ptr, length);
}

/// Converts a c memory region to a String in the fletch hea.p
String memoryToString(ForeignPointer ptr, int length) {
  var memory = new ForeignMemory.fromAddress(ptr.address, length);
  var encodedString = new List(length);
  for (int i = 0; i < length; ++i) {
    encodedString[i] = memory.getUint8(i);
  }
  return _decodeUtf8(encodedString);
}
