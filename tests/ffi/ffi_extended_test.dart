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
  var fff2 =
      new Ffi('ffun2', Ffi.returnsFloat32, new List.filled(2, Ffi.float32), fl);
  var fff3 =
      new Ffi('ffun3', Ffi.returnsFloat32, new List.filled(3, Ffi.float32), fl);
  var fff4 =
      new Ffi('ffun4', Ffi.returnsFloat32, new List.filled(4, Ffi.float32), fl);
  var fff5 =
      new Ffi('ffun5', Ffi.returnsFloat32, new List.filled(5, Ffi.float32), fl);
  var fff6 =
      new Ffi('ffun6', Ffi.returnsFloat32, new List.filled(6, Ffi.float32), fl);
  var fff7 =
      new Ffi('ffun7', Ffi.returnsFloat32, new List.filled(7, Ffi.float32), fl);
  var fff8 =
      new Ffi('ffun8', Ffi.returnsFloat32, new List.filled(8, Ffi.float32), fl);
  var fff9 =
      new Ffi('ffun9', Ffi.returnsFloat32, new List.filled(9, Ffi.float32), fl);
  var fff10 = new Ffi(
      'ffun10', Ffi.returnsFloat32, new List.filled(10, Ffi.float32), fl);
  var fff11 = new Ffi(
      'ffun11', Ffi.returnsFloat32, new List.filled(11, Ffi.float32), fl);
  var fff12 = new Ffi(
      'ffun12', Ffi.returnsFloat32, new List.filled(12, Ffi.float32), fl);
  var fff13 = new Ffi(
      'ffun13', Ffi.returnsFloat32, new List.filled(13, Ffi.float32), fl);
  var fff14 = new Ffi(
      'ffun14', Ffi.returnsFloat32, new List.filled(14, Ffi.float32), fl);
  var fff15 = new Ffi(
      'ffun15', Ffi.returnsFloat32, new List.filled(15, Ffi.float32), fl);
  var fff16 = new Ffi(
      'ffun16', Ffi.returnsFloat32, new List.filled(16, Ffi.float32), fl);
  var fff17 = new Ffi(
      'ffun17', Ffi.returnsFloat32, new List.filled(17, Ffi.float32), fl);

  Expect.equals(fff0([]), 0.0);
  Expect.equals(fff1([1.5]), 1.5);
  Expect.equals(fff2([1.5, 1.5]), 3.0);
  Expect.equals(fff3([1.5, 1.5, 1.5]), 4.5);
  Expect.equals(fff4([1.5, 1.5, 1.5, 1.5]), 6);
  Expect.equals(fff5([1.5, 1.5, 1.5, 1.5, 1.5]), 7.5);
  Expect.equals(fff6([1.5, 1.5, 1.5, 1.5, 1.5, 1.5]), 9);
  Expect.equals(fff7([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5]), 10.5);
  Expect.equals(fff8([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5]), 12);
  Expect.equals(fff9([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5]), 13.5);
  Expect.equals(fff10([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5]), 15);
  Expect.equals(
      fff11([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5]), 16.5);
  Expect.equals(
      fff12([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5]), 18);
  Expect.equals(
      fff13([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 1.5]),
      19.5);
  Expect.equals(
      fff14([
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5
      ]),
      21);
  Expect.equals(
      fff15([
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5
      ]),
      22.5);
  Expect.equals(
      fff16([
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5
      ]),
      24);
  Expect.equals(
      fff17([
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        10.5
      ]),
      34.5);

  // Test mixtures of 32-bit and 64-bit integers.
  var mix32_64_32 = new Ffi(
      'mix32_64_32', Ffi.returnsInt64, [Ffi.int32, Ffi.int64, Ffi.int32], fl);
  var mix32_64_64 = new Ffi(
      'mix32_64_64', Ffi.returnsInt64, [Ffi.int32, Ffi.int64, Ffi.int64], fl);
  var mix64_32_64 = new Ffi(
      'mix64_32_64', Ffi.returnsInt64, [Ffi.int64, Ffi.int32, Ffi.int64], fl);

  Expect.equals(mix32_64_32([1, 1, 1]), 3);
  Expect.equals(mix32_64_64([1, 1, 1]), 3);
  Expect.equals(mix64_32_64([1, 1, 1]), 3);

  // Test mixture of float and int arguments, both spilled to stack.
  var i5f17 = new Ffi(
      'i5f17',
      Ffi.returnsFloat32,
      new List.from(new List.filled(5, Ffi.int32))
        ..addAll(new List.filled(17, Ffi.float32)),
      fl);

  var f17i5 = new Ffi(
      'f17i5',
      Ffi.returnsFloat32,
      new List.from(new List.filled(17, Ffi.float32))
        ..addAll(new List.filled(5, Ffi.int32)),
      fl);

  Expect.equals(
      i5f17([
        1,
        1,
        1,
        1,
        1,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5
      ]),
      30.5);
  Expect.equals(
      f17i5([
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1.5,
        1,
        1,
        1,
        1,
        1
      ]),
      30.5);

  var dff0 = new Ffi('dfun0', Ffi.returnsFloat64, [], fl);
  var dff1 = new Ffi('dfun1', Ffi.returnsFloat64, [Ffi.float64], fl);
  var dff2 =
      new Ffi('dfun2', Ffi.returnsFloat64, new List.filled(2, Ffi.float64), fl);
  var dff3 =
      new Ffi('dfun3', Ffi.returnsFloat64, new List.filled(3, Ffi.float64), fl);
  var dff4 =
      new Ffi('dfun4', Ffi.returnsFloat64, new List.filled(4, Ffi.float64), fl);
  var dff5 =
      new Ffi('dfun5', Ffi.returnsFloat64, new List.filled(5, Ffi.float64), fl);
  var dff6 =
      new Ffi('dfun6', Ffi.returnsFloat64, new List.filled(6, Ffi.float64), fl);
  var dff7 =
      new Ffi('dfun7', Ffi.returnsFloat64, new List.filled(7, Ffi.float64), fl);
  var dff8 =
      new Ffi('dfun8', Ffi.returnsFloat64, new List.filled(8, Ffi.float64), fl);
  var dff9 =
      new Ffi('dfun9', Ffi.returnsFloat64, new List.filled(9, Ffi.float64), fl);

  Expect.equals(dff0([]), 0.0);
  Expect.equals(dff1([1.5]), 1.5);
  Expect.equals(dff2([1.5, 1.25]), 2.75);
  Expect.equals(dff3([1.5, 1.25, 1.0]), 3.75);
  Expect.equals(dff4([1.5, 1.25, 1.0, 0.75]), 4.5);
  Expect.equals(dff5([1.5, 1.25, 1.0, 0.75, 0.5]), 5.0);
  Expect.equals(dff6([1.5, 1.25, 1.0, 0.75, 0.5, 0.25]), 5.25);
  Expect.equals(dff7([1.5, 1.25, 1.0, 0.75, 0.5, 0.25, 0.5]), 5.75);
  Expect.equals(dff8([1.5, 1.25, 1.0, 0.75, 0.5, 0.25, 0.5, 0.75]), 6.5);
  Expect.equals(dff9([1.5, 1.25, 1.0, 0.75, 0.5, 0.25, 0.5, 0.75, 1.0]), 7.5);

  // Test mixture of float and double arguments, including stack spill.
  var mixfp2 = new Ffi(
      'mixfp2',
      Ffi.returnsFloat64,
      new List.generate(2, (int i) => i % 2 == 0 ? Ffi.float32 : Ffi.float64),
      fl);
  var mixfp3 = new Ffi(
      'mixfp3',
      Ffi.returnsFloat64,
      new List.generate(3, (int i) => i % 2 == 0 ? Ffi.float32 : Ffi.float64),
      fl);
  var mixfp4 = new Ffi(
      'mixfp4',
      Ffi.returnsFloat64,
      new List.generate(4, (int i) => i % 2 == 0 ? Ffi.float32 : Ffi.float64),
      fl);
  var mixfp5 = new Ffi(
      'mixfp5',
      Ffi.returnsFloat64,
      new List.generate(5, (int i) => i % 2 == 0 ? Ffi.float32 : Ffi.float64),
      fl);
  var mixfp6 = new Ffi(
      'mixfp6',
      Ffi.returnsFloat64,
      new List.generate(6, (int i) => i % 2 == 0 ? Ffi.float32 : Ffi.float64),
      fl);
  var mixfp7 = new Ffi(
      'mixfp7',
      Ffi.returnsFloat64,
      new List.generate(7, (int i) => i % 2 == 0 ? Ffi.float32 : Ffi.float64),
      fl);
  var mixfp8 = new Ffi(
      'mixfp8',
      Ffi.returnsFloat64,
      new List.generate(8, (int i) => i % 2 == 0 ? Ffi.float32 : Ffi.float64),
      fl);
  var mixfp9 = new Ffi(
      'mixfp9',
      Ffi.returnsFloat64,
      new List.generate(9, (int i) => i % 2 == 0 ? Ffi.float32 : Ffi.float64),
      fl);
  var mixfp10 = new Ffi(
      'mixfp10',
      Ffi.returnsFloat64,
      new List.generate(10, (int i) => i % 2 == 0 ? Ffi.float32 : Ffi.float64),
      fl);
  var mixfp11 = new Ffi(
      'mixfp11',
      Ffi.returnsFloat64,
      new List.generate(11, (int i) => i % 2 == 0 ? Ffi.float32 : Ffi.float64),
      fl);
  var mixfp12 = new Ffi(
      'mixfp12',
      Ffi.returnsFloat64,
      new List.generate(12, (int i) => i % 2 == 0 ? Ffi.float32 : Ffi.float64),
      fl);
  var mixfp13 = new Ffi(
      'mixfp13',
      Ffi.returnsFloat64,
      new List.generate(13, (int i) => i % 2 == 0 ? Ffi.float32 : Ffi.float64),
      fl);

  Expect.equals(mixfp2([0.5, 1.0]), 1.5);
  Expect.equals(mixfp3([0.5, 1.0, 1.5]), 3.0);
  Expect.equals(mixfp4([0.5, 1.0, 1.5, 2.0]), 5);
  Expect.equals(mixfp5([0.5, 1.0, 1.5, 2.0, 2.5]), 7.5);
  Expect.equals(mixfp6([0.5, 1.0, 1.5, 2.0, 2.5, 3.0]), 10.5);
  Expect.equals(mixfp7([0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5]), 14);
  Expect.equals(mixfp8([0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]), 18);
  Expect.equals(mixfp9([0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5]), 22.5);
  Expect.equals(
      mixfp10([0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]), 27.5);
  Expect.equals(
      mixfp11([0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5]), 33.0);
  Expect.equals(
      mixfp12([0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0]),
      39.0);
  Expect.equals(
      mixfp13(
          [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 6.5]),
      45.5);
}
