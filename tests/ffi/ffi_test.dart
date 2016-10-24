// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino.ffi';
import 'dart:dartino';
import 'dart:typed_data';
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

  testVariadicFfiCall();

  testImmutablePassing(false);
  testImmutablePassing(true);
  testExternalFinalizer();

  testDoubleBits();
  testDoubleConversion();
  testBitSizes();

  testCallbacksFromC();
  testNestedFfiCalls();
  testOutOfResources();
  testDoubleFree();
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
  var vcall7 = fl.lookup('vfun7');
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
  Expect.equals(null, vcall7.vcall$7(1, 1, 1, 1, 1, 1, 1));
  Expect.equals(7, getcount.icall$0());
}

testVariadicFfiCall() {
  var libPath = ForeignLibrary.bundleLibraryName('ffi_test_library');
  ForeignLibrary fl = new ForeignLibrary.fromName(libPath);

  // Test methods that use a static int.
  var setup = new Ffi('setup', Ffi.returnsVoid, [], fl);
  var getcount = new Ffi('getcount', Ffi.returnsInt32, [], fl);
  var inc = new Ffi('inc', Ffi.returnsVoid, [], fl);
  var setcount = new Ffi('setcount', Ffi.returnsInt32, [Ffi.int32], fl);
  Expect.equals(null, setup([]));
  Expect.equals(0, setcount([0]));
  Expect.equals(0, getcount([]));
  Expect.equals(null, inc([]));
  Expect.equals(1, getcount([]));
  Expect.equals(42, setcount([42]));

  // Test that reading out the value of the variable directly works
  var count = fl.lookupVariable('count');
  var countMemory = new ForeignMemory.fromAddress(count.address, 4);
  Expect.equals(42, countMemory.getInt32(0));

  // Test function calls with different number of arguments
  var icall0 = new Ffi('ifun0', Ffi.returnsInt32, [], fl);
  var icall1 = new Ffi('ifun1', Ffi.returnsInt32, [Ffi.int32], fl);
  var icall2 = new Ffi('ifun2', Ffi.returnsInt32, [Ffi.int32, Ffi.int32], fl);
  var icall3 = new Ffi('ifun3', Ffi.returnsInt32, 
    new List.filled(3, Ffi.int32), fl);
  var icall4 = new Ffi('ifun4', Ffi.returnsInt32,
    new List.filled(4, Ffi.int32), fl);
  var icall5 = new Ffi('ifun5', Ffi.returnsInt32,
    new List.filled(5, Ffi.int32), fl);
  var icall6 = new Ffi('ifun6', Ffi.returnsInt32,
    new List.filled(6, Ffi.int32), fl);
  var icall7 = new Ffi('ifun7', Ffi.returnsInt32,
    new List.filled(7, Ffi.int32), fl);
  Expect.equals(0, icall0([]));
  Expect.equals(1, icall1([1]));
  Expect.equals(2, icall2([1, 1]));
  Expect.equals(3, icall3([1, 1, 1]));
  Expect.equals(4, icall4([1, 1, 1, 1]));
  Expect.equals(5, icall5([1, 1, 1, 1, 1]));
  Expect.equals(6, icall6([1, 1, 1, 1, 1, 1]));
  Expect.equals(7, icall7([1, 1, 1, 1, 1, 1, 1]));

  // Test wrong number of arguments
  Expect.throws(() => icall0([1]), isArgumentError);
  Expect.throws(() => icall3([1, 1]), isArgumentError);
  // Test wrong argument types
  Expect.throws(() => icall1(1), isArgumentError);
  Expect.throws(() => icall1(["Abc"]), isArgumentError);
  Expect.throws(() => icall2([1, "Abc"]), isArgumentError);
  // Conversion of doubles (truncates)
  Expect.equals(1, icall2([1.5, 0.9]));

  // Some limit tests, this is more of sanity checking of our conversions.
  Expect.equals(-1, icall1([-1]));
  Expect.equals(-2, icall2([-1, -1]));
  Expect.equals(2147483647, icall3([2147483647, 0, 0]));
  Expect.equals(2147483646, icall3([2147483647, -1, 0]));
  Expect.equals(-2147483647, icall3([2147483647, 2, 0]));
  Expect.equals(0, icall1([4294967296]));
  Expect.equals(1, icall1([4294967297]));
  Expect.equals(-1, icall1([4294967295]));
  Expect.equals(0, icall1([1024 * 4294967296]));
  Expect.equals(1, icall1([1024 * 4294967296 + 1]));

  // Test all int64 returning versions.
  var i64call0 = new Ffi('i64fun0', Ffi.returnsInt64, [], fl);
  var i64call1 = new Ffi('i64fun1', Ffi.returnsInt64, [Ffi.int32], fl);
  var i64call2 = new Ffi('i64fun2', Ffi.returnsInt64, 
    [Ffi.int32, Ffi.int32], fl);
  var i64call3 = new Ffi('i64fun3', Ffi.returnsInt64,
    new List.filled(3, Ffi.int32), fl);
  var i64call4 = new Ffi('i64fun4', Ffi.returnsInt64,
    new List.filled(4, Ffi.int32), fl);
  var i64call5 = new Ffi('i64fun5', Ffi.returnsInt64,
    new List.filled(5, Ffi.int32), fl);
  var i64call6 = new Ffi('i64fun6', Ffi.returnsInt64,
    new List.filled(6, Ffi.int32), fl);
  var i64call7 = new Ffi('i64fun7', Ffi.returnsInt64,
    new List.filled(7, Ffi.int32), fl);
  Expect.equals(0, i64call0([]));
  Expect.equals(1, i64call1([1]));
  Expect.equals(2, i64call2([1, 1]));
  Expect.equals(3, i64call3([1, 1, 1]));
  Expect.equals(4, i64call4([1, 1, 1, 1]));
  Expect.equals(5, i64call5([1, 1, 1, 1, 1]));
  Expect.equals(6, i64call6([1, 1, 1, 1, 1, 1]));
  Expect.equals(7, i64call7([1, 1, 1, 1, 1, 1, 1]));

  // Test all the void returning versions.
  // The vcall c functions will set the count to
  // the sum of the arguments, testable by running getcount.
  var vcall0 = new Ffi('vfun0', Ffi.returnsVoid, [], fl);
  var vcall1 = new Ffi('vfun1', Ffi.returnsVoid, [Ffi.int32], fl);
  var vcall2 = new Ffi('vfun2', Ffi.returnsVoid, [Ffi.int32, Ffi.int32], fl);
  var vcall3 = new Ffi('vfun3', Ffi.returnsVoid, 
    new List.filled(3, Ffi.int32), fl);
  var vcall4 = new Ffi('vfun4', Ffi.returnsVoid,
    new List.filled(4, Ffi.int32), fl);
  var vcall5 = new Ffi('vfun5', Ffi.returnsVoid,
    new List.filled(5, Ffi.int32), fl);
  var vcall6 = new Ffi('vfun6', Ffi.returnsVoid,
    new List.filled(6, Ffi.int32), fl);
  var vcall7 = new Ffi('vfun7', Ffi.returnsVoid,
    new List.filled(7, Ffi.int32), fl);
  Expect.equals(null, vcall0([]));
  Expect.equals(0, getcount([]));
  Expect.equals(null, vcall1([1]));
  Expect.equals(1, getcount([]));
  Expect.equals(null, vcall2([1, 1]));
  Expect.equals(2, getcount([]));
  Expect.equals(null, vcall3([1, 1, 1]));
  Expect.equals(3, getcount([]));
  Expect.equals(null, vcall4([1, 1, 1, 1]));
  Expect.equals(4, getcount([]));
  Expect.equals(null, vcall5([1, 1, 1, 1, 1]));
  Expect.equals(5, getcount([]));
  Expect.equals(null, vcall6([1, 1, 1, 1, 1, 1]));
  Expect.equals(6, getcount([]));
  Expect.equals(null, vcall7([1, 1, 1, 1, 1, 1, 1]));
  Expect.equals(7, getcount([]));

  var pcall0 = new Ffi('pfun0', Ffi.returnsPointer, [], fl);
  var pcall1 = new Ffi('pfun1', Ffi.returnsPointer, [Ffi.int32], fl);
  var pcall2 = new Ffi('pfun2', Ffi.returnsPointer, 
    [Ffi.int32, Ffi.int32], fl);
  var pcall3 = new Ffi('pfun3', Ffi.returnsPointer, 
    new List.filled(3, Ffi.int32), fl);
  var pcall4 = new Ffi('pfun4', Ffi.returnsPointer,
    new List.filled(4, Ffi.int32), fl);
  var pcall5 = new Ffi('pfun5', Ffi.returnsPointer,
    new List.filled(5, Ffi.int32), fl);
  var pcall6 = new Ffi('pfun6', Ffi.returnsPointer,
    new List.filled(6, Ffi.int32), fl);

  fromPointer(ForeignPointer pointer, int length) {
    return new ForeignMemory.fromAddress(pointer.address, length);
  }

  var foreignPointer = pcall0([]);
  var memory = fromPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt32(0), 1);
  Expect.equals(memory.getInt32(4), 2);
  Expect.equals(memory.getInt32(8), 3);
  Expect.equals(memory.getInt32(12), 4);
  checkOutOfBoundsThrows(() => memory.getInt32(16));
  memory.free();

  foreignPointer = pcall1([42]);
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
  memory.free();

  foreignPointer = pcall2([42, 43]);
  memory = fromPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt32(0), 42);
  Expect.equals(memory.getInt32(4), 43);
  Expect.equals(memory.getInt32(8), 42);
  Expect.equals(memory.getInt32(12), 43);
  memory.free();

  foreignPointer = pcall3([42, 43, 44]);
  memory = fromPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt32(0), 42);
  Expect.equals(memory.getInt32(4), 43);
  Expect.equals(memory.getInt32(8), 44);
  Expect.equals(memory.getInt32(12), 43);
  memory.free();

  foreignPointer = pcall4([42, 43, 44, 45]);
  memory = fromPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt32(0), 42);
  Expect.equals(memory.getInt32(4), 43);
  Expect.equals(memory.getInt32(8), 44);
  Expect.equals(memory.getInt32(12), 45);
  memory.free();

  foreignPointer = pcall5([42, 43, 44, 45, 46]);
  memory = fromPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt32(0), 42);
  Expect.equals(memory.getInt32(4), 43);
  Expect.equals(memory.getInt32(8), 44);
  Expect.equals(memory.getInt32(12), 45 + 46);
  memory.free();

  foreignPointer = pcall6([42, 43, 44, 45, 46, 47]);
  memory = fromPointer(foreignPointer, 16);
  Expect.equals(memory.address, foreignPointer.address);
  Expect.equals(memory.getInt32(0), 42);
  Expect.equals(memory.getInt32(4), 43);
  Expect.equals(memory.getInt32(8), 44);
  Expect.equals(memory.getInt32(12), 45 + 46 + 47);
  memory.free();
}

testFailingLibraryLookups() {
  print("** Failed library lookups on missing.so are normal and expected.");
  var libPath = ForeignLibrary.bundleLibraryName('missing');
  Expect.throws(
      () => new ForeignLibrary.fromName(libPath),
      isArgumentError);
  Expect.throws(
      () => new ForeignLibrary.fromName('random__for_not_hitting_missing.so'),
      isArgumentError);
  print("** Failed library lookups on missing.so are normal and expected.");
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

void testDoubleBits() {
  double roundTrip(x) {
    return ForeignFunction.signedBitsToDouble(
        ForeignFunction.doubleToSignedBits(x));
  }

  List doubleTests = [
    0.0, 1.0, 2.0,
    1.0000000000000002, 1.0000000000000004,
    4.9406564584124654e-324, 2.2250738585072009e-308,
    2.2250738585072014e-308, 1.7976931348623157e308,
    double.NAN,
    double.INFINITY,
    3.402823466e38, 1.175494351e-38
  ];

  for (double d in doubleTests) {
    Expect.identical(d, roundTrip(d));
    Expect.identical(-d, roundTrip(-d));
  }

  Expect.throws(() => ForeignFunction.signedBitsToDouble("str"));
  Expect.throws(() => ForeignFunction.signedBitsToDouble(null));
  Expect.throws(() => ForeignFunction.signedBitsToDouble(true));
  Expect.throws(() => ForeignFunction.signedBitsToDouble(5.0));

  Expect.throws(() => ForeignFunction.doubleToSignedBits("str"));
  Expect.throws(() => ForeignFunction.doubleToSignedBits(null));
  Expect.throws(() => ForeignFunction.doubleToSignedBits(true));
  Expect.throws(() => ForeignFunction.doubleToSignedBits(5));
}

void testDoubleConversion() {
  // We assume that there is a ffi_test_library library build.
  var libPath = ForeignLibrary.bundleLibraryName('ffi_test_library');
  ForeignLibrary fl = new ForeignLibrary.fromName(libPath);

  var echoFun = fl.lookup('echoWord');

  int echo(x) {
    // We can't use `icall` since that truncates the return value to a C `int`.
    return echoFun.pcall$1(x).address;
  }

  List doubleTests = [
    0.0, 1.0, 2.0,
    1.0000000000000002, 1.0000000000000004,
    4.9406564584124654e-324, 2.2250738585072009e-308,
    2.2250738585072014e-308, 1.7976931348623157e308,
    double.NAN,
    double.INFINITY,
    3.402823466e38, 1.175494351e-38
  ];

  int typedListLeastSignificantBitsOf(double d) {
    var float64List = new Float64List(1);
    float64List[0] = d;
    return float64List.buffer.asUint32List()[
        Endianness.HOST_ENDIAN == Endianness.BIG_ENDIAN ? 1 : 0];
  }

  for (double d in doubleTests) {
    var bits = echo(d);
    var negatedBits = echo(-d);

    if (Foreign.bitsPerMachineWord >= Foreign.bitsPerDouble) {
      Expect.identical(d, ForeignFunction.signedBitsToDouble(bits));
      Expect.identical(-d, ForeignFunction.signedBitsToDouble(negatedBits));
    } else {
      Expect.equals(32, Foreign.bitsPerMachineWord);
      Expect.equals(64, Foreign.bitsPerDouble);
      int mask = (1 << Foreign.bitsPerMachineWord) - 1;
      Expect.equals(typedListLeastSignificantBitsOf(d), bits & mask);
      Expect.equals(typedListLeastSignificantBitsOf(-d), negatedBits & mask);
    }
  }
}

void testBitSizes() {
  int wordBitSize = Foreign.bitsPerMachineWord;
  Expect.isTrue(wordBitSize == 32 || wordBitSize == 64);
  int doubleBitSize = Foreign.bitsPerDouble;
  Expect.isTrue(doubleBitSize == 32 || doubleBitSize == 64);
}

// Test callbacks from C to Dart.

testCallbacksFromC() {
  var foreignDartFunctions = <ForeignDartFunction>[];

  ForeignDartFunction buildCallback(f) {
    var result = new ForeignDartFunction(f);
    foreignDartFunctions.add(result);
    return result;
  }

  var libPath = ForeignLibrary.bundleLibraryName('ffi_test_library');
  ForeignLibrary fl = new ForeignLibrary.fromName(libPath);
  var trampoline0 = fl.lookup('trampoline0');
  var trampoline1 = fl.lookup('trampoline1');
  var trampoline2 = fl.lookup('trampoline2');
  var trampoline3 = fl.lookup('trampoline3');

  var events = [];

  Expect.equals(10000, trampoline0.icall$1(buildCallback(() {
    events.add("callback from C");
    var sum = 0;
    for (int i = 0; i < 10000; i++) {
      sum++;
    }
    events.add("returning sum: $sum");
    return sum;
  })));

  Expect.equals(4, trampoline1.icall$2(buildCallback((int x) {
    events.add("callback from C with $x");
    return x + 1;
  }), 3));

  Expect.equals(13, trampoline2.icall$3(buildCallback((int x, int y) {
    events.add("callback from C with $x and $y");
    return x + y + 1;
  }), 5, 7));

  Expect.equals(1007, trampoline3.icall$4(buildCallback((int x, int y, int z) {
    events.add("callback from C with $x and $y, $z");
    return x + y + z + 1000;
  }), 1, 2, 4));

  Expect.listEquals([ "callback from C", "returning sum: 10000",
      "callback from C with 3", "callback from C with 5 and 7",
      "callback from C with 1 and 2, 4"],
      events);

  foreignDartFunctions.forEach((f) => f.free());
}

// Test nested ffi calls:
// ===

int allocateALot() {
  for (int i = 0; i < 100000; i++) {
    var map = {};
    map['foo'] = [1, 2];
    if (map['foo'] == map['bar']) return -1;
  }
  return 1;
}

testNestedFfiCalls() {
  var foreignDartFunctions = <ForeignDartFunction>[];

  ForeignDartFunction buildCallback(f) {
    var result = new ForeignDartFunction(f);
    foreignDartFunctions.add(result);
    return result;
  }

  var libPath = ForeignLibrary.bundleLibraryName('ffi_test_library');
  ForeignLibrary fl = new ForeignLibrary.fromName(libPath);
  var trampoline2 = fl.lookup('trampoline2');

  var events = [];

  int nested1(trampoline2) {
    events.add("nested1 before");

    var next = buildCallback((int nextAddress, int trampoline2Address) {
      events.add("nested2 before");

      var next = new ForeignFunction.fromAddress(nextAddress);

      var nextNext = new ForeignDartFunction(() {
        events.add("nested4");
        return allocateALot() + 3;
      });

      var trampoline2 = new ForeignFunction.fromAddress(trampoline2Address);
      var result = trampoline2.icall$3(next, nextNext, trampoline2);
      nextNext.free();
      events.add("nested2 after: $result");
      return 2;
    });

    var nextNext = buildCallback((int nextAddress, int trampoline2Address) {
      events.add("nested3 before");
      var next = new ForeignFunction.fromAddress(nextAddress);
      var result = next.icall$0();
      events.add("nested3 after: $result");
      return 3;
    });

    var result = trampoline2.icall$3(next, nextNext, trampoline2);
    next.free();
    nextNext.free();
    events.add("nested1 after: $result");
    return 1;
  }

  Expect.equals(1, nested1(trampoline2));
  Expect.listEquals([
      "nested1 before",
      "nested2 before",
      "nested3 before",
      "nested4",
      "nested3 after: 4",
      "nested2 after: 3",
      "nested1 after: 2",
  ], events);
}

testOutOfResources() {
  var allocated = [];
  // In a system where wrapper functions are created dynamically, this test must
  // be adapted or removed.
  bool hitOutOfResources = false;
  for (int i = 0; i < 10000; i++) {
    try {
      allocated.add(new ForeignDartFunction(testOutOfResources));
    } on ResourceExhaustedException catch (e) {
      hitOutOfResources = true;
    }
  }
  Expect.isTrue(hitOutOfResources);
  for (ForeignDartFunction f in allocated) f.free();
  allocated.clear();
  // After freeing the allocated wrappers, we should be back in business.
  for (int i = 0; i < 3; i++) {
    allocated.add(new ForeignDartFunction(testOutOfResources));
  }
  // Should reach this line without exceptions.
  for (ForeignDartFunction f in allocated) f.free();
}

testDoubleFree() {
  var f = new ForeignDartFunction(testDoubleFree);
  f.free();
  // It is an error to free a foreign function twice. No need to test the type.
  Expect.throws(() { f.free(); });
}
