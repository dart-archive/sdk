// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino.ffi';
import 'dart:dartino';
import "package:expect/expect.dart";

main() {
  var libPath = ForeignLibrary.bundleLibraryName('ffi_test_library');
  ForeignLibrary fl = new ForeignLibrary.fromName(libPath);

  // Test floating point up 17 arguments (16 are in registers on ARM).
  var fff0 = new Ffi('ffun0', Ffi.returnsFloat32, [], fl);
  var fff1 = new Ffi('ffun1', Ffi.returnsFloat32, [Ffi.float32], fl);
  var fff2 = new Ffi('ffun2', Ffi.returnsFloat32, 
    new List.filled(2, Ffi.float32), fl);
  var fff3 = new Ffi('ffun3', Ffi.returnsFloat32, 
    new List.filled(3, Ffi.float32), fl);
  var fff4 = new Ffi('ffun4', Ffi.returnsFloat32, 
    new List.filled(4, Ffi.float32), fl);
  var fff5 = new Ffi('ffun5', Ffi.returnsFloat32,
    new List.filled(5, Ffi.float32), fl);
  var fff6 = new Ffi('ffun6', Ffi.returnsFloat32,
    new List.filled(6, Ffi.float32), fl);
  var fff7 = new Ffi('ffun7', Ffi.returnsFloat32, 
    new List.filled(7, Ffi.float32), fl);
  var fff8 = new Ffi('ffun8', Ffi.returnsFloat32, 
    new List.filled(8, Ffi.float32), fl);
  var fff9 = new Ffi('ffun9', Ffi.returnsFloat32, 
    new List.filled(9, Ffi.float32), fl);
  var fff10 = new Ffi('ffun10', Ffi.returnsFloat32, 
    new List.filled(10, Ffi.float32), fl);
  var fff11 = new Ffi('ffun11', Ffi.returnsFloat32, 
    new List.filled(11, Ffi.float32), fl);
  var fff12 = new Ffi('ffun12', Ffi.returnsFloat32, 
    new List.filled(12, Ffi.float32), fl);
  var fff13 = new Ffi('ffun13', Ffi.returnsFloat32, 
    new List.filled(13, Ffi.float32), fl);
  var fff14 = new Ffi('ffun14', Ffi.returnsFloat32, 
    new List.filled(14, Ffi.float32), fl);
  var fff15 = new Ffi('ffun15', Ffi.returnsFloat32, 
    new List.filled(15, Ffi.float32), fl);
  var fff16 = new Ffi('ffun16', Ffi.returnsFloat32, 
    new List.filled(16, Ffi.float32), fl);
  var fff17 = new Ffi('ffun17', Ffi.returnsFloat32, 
    new List.filled(17, Ffi.float32), fl);


  Expect.equals(fff0([]), 0.0);
  Expect.equals(fff1([1.5]), 1.5);
  Expect.equals(fff2([1.5, 1.5]), 3.0);
  Expect.equals(fff3([1.5, 1.5, 1.5]), 4.5);
  Expect.equals(fff4([1.5, 1.5, 1.5, 1.5]), 6);
  Expect.equals(fff5([1.5, 1.5, 1.5, 1.5, 1.5]), 7.5);
  Expect.equals(fff6([1.5, 1.5, 1.5, 1.5, 1.5, 1.5]), 9);
  Expect.equals(fff7([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5]), 10.5);
  Expect.equals(fff8([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
   1.5]), 12);
  Expect.equals(fff9([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
   1.5, 1.5]), 13.5);
  Expect.equals(fff10([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
   1.5, 1.5, 1.5]), 15);
  Expect.equals(fff11([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
   1.5, 1.5, 1.5, 1.5]), 16.5);
  Expect.equals(fff12([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
   1.5, 1.5, 1.5, 1.5, 1.5]), 18);
  Expect.equals(fff13([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
   1.5, 1.5, 1.5, 1.5, 1.5, 1.5]), 19.5);
  Expect.equals(fff14([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
   1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5]), 21);
  Expect.equals(fff15([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
   1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5]), 22.5);
  Expect.equals(fff16([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
   1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5]), 24);
  Expect.equals(fff17([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
   1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 10.5]), 34.5);

  // Test mixtures of 32-bit and 64-bit integers.
  var mix32_64_32 = new Ffi('mix32_64_32', Ffi.returnsInt64,
    [Ffi.int32, Ffi.int64, Ffi.int32], fl);
  var mix32_64_64 = new Ffi('mix32_64_64', Ffi.returnsInt64,
    [Ffi.int32, Ffi.int64, Ffi.int64], fl);
  var mix64_32_64 = new Ffi('mix64_32_64', Ffi.returnsInt64,
    [Ffi.int64, Ffi.int32, Ffi.int64], fl);

  Expect.equals(mix32_64_32([1, 1, 1]), 3);
  Expect.equals(mix32_64_64([1, 1, 1]), 3);
  Expect.equals(mix64_32_64([1, 1, 1]), 3);

  // Test mixture of float and int arguments, both spilled to stack.
  var i5f17 = new Ffi('i5f17', Ffi.returnsFloat32, 
    new List.from(new List.filled(5, Ffi.int32))
    ..addAll(new List.filled(17, Ffi.float32)), fl);

  var f17i5 = new Ffi('f17i5', Ffi.returnsFloat32, 
    new List.from(new List.filled(17, Ffi.float32))
    ..addAll(new List.filled(5, Ffi.int32)), fl);

  Expect.equals(i5f17([1, 1, 1, 1, 1, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
   1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5]), 30.5);
  Expect.equals(f17i5([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5,
   1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1, 1, 1, 1, 1]), 30.5);

}
