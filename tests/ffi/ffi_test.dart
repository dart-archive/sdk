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
  int size = 10;
  Foreign memory = finalized
    ? new Foreign.allocatedFinalize(size)
    : new Foreign.allocated(size);
  Expect.isTrue(memory.value != 0);

  Expect.throws(() => memory.getUint8(-100), isRangeError);
  Expect.throws(() => memory.getUint8(-1), isRangeError);
  Expect.throws(() => memory.getUint8(10), isRangeError);
  Expect.throws(() => memory.getUint8(100), isRangeError);

  Expect.throws(() => memory.getUint32(7), isRangeError);

  Expect.equals(0, memory.getUint32(6));

  for (int i = 0; i < size; i++) {
    Expect.equals(0, memory.getUint8(i));
    Expect.equals(i, memory.setUint8(i, i));
  }

  for (int i = 0; i < size; i++) {
    Expect.equals(i, memory.getUint8(i));
  }

  if (!finalized) {
    memory.free();
    memory.free();  // Free'ing multiple times is okay.
  }
}
