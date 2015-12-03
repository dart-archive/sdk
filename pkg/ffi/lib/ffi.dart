// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Higher level access to the FFI library.
///
/// This package is a set of functions and classes that builds on the lower
/// level FFI library (dart:fletch.ffi).
library ffi;

import 'dart:fletch.ffi';

part 'utf.dart';

final ForeignFunction _strlen = ForeignLibrary.main.lookup('strlen');

/// Converts a C string to a String in the Fletch heap.
/// This call expects a null terminated string. The string will be decoded
/// using a UTF8 decoder.
String cStringToString(ForeignPointer ptr) {
  int length = _strlen.icall$1(ptr);
  return memoryToString(ptr, length);
}

/// Converts a C memory region to a String in the Fletch heap. The string
/// will be decoded using a UTF8 decoder.
String memoryToString(ForeignPointer ptr, int length) {
  var memory = new ForeignMemory.fromAddress(ptr.address, length);
  var encodedString = new List(length);
  for (int i = 0; i < length; ++i) {
    encodedString[i] = memory.getUint8(i);
  }
  return _decodeUtf8(encodedString);
}
