// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino.ffi';
import 'dart:dartino';
import "package:expect/expect.dart";
import "package:isolate/isolate.dart";

bool isRangeError(e) => e is RangeError;
bool isArgumentError(e) => e is ArgumentError;

var freeFunc = ForeignLibrary.main.lookup('free');

main() {
  // Not finalized, not immutable.
  testAllocate(false, false);
  // Finalized, not immutable.
  testAllocate(true, false);
  // Not finalized, immutable.
  testAllocate(false, true);
  // Finalized, immutable.
  testAllocate(true, true);

  testVAndICall();
  testFailingLibraryLookups();
  testDefaultLibraryLookups();
  testPCallAndMemory(true);
  testPCallAndMemory(false);
  testStruct();

  testImmutablePassing(false);
  testImmutablePassing(true);

  testExternalFinalizer();
}

checkOutOfBoundsThrows(function) {
  Expect.throws(function, (e) => e is RangeError);
}

testPCallAndMemory(bool immutable) {
  fromPointer(ForeignPointer pointer, int length) {
    if (immutable) {
      return new ImmutableForeignMemory.fromAddress(pointer.address, length);
    }
    return new ForeignMemory.fromAddress(pointer.address, length);
  }

  freeMem(memory) {
    if (immutable) {
      freeFunc.vcall$1(memory.address);
    } else {
      memory.free();
    }
  }

  // Please see the expected values in the ffi_test_library.c file (obvious
  // from the code below, but that is where they are defined).
  // For all memory returning functions we expect there to be 4 values of the
  // type we are working on.
  var libPath = ForeignLibrary.bundleLibraryName('ffi_test_library');
  ForeignLibrary fl = new ForeignLibrary.fromName(libPath);
  var pcall0 = fl.lookup('pfun0');
  var foreignPointer = pcall0.pcall$0();
  var memory = fromPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt32(0), 1);
  Expect.equals(memory.getInt32(4), 2);
  Expect.equals(memory.getInt32(8), 3);
  Expect.equals(memory.getInt32(12), 4);
  checkOutOfBoundsThrows(() => memory.getInt32(16));
  freeMem(memory);

  var pcall1 = fl.lookup('pfun1');
  foreignPointer = pcall1.pcall$1(42);
  memory = fromPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt32(0), 42);
  Expect.equals(memory.getInt32(4), 42);
  Expect.equals(memory.getInt32(8), 42);
  Expect.equals(memory.getInt32(12), 42);
  memory.setInt32(8, -1);
  Expect.equals(memory.getInt32(0), 42);
  Expect.equals(memory.getInt32(4), 42);
  Expect.equals(memory.getInt32(8), -1);
  Expect.equals(memory.getInt32(12), 42);
  freeMem(memory);

  var pcall2 = fl.lookup('pfun2');
  foreignPointer = pcall2.pcall$2(42, 43);
  memory = fromPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt32(0), 42);
  Expect.equals(memory.getInt32(4), 43);
  Expect.equals(memory.getInt32(8), 42);
  Expect.equals(memory.getInt32(12), 43);
  freeMem(memory);

  var pcall3 = fl.lookup('pfun3');
  foreignPointer = pcall3.pcall$3(42, 43, 44);
  memory = fromPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt32(0), 42);
  Expect.equals(memory.getInt32(4), 43);
  Expect.equals(memory.getInt32(8), 44);
  Expect.equals(memory.getInt32(12), 43);
  freeMem(memory);

  var pcall4 = fl.lookup('pfun4');
  foreignPointer = pcall4.pcall$4(42, 43, 44, 45);
  memory = fromPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt32(0), 42);
  Expect.equals(memory.getInt32(4), 43);
  Expect.equals(memory.getInt32(8), 44);
  Expect.equals(memory.getInt32(12), 45);
  freeMem(memory);

  var pcall5 = fl.lookup('pfun5');
  foreignPointer = pcall5.pcall$5(42, 43, 44, 45, 46);
  memory = fromPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt32(0), 42);
  Expect.equals(memory.getInt32(4), 43);
  Expect.equals(memory.getInt32(8), 44);
  Expect.equals(memory.getInt32(12), 45 + 46);
  freeMem(memory);

  var pcall6 = fl.lookup('pfun6');
  foreignPointer = pcall6.pcall$6(42, 43, 44, 45, 46, 47);
  memory = fromPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt32(0), 42);
  Expect.equals(memory.getInt32(4), 43);
  Expect.equals(memory.getInt32(8), 44);
  Expect.equals(memory.getInt32(12), 45 + 46 + 47);
  freeMem(memory);

  // All tetsts below here is basically sanity checking that we correctly
  // convert the values to and from c, and that we can also set and read
  // back values correctly.

  var memint8 = fl.lookup('memint8');
  foreignPointer = memint8.pcall$0();
  memory = fromPointer(foreignPointer, 4);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt8(0), -1);
  Expect.equals(memory.getInt8(1), -128);
  Expect.equals(memory.getInt8(2), 99);
  Expect.equals(memory.getInt8(3), 100);
  Expect.equals(memory.getUint8(0), 255);
  Expect.equals(memory.getUint8(1), 128);
  Expect.equals(memory.getUint8(2), 99);
  Expect.equals(memory.getUint8(3), 100);
  memory.setInt8(1, -1);
  memory.setUint8(2, 100);
  Expect.equals(memory.getInt8(0), -1);
  Expect.equals(memory.getInt8(1), -1);
  Expect.equals(memory.getInt8(2), 100);
  Expect.equals(memory.getInt8(3), 100);
  Expect.equals(memory.getUint8(0), 255);
  Expect.equals(memory.getUint8(1), 255);
  Expect.equals(memory.getUint8(2), 100);
  Expect.equals(memory.getUint8(3), 100);
  checkOutOfBoundsThrows(() => memory.getUint8(4));
  freeMem(memory);

  var memint16 = fl.lookup('memint16');
  foreignPointer = memint16.pcall$0();
  memory = fromPointer(foreignPointer, 8);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt16(0), 32767);
  Expect.equals(memory.getInt16(2), -32768);
  Expect.equals(memory.getInt16(4), 0);
  Expect.equals(memory.getInt16(6), -1);
  memory.setInt16(2, -1);
  Expect.equals(memory.getInt16(0), 32767);
  Expect.equals(memory.getInt16(2), -1);
  Expect.equals(memory.getInt16(4), 0);
  Expect.equals(memory.getInt16(6), -1);
  checkOutOfBoundsThrows(() => memory.getInt16(8));
  freeMem(memory);

  var memuint16 = fl.lookup('memuint16');
  foreignPointer = memuint16.pcall$0();
  memory = fromPointer(foreignPointer, 8);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getUint16(0), 0);
  Expect.equals(memory.getUint16(2), 32767);
  Expect.equals(memory.getUint16(4), 32768);
  Expect.equals(memory.getUint16(6), 65535);
  memory.setUint16(6, 1);
  Expect.equals(memory.getUint16(0), 0);
  Expect.equals(memory.getUint16(2), 32767);
  Expect.equals(memory.getUint16(4), 32768);
  Expect.equals(memory.getUint16(6), 1);
  checkOutOfBoundsThrows(() => memory.getUint16(8));
  freeMem(memory);

  var memuint32 = fl.lookup('memuint32');
  foreignPointer = memuint32.pcall$0();
  memory = fromPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getUint32(0), 0);
  Expect.equals(memory.getUint32(4), 1);
  Expect.equals(memory.getUint32(8), 65536);
  Expect.equals(memory.getUint32(12), 4294967295);
  memory.setUint32(8, 1);
  Expect.equals(memory.getUint32(0), 0);
  Expect.equals(memory.getUint32(4), 1);
  Expect.equals(memory.getUint32(8), 1);
  Expect.equals(memory.getUint32(12), 4294967295);
  checkOutOfBoundsThrows(() => memory.getUint32(16));
  freeMem(memory);

  var memint64 = fl.lookup('memint64');
  foreignPointer = memint64.pcall$0();
  memory = fromPointer(foreignPointer, 32);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt64(0), 0);
  Expect.equals(memory.getInt64(8), -1);
  Expect.equals(memory.getInt64(16), 9223372036854775807);
  Expect.equals(memory.getInt64(24), -9223372036854775808); /// 01: ok
  memory.setInt64(8, 9223372036854775806);
  Expect.equals(memory.getInt64(0), 0);
  // TODO(ricow): Failure, need to investigate
  Expect.equals(memory.getInt64(8), 9223372036854775806);
  Expect.equals(memory.getInt64(16), 9223372036854775807);
  Expect.equals(memory.getInt64(24), -9223372036854775808); /// 01: ok
  checkOutOfBoundsThrows(() => memory.getInt64(25));
  freeMem(memory);

  var memfloat32 = fl.lookup('memfloat32');
  foreignPointer = memfloat32.pcall$0();
  memory = fromPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.approxEquals(memory.getFloat32(0), 0);
  Expect.approxEquals(memory.getFloat32(4), 1.175494e-38, 0.01);
  Expect.approxEquals(memory.getFloat32(8), 3.402823e+38);
  Expect.equals(memory.getFloat32(12), 4);
  memory.setFloat32(4, 2.1);
  Expect.equals(memory.getFloat32(0), 0);
  Expect.approxEquals(memory.getFloat32(4), 2.1);
  Expect.approxEquals(memory.getFloat32(8), 3.402823e+38);
  Expect.equals(memory.getFloat32(12), 4);
  checkOutOfBoundsThrows(() => memory.getFloat32(16));
  freeMem(memory);

  var memfloat64 = fl.lookup('memfloat64');
  foreignPointer = memfloat64.pcall$0();
  memory = fromPointer(foreignPointer, 32);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getFloat64(0), 0);
  Expect.approxEquals(memory.getFloat64(8), 1.79769e+308);
  Expect.approxEquals(memory.getFloat64(16), -1.79769e+308);
  Expect.equals(memory.getFloat64(24), 4);
  memory.setFloat64(24, 1.79769e+308);
  Expect.equals(memory.getFloat64(0), 0);
  Expect.approxEquals(memory.getFloat64(8), 1.79769e+308);
  Expect.approxEquals(memory.getFloat64(16), -1.79769e+308);
  Expect.approxEquals(memory.getFloat64(24), 1.79769e+308);
  checkOutOfBoundsThrows(() => memory.getFloat64(25));
  freeMem(memory);
}

testVAndICall() {
  // We assume that there is a ffi_test_library library build.
  var libPath = ForeignLibrary.bundleLibraryName('ffi_test_library');
  ForeignLibrary fl = new ForeignLibrary.fromName(libPath);

  // Test metods that use a static int.
  var setup = fl.lookup('setup');
  var getcount = fl.lookup('getcount');
  var inc = fl.lookup('inc');
  var setcount = fl.lookup('setcount');
  Expect.equals(null, setup.vcall$0());
  Expect.equals(0, getcount.icall$0());
  Expect.equals(null, inc.vcall$0());
  Expect.equals(1, getcount.icall$0());
  Expect.equals(42, setcount.icall$1(42));

  // Test that reading out the value of the variable directly works
  var count = fl.lookupVariable('count');
  var countMemory = new ForeignMemory.fromAddress(count.address, 4);
  Expect.equals(42, countMemory.getInt32(0));

  // Test all the icall wrappers, all c functions returns the sum of the
  // arguments.
  var icall0 = fl.lookup('ifun0');
  var icall1 = fl.lookup('ifun1');
  var icall2 = fl.lookup('ifun2');
  var icall3 = fl.lookup('ifun3');
  var icall4 = fl.lookup('ifun4');
  var icall5 = fl.lookup('ifun5');
  var icall6 = fl.lookup('ifun6');
  var icall7 = fl.lookup('ifun7');
  Expect.equals(0, icall0.icall$0());
  Expect.equals(1, icall1.icall$1(1));
  Expect.equals(2, icall2.icall$2(1, 1));
  Expect.equals(3, icall3.icall$3(1, 1, 1));
  Expect.equals(4, icall4.icall$4(1, 1, 1, 1));
  Expect.equals(5, icall5.icall$5(1, 1, 1, 1, 1));
  Expect.equals(6, icall6.icall$6(1, 1, 1, 1, 1, 1));
  Expect.equals(7, icall7.icall$7(1, 1, 1, 1, 1, 1, 1));

  // Some limit tests, this is more of sanity checking of our conversions.
  Expect.equals(-1, icall1.icall$1(-1));
  Expect.equals(-2, icall2.icall$2(-1, -1));
  Expect.equals(2147483647, icall3.icall$3(2147483647, 0, 0));
  Expect.equals(2147483646, icall3.icall$3(2147483647, -1, 0));
  Expect.equals(-2147483647, icall3.icall$3(2147483647, 2, 0));
  Expect.equals(0, icall1.icall$1(4294967296));
  Expect.equals(1, icall1.icall$1(4294967297));
  Expect.equals(-1, icall1.icall$1(4294967295));
  Expect.equals(0, icall1.icall$1(1024 * 4294967296));
  Expect.equals(1, icall1.icall$1(1024 * 4294967296 + 1));

  // Test the retrying versions id icall wrappers.
  var icall0EINTR = fl.lookup('ifun0EINTR');
  var icall1EINTR = fl.lookup('ifun1EINTR');
  var icall2EINTR = fl.lookup('ifun2EINTR');
  var icall3EINTR = fl.lookup('ifun3EINTR');
  var icall4EINTR = fl.lookup('ifun4EINTR');
  var icall5EINTR = fl.lookup('ifun5EINTR');
  var icall6EINTR = fl.lookup('ifun6EINTR');
  var icall7EINTR = fl.lookup('ifun7EINTR');
  Expect.equals(-1, icall0EINTR.icall$0());
  Expect.equals(4, Foreign.errno);
  Expect.equals(-1, icall1EINTR.icall$1(1));
  Expect.equals(4, Foreign.errno);
  Expect.equals(-1, icall2EINTR.icall$2(1, 1));
  Expect.equals(4, Foreign.errno);
  Expect.equals(-1, icall3EINTR.icall$3(1, 1, 1));
  Expect.equals(4, Foreign.errno);
  Expect.equals(-1, icall4EINTR.icall$4(1, 1, 1, 1));
  Expect.equals(4, Foreign.errno);
  Expect.equals(-1, icall5EINTR.icall$5(1, 1, 1, 1, 1));
  Expect.equals(4, Foreign.errno);
  Expect.equals(-1, icall6EINTR.icall$6(1, 1, 1, 1, 1, 1));
  Expect.equals(4, Foreign.errno);
  Expect.equals(-1, icall7EINTR.icall$7(1, 1, 1, 1, 1, 1, 1));
  Expect.equals(4, Foreign.errno);
  Expect.equals(0, icall0EINTR.icall$0Retry());
  Expect.equals(4, Foreign.errno);
  Expect.equals(1, icall1EINTR.icall$1Retry(1));
  Expect.equals(4, Foreign.errno);
  Expect.equals(2, icall2EINTR.icall$2Retry(1, 1));
  Expect.equals(4, Foreign.errno);
  Expect.equals(3, icall3EINTR.icall$3Retry(1, 1, 1));
  Expect.equals(4, Foreign.errno);
  Expect.equals(4, icall4EINTR.icall$4Retry(1, 1, 1, 1));
  Expect.equals(4, Foreign.errno);
  Expect.equals(5, icall5EINTR.icall$5Retry(1, 1, 1, 1, 1));
  Expect.equals(4, Foreign.errno);
  Expect.equals(6, icall6EINTR.icall$6Retry(1, 1, 1, 1, 1, 1));
  Expect.equals(4, Foreign.errno);
  Expect.equals(7, icall7EINTR.icall$7Retry(1, 1, 1, 1, 1, 1, 1));
  Expect.equals(4, Foreign.errno);

  // Test that ForeignFunction.retry is available (note that this will
  // not actually retry as the retry count was exhausted by the calls above).
  Expect.equals(0, ForeignFunction.retry(() => icall0EINTR.icall$0()));
  Expect.equals(1, ForeignFunction.retry(() => icall1EINTR.icall$1(1)));
  Expect.equals(2, ForeignFunction.retry(() => icall2EINTR.icall$2(1, 1)));
  Expect.equals(3, ForeignFunction.retry(() => icall3EINTR.icall$3(1, 1, 1)));
  Expect.equals(
      4, ForeignFunction.retry(() => icall4EINTR.icall$4(1, 1, 1, 1)));
  Expect.equals(
      5, ForeignFunction.retry(() => icall5EINTR.icall$5(1, 1, 1, 1, 1)));
  Expect.equals(
      6, ForeignFunction.retry(() => icall6EINTR.icall$6(1, 1, 1, 1, 1, 1)));
  Expect.equals(
      7, ForeignFunction.retry(() => icall7EINTR.icall$7(1, 1, 1, 1, 1, 1, 1)));

  // Test all the void wrappers. The vcall c functions will set the count to
  // the sum of the arguments, testable by running getcount.
  var vcall0 = fl.lookup('vfun0');
  var vcall1 = fl.lookup('vfun1');
  var vcall2 = fl.lookup('vfun2');
  var vcall3 = fl.lookup('vfun3');
  var vcall4 = fl.lookup('vfun4');
  var vcall5 = fl.lookup('vfun5');
  var vcall6 = fl.lookup('vfun6');
  Expect.equals(null, vcall0.vcall$0());
  Expect.equals(0, getcount.icall$0());
  Expect.equals(null, vcall1.vcall$1(1));
  Expect.equals(1, getcount.icall$0());
  Expect.equals(null, vcall2.vcall$2(1, 1));
  Expect.equals(2, getcount.icall$0());
  Expect.equals(null, vcall3.vcall$3(1, 1, 1));
  Expect.equals(3, getcount.icall$0());
  Expect.equals(null, vcall4.vcall$4(1, 1, 1, 1));
  Expect.equals(4, getcount.icall$0());
  Expect.equals(null, vcall5.vcall$5(1, 1, 1, 1, 1));
  Expect.equals(5, getcount.icall$0());
  Expect.equals(null, vcall6.vcall$6(1, 1, 1, 1, 1, 1));
  Expect.equals(6, getcount.icall$0());
}

testFailingLibraryLookups() {
  var libPath = ForeignLibrary.bundleLibraryName('foobar');
  Expect.throws(
      () => new ForeignLibrary.fromName(libPath),
      isArgumentError);
  Expect.throws(
      () => new ForeignLibrary.fromName('random__for_not_hitting_foobar.so'),
      isArgumentError);
}

testDefaultLibraryLookups() {
  Expect.isTrue(ForeignLibrary.main.lookup('qsort') is ForeignFunction);
}

testAllocate(bool finalized, bool immutable) {
  freeMem(memory) {
    if (immutable) {
      freeFunc.vcall$1(memory.address);
    } else {
      memory.free();
    }
  }

  int length = 10;
  var memory;
  if (immutable) {
    memory = finalized
        ? new ImmutableForeignMemory.allocatedFinalized(length)
        : new ImmutableForeignMemory.allocated(length);
  } else {
    memory = finalized
        ? new ForeignMemory.allocatedFinalized(length)
        : new ForeignMemory.allocated(length);
  }
  Expect.isTrue(memory.address != 0);
  Expect.throws(() => memory.getUint8(-100), isRangeError);
  Expect.throws(() => memory.getUint8(-1), isRangeError);
  Expect.throws(() => memory.getUint8(10), isRangeError);
  Expect.throws(() => memory.getUint8(100), isRangeError);
  Expect.throws(() => memory.getUint32(7), isRangeError);

  Expect.throws(() => memory.setUint8(length, 0), isRangeError);
  Expect.throws(() => memory.setUint16(length - 1, 0), isRangeError);
  Expect.throws(() => memory.setUint32(length - 3, 0), isRangeError);
  Expect.throws(() => memory.setUint64(length - 7, 0), isRangeError);
  Expect.throws(() => memory.setInt8(length, 0), isRangeError);
  Expect.throws(() => memory.setInt16(length - 1, 0), isRangeError);
  Expect.throws(() => memory.setInt32(length - 3, 0), isRangeError);
  Expect.throws(() => memory.setInt64(length - 7, 0), isRangeError);

  for (var value in [0.0, new Object(), '123']) {
    Expect.throws(() => memory.setInt8(0, value), isArgumentError);
    Expect.throws(() => memory.setInt16(0, value), isArgumentError);
    Expect.throws(() => memory.setInt32(0, value), isArgumentError);
    Expect.throws(() => memory.setInt64(0, value), isArgumentError);
    Expect.throws(() => memory.setUint8(0, value), isArgumentError);
    Expect.throws(() => memory.setUint16(0, value), isArgumentError);
    Expect.throws(() => memory.setUint32(0, value), isArgumentError);
    Expect.throws(() => memory.setUint64(0, value), isArgumentError);
  }
  for (var value in [0, new Object(), '123']) {
    Expect.throws(() => memory.setFloat32(0, value), isArgumentError);
    Expect.throws(() => memory.setFloat64(0, value), isArgumentError);
  }

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
    freeMem(memory);
    if (!immutable) memory.free();  // Free'ing multiple times is okay.
  }
}

void otherProcess(ImmutableForeignMemory memory) {
  Expect.equals(42.0, memory.getFloat32(0));
}

void otherProcessNonFinalized(ImmutableForeignMemory memory) {
  Expect.equals(42.0, memory.getFloat32(0));
  freeFunc.vcall$1(memory.address);
}

testImmutablePassing(finalized) {
  var length = 10;
  var memory = finalized
      ? new ImmutableForeignMemory.allocatedFinalized(length)
      : new ImmutableForeignMemory.allocated(length);
  memory.setFloat32(0, 42.0);
  if (finalized) {
    Isolate.spawn(() => otherProcess(memory)).join();
  } else {
    Isolate.spawn(() => otherProcessNonFinalized(memory)).join();
  }
}

testStruct() {
  // Please see the expected values in the ffi_test_library.c file (obvious
  // from the code below, but that is where they are defined).
  // For all memory returning functions we expect there to be 4 values of the
  // type we are working on.
  var libPath = ForeignLibrary.bundleLibraryName('ffi_test_library');
  ForeignLibrary fl = new ForeignLibrary.fromName(libPath);
  var memuint32 = fl.lookup('memuint32');
  var foreignPointer = memuint32.pcall$0();
  var struct32 = new Struct32.fromAddress(foreignPointer.address, 4);
  Expect.equals(struct32.address, foreignPointer.address);
  Expect.equals(0, struct32.getField(0));
  Expect.equals(0, struct32.getWord(0));
  Expect.equals(1, struct32.getField(1));
  Expect.equals(1, struct32.getWord(4));
  Expect.equals(65536, struct32.getField(2));
  Expect.equals(65536, struct32.getWord(8));
  Expect.equals(-1, struct32.getField(3));
  Expect.equals(-1, struct32.getWord(12));
  struct32.setField(2, 1);
  Expect.equals(0, struct32.getField(0));
  Expect.equals(1, struct32.getField(1));
  Expect.equals(1, struct32.getField(2));
  Expect.equals(-1, struct32.getField(3));
  checkOutOfBoundsThrows(() => struct32.getField(4));
  checkOutOfBoundsThrows(() => struct32.getWord(13));
  // Reset field 2 to original value to use when testing with Struct
  // below.
  struct32.setField(2, 65536);

  var memint64 = fl.lookup('memint64');
  foreignPointer = memint64.pcall$0();
  var struct64 = new Struct64.fromAddress(foreignPointer.address, 4);
  Expect.equals(struct64.address, foreignPointer.address);
  Expect.equals(0, struct64.getField(0));
  Expect.equals(0, struct64.getWord(0));
  Expect.equals(-1, struct64.getField(1));
  Expect.equals(-1, struct64.getWord(8));
  Expect.equals(9223372036854775807, struct64.getField(2));
  Expect.equals(9223372036854775807, struct64.getWord(16));
  Expect.equals(-9223372036854775808, struct64.getField(3)); /// 01: ok
  Expect.equals(-9223372036854775808, struct64.getWord(24)); /// 01: ok
  struct64.setField(1, 9223372036854775806);
  Expect.equals(0, struct64.getField(0));
  Expect.equals(9223372036854775806, struct64.getField(1));
  Expect.equals(9223372036854775807, struct64.getField(2));
  Expect.equals(-9223372036854775808, struct64.getField(3)); /// 01: ok
  checkOutOfBoundsThrows(() => struct64.getField(4));
  checkOutOfBoundsThrows(() => struct64.getWord(25));
  // Reset field 1 to original value to use when testing with Struct
  // below.
  struct64.setField(1, -1);

  // Do a test using the platform specific word size.
  var memint;
  var expected;
  if (Foreign.machineWordSize == 4) {
    memint = fl.lookup('memuint32');
    expected = struct32;
  } else {
    assert(Foreign.machineWordSize == 8);
    memint = fl.lookup('memint64');
    expected = struct64;
  }
  foreignPointer = memint.pcall$0();
  var struct = new Struct.fromAddress(foreignPointer.address, 4);
  Expect.equals(struct.address, foreignPointer.address);
  Expect.equals(expected.getField(0), struct.getField(0));
  Expect.equals(expected.getWord(0 * expected.wordSize),
      struct.getWord(0 * struct.wordSize));
  Expect.equals(expected.getField(1), struct.getField(1));
  Expect.equals(expected.getWord(1 * expected.wordSize),
      struct.getWord(1 * struct.wordSize));
  Expect.equals(expected.getField(2), struct.getField(2));
  Expect.equals(expected.getWord(2 * expected.wordSize),
      struct.getWord(2 * struct.wordSize));
  Expect.equals(expected.getField(3), struct.getField(3));
  Expect.equals(expected.getWord(3 * expected.wordSize),
      struct.getWord(3 * struct.wordSize));
  struct.setField(1, 42);
  Expect.equals(expected.getField(0), struct.getField(0));
  Expect.equals(42, struct.getField(1));
  Expect.equals(expected.getField(2), struct.getField(2));
  Expect.equals(expected.getField(3), struct.getField(3));
  checkOutOfBoundsThrows(() => struct.getField(4));
  checkOutOfBoundsThrows(() => struct.getWord(3 * struct.wordSize + 1));

  // Check misaligned write and read.
  struct.setWord(struct.wordSize ~/ 2, 42);
  Expect.equals(42, struct.getWord(struct.wordSize ~/ 2));
  struct64.setWord(4, 42);
  Expect.equals(42, struct64.getWord(4));
  struct32.setWord(2, 42);
  Expect.equals(42, struct32.getWord(2));

  struct.free();
  struct64.free();
  struct32.free();
}

void testExternalFinalizer() {
  var libPath = ForeignLibrary.bundleLibraryName('ffi_test_library');
  ForeignLibrary fl = new ForeignLibrary.fromName(libPath);

  var makeA = fl.lookup("make_a_thing");
  var makeB = fl.lookup("make_b_thing");
  var finalizer = fl.lookup("free_thing");
  var check = fl.lookup("get_things");

  var a = makeA.pcall$0();
  var b = makeB.pcall$0();

  Expect.equals(3, check.icall$0());

  a.registerFinalizer(finalizer, a.address);
  b.registerFinalizer(finalizer, b.address);
  Expect.isTrue(b.removeFinalizer(finalizer));
  Expect.isFalse(b.removeFinalizer(finalizer));
  Expect.isFalse(b.removeFinalizer(makeA));

  a = null;
  b = null;

  // Make a GC happen...
  var x = new List(1024);
  x[1023] = 42;
  for (int i = 0; i < 100; i++) {
    var y = new List(1024);
    y[1023] = x[1023];
    x = y;
  }
  Expect.equals(42, x[1023]);

  Expect.equals(1, check.icall$0());
}
