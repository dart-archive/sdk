// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch.ffi';
import "package:expect/expect.dart";

bool isRangeError(e) => e is RangeError;
bool isArgumentError(e) => e is ArgumentError;

main() {
  testAllocate(false);
  testAllocate(true);

  testVAndICall();
  testFailingLibraryLookups();
  testDefaultLibraryLookups();
  testPCallAndMemory();
}

checkOutOfBoundsThrows(function) {
  Expect.throws(function, (e) => e is RangeError);
}

testPCallAndMemory() {
  // Please see the expected values in the ffi_test_library.c file (obvious
  // from the code below, but that is where they are defined).
  // For all memory returning functions we expect there to be 4 values of the
  // type we are working on.
  var libPath = ForeignLibrary.bundleLibraryName('ffi_test_library');
  ForeignLibrary fl = new ForeignLibrary.fromName(libPath);
  ForeignPointer p = new ForeignPointer();
  var pcall0 = fl.lookup('pfun0');
  var foreignPointer = pcall0.pcall$0(p);
  var memory = new ForeignMemory.fromForeignPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt32(0), 1);
  Expect.equals(memory.getInt32(4), 2);
  Expect.equals(memory.getInt32(8), 3);
  Expect.equals(memory.getInt32(12), 4);
  checkOutOfBoundsThrows(() => memory.getInt32(16));
  memory.free();
  memory = new ForeignMemory.fromForeignPointer(foreignPointer, 16);

  var pcall1 = fl.lookup('pfun1');
  foreignPointer = pcall1.pcall$1(p, 42);
  memory = new ForeignMemory.fromForeignPointer(foreignPointer, 16);
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
  memory.free();

  var pcall2 = fl.lookup('pfun2');
  foreignPointer = pcall2.pcall$2(p, 42, 43);
  memory = new ForeignMemory.fromForeignPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt32(0), 42);
  Expect.equals(memory.getInt32(4), 43);
  Expect.equals(memory.getInt32(8), 42);
  Expect.equals(memory.getInt32(12), 43);
  memory.free();

  // All tetsts below here is basically sanity checking that we correctly
  // convert the values to and from c, and that we can also set and read
  // back values correctly.

  var memint8 = fl.lookup('memint8');
  foreignPointer = memint8.pcall$0(p);
  memory = new ForeignMemory.fromForeignPointer(foreignPointer, 4);
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
  memory.free();

  var memint16 = fl.lookup('memint16');
  foreignPointer = memint16.pcall$0(p);
  memory = new ForeignMemory.fromForeignPointer(foreignPointer, 8);
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
  memory.free();

  var memuint16 = fl.lookup('memuint16');
  foreignPointer = memuint16.pcall$0(p);
  memory = new ForeignMemory.fromForeignPointer(foreignPointer, 8);
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
  memory.free();

  var memuint32 = fl.lookup('memuint32');
  foreignPointer = memuint32.pcall$0(p);
  memory = new ForeignMemory.fromForeignPointer(foreignPointer, 16);
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
  memory.free();

  var memint64 = fl.lookup('memint64');
  foreignPointer = memint64.pcall$0(p);
  memory = new ForeignMemory.fromForeignPointer(foreignPointer, 32);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt64(0), 0);
  Expect.equals(memory.getInt64(8), -1);
  Expect.equals(memory.getInt64(16), 9223372036854775807);
  Expect.equals(memory.getInt64(24), -9223372036854775808);
  memory.setInt64(8, 9223372036854775806);
  Expect.equals(memory.getInt64(0), 0);
  // TODO(ricow): Failure, need to investigate
  Expect.equals(memory.getInt64(8), 9223372036854775806);
  Expect.equals(memory.getInt64(16), 9223372036854775807);
  Expect.equals(memory.getInt64(24), -9223372036854775808);
  checkOutOfBoundsThrows(() => memory.getInt64(25));
  memory.free();

  var memfloat32 = fl.lookup('memfloat32');
  foreignPointer = memfloat32.pcall$0(p);
  memory = new ForeignMemory.fromForeignPointer(foreignPointer, 16);
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
  memory.free();

  var memfloat64 = fl.lookup('memfloat64');
  foreignPointer = memfloat64.pcall$0(p);
  memory = new ForeignMemory.fromForeignPointer(foreignPointer, 32);
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
  memory.free();

  fl.close();
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

  // Test all the icall wrappers, all c functions returns the sum of the
  // arguments.
  var icall0 = fl.lookup('ifun0');
  var icall1 = fl.lookup('ifun1');
  var icall2 = fl.lookup('ifun2');
  var icall3 = fl.lookup('ifun3');
  var icall4 = fl.lookup('ifun4');
  var icall5 = fl.lookup('ifun5');
  var icall6 = fl.lookup('ifun6');
  Expect.equals(0, icall0.icall$0());
  Expect.equals(1, icall1.icall$1(1));
  Expect.equals(2, icall2.icall$2(1, 1));
  Expect.equals(3, icall3.icall$3(1, 1, 1));
  Expect.equals(4, icall4.icall$4(1, 1, 1, 1));
  Expect.equals(5, icall5.icall$5(1, 1, 1, 1, 1));
  Expect.equals(6, icall6.icall$6(1, 1, 1, 1, 1, 1));

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
  fl.close();
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

testAllocate(bool finalized) {
  int length = 10;
  ForeignMemory memory = finalized
    ? new ForeignMemory.allocatedFinalize(length)
    : new ForeignMemory.allocated(length);
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
