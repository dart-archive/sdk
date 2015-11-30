// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch.ffi';
import "package:expect/expect.dart";
import 'package:ffi/ffi.dart';

main() {
  var memory = new ForeignMemory.allocated(100);
  var ptr = new ForeignPointer(memory.address);
  memory.setUint8(0, 65);
  memory.setUint8(1, 0);
  Expect.equals('A',  cStringToString(ptr));
  Expect.equals('', memoryToString(memory, 0));
  Expect.equals('A', memoryToString(memory, 1));
  memory.setUint8(1, 42);
  Expect.equals('A', memoryToString(memory, 1));
  memory.setUint8(0, 0xc3);
  memory.setUint8(1, 0x98);
  memory.setUint8(2, 0);
  Expect.equals('Ø', cStringToString(ptr));
  memory.free();

  var libPath = ForeignLibrary.bundleLibraryName('ffi_test_library');
  ForeignLibrary fl = new ForeignLibrary.fromName(libPath);
  var memstring = fl.lookup('memstring');
  var foreignPointer = memstring.pcall$0();
  Expect.equals('dart', cStringToString(foreignPointer));
  memory = new ForeignMemory.fromAddress(foreignPointer.address, 5);
  memory.free();
}
