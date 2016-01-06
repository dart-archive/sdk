// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch.ffi';
import 'dart:typed_data';
import "package:expect/expect.dart";
import 'package:ffi/ffi.dart';

main() {
  testStringFunctions();
  testCircularBuffer();
}

testList(int size) {
  Uint8List data = new Uint8List(size);
  for (int i = 0; i < size; i++) data[i] = i;
  return data;
}

testCircularBuffer() {
  int size = 128;
  // A few different sizes that adds up to size;
  var sizes = [1, 1, 2, 4, 8, 16, 32, 64];
  Expect.equals(size, sizes.reduce((value, element) => value + element));
  CircularByteBuffer buffer = new CircularByteBuffer(size);
  for (int j = 1; j <= size; j++) {
    Uint8List data = testList(j);
    Expect.isFalse(buffer.isFull);
    Expect.isTrue(buffer.isEmpty);
    Expect.equals(buffer.write(data.buffer), j);
    Expect.isFalse(buffer.isEmpty);
    if (j == size) Expect.isTrue(buffer.isFull);
    Expect.equals(buffer.available, j);
    Expect.equals(buffer.freeSpace, size - j);
    Uint8List back = new Uint8List(j);
    Expect.equals(buffer.read(back.buffer), j);
    for (int i = 0; i < j; i++) Expect.equals(back[i], i);
  }

  Expect.isTrue(buffer.isEmpty);
  int total = 0;
  for (int j in sizes) {
    total += j;
    Uint8List data = testList(j);
    Expect.equals(buffer.write(data.buffer), j);
    Expect.isFalse(buffer.isEmpty);
    Expect.equals(buffer.available, total);
  }
  Expect.equals(total, size);
  Expect.isTrue(buffer.isFull);

  for (int j in sizes) {
    Expect.isFalse(buffer.isEmpty);
    total -= j;
    Uint8List back = new Uint8List(j);
    Expect.equals(buffer.read(back.buffer), j);;
    for (int i = 0; i < j; i++) Expect.equals(back[i], i);
    Expect.equals(buffer.available, total);
  }
  Expect.isTrue(buffer.isEmpty);
  Expect.equals(buffer.freeSpace, size);

  Uint8List data = testList(size);
  int index = 0;
  for (int j in sizes) {
    Expect.equals(buffer.write(data.buffer, index, j), j);
    index += j;
  }
  Expect.equals(index, size);
  Expect.isTrue(buffer.isFull);
  Expect.equals(buffer.available, size);
  Expect.equals(buffer.freeSpace, 0);

  Uint8List back = new Uint8List(size);
  index = 0;
  for (int j in sizes) {
    Expect.equals(buffer.read(back.buffer, index, j), j);
    index += j;
  }
  Expect.listEquals(data, back);
  Expect.equals(index, size);
  Expect.isFalse(buffer.isFull);
  Expect.equals(buffer.available, 0);
  Expect.equals(buffer.freeSpace, size);

  Uint8List data_smaller = testList(size - 2);
  Expect.equals(buffer.write(data_smaller.buffer), size - 2);
  Expect.equals(buffer.write(data_smaller.buffer), 2);
  for (int i = 0; i < size - 2; i++) data_smaller[i] = 0;
  Expect.equals(buffer.read(data_smaller.buffer), size - 2);
  for (int i = 0; i < size - 2; i++) Expect.equals(data_smaller[i], i);
  for (int i = 0; i < size - 2; i++) data_smaller[i] = 0;
  Expect.equals(buffer.read(data_smaller.buffer), 2);
  Expect.equals(data_smaller[0], 0);
  Expect.equals(data_smaller[1], 1);

  var libPath = ForeignLibrary.bundleLibraryName('ffi_test_library');
  ForeignLibrary fl = new ForeignLibrary.fromName(libPath);
  var bufferRead = fl.lookup('bufferRead');
  buffer.write(data.buffer);
  for (int i = 0; i < size; i++) {
    Expect.isFalse(buffer.isEmpty);
    Expect.equals(buffer.available, size - i);
    var value = bufferRead.icall$2(buffer.foreign, size);
    Expect.equals(value, i);
  }
  Expect.isTrue(buffer.isEmpty);

  var bufferWrite = fl.lookup('bufferWrite');
  for (int i = 0; i < size; i++) {
    Expect.equals(buffer.available, i);
    var value = bufferWrite.icall$3(buffer.foreign, size, i);
    Expect.equals(i, value);
  }
  Expect.equals(buffer.available, size);
  Expect.isTrue(buffer.isFull);
  Expect.equals(buffer.read(back.buffer), size);
  Expect.listEquals(back, data);
  
}

testStringFunctions() {
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
