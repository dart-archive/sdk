// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:ffi';
import "package:expect/expect.dart";

bool isRangeError(e) => e is RangeError;
bool isArgumentError(e) => e is ArgumentError;

main() {
  testLookup();

  testICall();
  testPCall();

  testAllocate(false);
  testAllocate(true);
}

testLookup() {
  Expect.isTrue(Foreign.lookup('qsort') is Foreign);
  Expect.isTrue(Foreign.lookup('qsort', library: null) is Foreign);
  Expect.isTrue(Foreign.lookup('qsort', library: '') is Foreign);

  Expect.throws(
      () => Foreign.lookup('qsort', library: 'does-not-exist'),
      isArgumentError);
  Expect.throws(
      () => Foreign.lookup('does-not-exist'),
      isArgumentError);
  Expect.throws(
      () => Foreign.lookup('does-not-exist', library: null),
      isArgumentError);
}

testICall() {
  Foreign getpid = Foreign.lookup('getpid');
  int pid = getpid.icall$0();
  Expect.isTrue(pid > 0);
  Expect.equals(pid, getpid.icall$0());
}

class ForeignPid extends Foreign {
  static ForeignPid getpid() => _function.pcall$0(new ForeignPid());
  static Foreign _function = Foreign.lookup('getpid');
}

testPCall() {
  ForeignPid pid = ForeignPid.getpid();
  Expect.isTrue(pid.value > 0);
  Expect.equals(pid.value, ForeignPid.getpid().value);
}

testAllocate(bool finalized) {
  int length = 10;
  Foreign memory = finalized
    ? new Foreign.allocatedFinalize(length)
    : new Foreign.allocated(length);
  Expect.isTrue(memory.value != 0);

  Expect.throws(() => memory.getUint8(-100), isRangeError);
  Expect.throws(() => memory.getUint8(-1), isRangeError);
  Expect.throws(() => memory.getUint8(10), isRangeError);
  Expect.throws(() => memory.getUint8(100), isRangeError);

  Expect.throws(() => memory.getUint32(7), isRangeError);

  Expect.throws(() => memory.setUint32(0, 0.0), isArgumentError);
  Expect.throws(() => memory.setUint32(0, new Object()), isArgumentError);
  Expect.throws(() => memory.setFloat32(0, 0), isArgumentError);
  Expect.throws(() => memory.setFloat32(0, new Object()), isArgumentError);

  Expect.equals(0, memory.getUint32(6));

  for (int i = 0; i < length; i++) {
    Expect.equals(0, memory.getUint8(i));
    Expect.equals(i, memory.setUint8(i, i));
  }

  for (int i = 0; i < length; i++) {
    Expect.equals(i, memory.getUint8(i));
  }

  for (int i = 0; i < 8; i++) {
    memory.setUint8(i, 0);
  }

  Expect.equals(0.0, memory.getFloat32(0));
  Expect.equals(0.0, memory.getFloat32(4));
  Expect.equals(0.0, memory.getFloat64(0));

  memory.setFloat32(0, 1.0);
  Expect.equals(1.0, memory.getFloat32(0));

  memory.setFloat64(0, 2.0);
  Expect.equals(2.0, memory.getFloat64(0));

  if (!finalized) {
    memory.free();
    memory.free();  // Free'ing multiple times is okay.
  }
}
