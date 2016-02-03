// Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// Dartino test program for testing typed data.

import "package:expect/expect.dart";
import 'dart:typed_data';

void testCreateUint8TypedData() {
  Uint8List typed_data;

  typed_data = new Uint8List(0);
  Expect.isTrue(typed_data is Uint8List);
  Expect.isFalse(typed_data is Uint8ClampedList);
  Expect.equals(0, typed_data.length);

  typed_data = new Uint8List(10);
  Expect.equals(10, typed_data.length);
  for (int i = 0; i < 10; i++) {
    Expect.equals(0, typed_data[i]);
  }
}

void testCreateClampedUint8TypedData() {
  Uint8ClampedList typed_data;

  typed_data = new Uint8ClampedList(0);
  Expect.isTrue(typed_data is Uint8ClampedList);
  Expect.isFalse(typed_data is Uint8List);
  Expect.equals(0, typed_data.length);
  Expect.equals(0, typed_data.lengthInBytes);

  typed_data = new Uint8ClampedList(10);
  Expect.equals(10, typed_data.length);
  for (int i = 0; i < 10; i++) {
    Expect.equals(0, typed_data[i]);
  }
}

void testTypedDataRange(bool check_throws) {
  Int8List typed_data;
  typed_data = new Int8List(10);
  typed_data[1] = 0;
  Expect.equals(0, typed_data[1]);
  typed_data[2] = -128;
  Expect.equals(-128, typed_data[2]);
  typed_data[3] = 127;
  Expect.equals(127, typed_data[3]);
  // This should eventually throw.
  typed_data[0] = 128;
  typed_data[4] = -129;
  if (check_throws) {
    Expect.throws(() {
      typed_data[1] = 1.2;
    });
  }
  Expect.throws(() => typed_data[-1]);
  Expect.throws(() => typed_data[100]);
  // TODO(wibling): Enable the below. It causes a vm crash wrt. largeIntegers.
  //Expect.throws(() => typed_data[2.0]);
}

void testUnsignedTypedDataRange(bool check_throws) {
  Uint8List typed_data;
  typed_data = new Uint8List(10);

  typed_data[1] = 255;
  Expect.equals(255, typed_data[1]);
  typed_data[1] = 0;
  Expect.equals(0, typed_data[1]);

  for (int i = 0; i < typed_data.length; i++) {
    typed_data[i] = i;
  }
  for (int i = 0; i < typed_data.length; i++) {
    Expect.equals(i, typed_data[i]);
  }

  // These should eventually throw.
  typed_data[1] = 256;
  typed_data[1] = -1;
  typed_data[2] = -129;
  if (check_throws) {
    Expect.throws(() {
      typed_data[1] = 1.2;
    });
  }
  Expect.throws(() => typed_data[-1]);
  Expect.throws(() => typed_data[100]);
  // TODO(wibling): Enable the below. It causes a vm crash wrt. largeIntegers.
  //Expect.throws(() => typed_data[2.0]);
}

void testClampedUnsignedTypedDataRangeHelper(Uint8ClampedList typed_data,
                                             bool check_throws) {
  Uint8ClampedList typed_data;
  typed_data = new Uint8ClampedList(10);

  typed_data[1] = 255;
  Expect.equals(255, typed_data[1]);
  typed_data[1] = 0;
  Expect.equals(0, typed_data[1]);
  for (int i = 0; i < typed_data.length; i++) {
    typed_data[i] = i;
  }
  for (int i = 0; i < typed_data.length; i++) {
    Expect.equals(i, typed_data[i]);
  }

  // These should eventually throw.
  typed_data[1] = 256;
  typed_data[2] = -129;
  Expect.equals(255, typed_data[1]);
  Expect.equals(0, typed_data[2]);
}

void testClampedUnsignedTypedDataRange(bool check_throws) {
  testClampedUnsignedTypedDataRangeHelper(new Uint8ClampedList(10),
                                          check_throws);
}

void testSetRangeHelper(typed_data) {
  List<int> list = [10, 11, 12];
  typed_data.setRange(0, 3, list);
  for (int i = 0; i < 3; i++) {
    Expect.equals(10 + i, typed_data[i]);
  }

  typed_data[0] = 20;
  typed_data[1] = 21;
  typed_data[2] = 22;
  list.setRange(0, 3, typed_data);
  for (int i = 0; i < 3; i++) {
    Expect.equals(20 + i, list[i]);
  }

  typed_data.setRange(1, 3, const [8, 9]);
  Expect.equals(20, typed_data[0]);
  Expect.equals(8, typed_data[1]);
  Expect.equals(9, typed_data[2]);
}

void testSetRange() {
  testSetRangeHelper(new Uint8List(3));
  testSetRangeHelper(new Uint8ClampedList(3));
  testSetRangeHelper(new Uint16List(3));
  testSetRangeHelper(new Int16List(3));

  var list = new Uint8List(4);
  list.setRange(0, 4, "abcd".codeUnits, 0);
  Expect.listEquals(list, "abcd".codeUnits);
  list = new Uint16List(4);
  list.setRange(0, 4, "abcd".codeUnits, 0);
  Expect.listEquals(list, "abcd".codeUnits);
  list.setRange(0, 4, "\xff\u0100\uffff\x00".codeUnits, 0);
  Expect.listEquals(list, "\xff\u0100\uffff\x00".codeUnits);
  list = new Int16List(4);
  list.setRange(0, 4, "abcd".codeUnits, 0);
  Expect.listEquals(list, "abcd".codeUnits);
  list.setRange(0, 4, "\xff\u0100\u7fff\x00".codeUnits, 0);
  Expect.listEquals(list, "\xff\u0100\u7fff\x00".codeUnits);
}

class C {
  final x;
  C(this.x);
  operator<(o) => false;
  operator>=(o) => false;
  operator*(o) => x;
}

void testIndexOutOfRangeHelper(typed_data, value) {
  List<int> list = new List<int>(typed_data.length + 1);
  for (int i = 0; i < list.length; i++) list[i] = i;

  Expect.throws(() {
    typed_data.setRange(0, 4, list);
  });

  Expect.throws(() {
    typed_data.setRange(3, 4, list);
  });

  Expect.throws(() {
    typed_data[new C(-4000000)] = value;
  });

  Expect.throws(() {
    var size = typed_data.elementSizeInBytes;
    var i = (typed_data.length - 1) * size + 1;
    typed_data[new C(i)] = value;
  });

  Expect.throws(() {
    typed_data[new C(-1)] = value;
  });
}

void testIndexOutOfRange() {
  testIndexOutOfRangeHelper(new Int8List(3), 0);
  testIndexOutOfRangeHelper(new Uint8List(3), 0);
  testIndexOutOfRangeHelper(new Uint8ClampedList(3), 0);
  testIndexOutOfRangeHelper(new Int16List(3), 0);
  testIndexOutOfRangeHelper(new Uint16List(3), 0);
  testIndexOutOfRangeHelper(new Int32List(3), 0);
  testIndexOutOfRangeHelper(new Uint32List(3), 0);
  testIndexOutOfRangeHelper(new Int64List(3), 0);
  testIndexOutOfRangeHelper(new Uint64List(3), 0);
  testIndexOutOfRangeHelper(new Float32List(3), 0.0);
  testIndexOutOfRangeHelper(new Float64List(3), 0.0);
  testIndexOutOfRangeHelper(new Int64List(3), 0);
  testIndexOutOfRangeHelper(new Uint64List(3), 0);
}

void testIndexOfHelper(list) {
  for (int i = 0; i < list.length; i++) {
    list[i] = i + 10;
  }
  Expect.equals(0, list.indexOf(10));
  Expect.equals(5, list.indexOf(15));
  Expect.equals(9, list.indexOf(19));
  Expect.equals(-1, list.indexOf(20));

  list = new Float32List(10);
  for (int i = 0; i < list.length; i++) {
    list[i] = i + 10.0;
  }
  Expect.equals(0, list.indexOf(10.0));
  Expect.equals(5, list.indexOf(15.0));
  Expect.equals(9, list.indexOf(19.0));
  Expect.equals(-1, list.indexOf(20.0));
}

void testIndexOf() {
  testIndexOfHelper(new Uint8List(10));
  testIndexOfHelper(new Uint8ClampedList(10));
}

testViewCreation() {
  var bytes = new Uint8List(1024).buffer;
  var view;
  view = new Uint8List.view(bytes, 24);
  Expect.equals(1000, view.lengthInBytes);
  view = new Int8List.view(bytes, 24);
  Expect.equals(1000, view.lengthInBytes);
  view = new Uint8ClampedList.view(bytes, 24);
  Expect.equals(1000, view.lengthInBytes);
  view = new Uint16List.view(bytes, 24);
  Expect.equals(1000, view.lengthInBytes);
  view = new Int16List.view(bytes, 24);
  Expect.equals(1000, view.lengthInBytes);
  view = new Uint32List.view(bytes, 24);
  Expect.equals(1000, view.lengthInBytes);
  view = new Int32List.view(bytes, 24);
  Expect.equals(1000, view.lengthInBytes);
  view = new Uint64List.view(bytes, 24);
  Expect.equals(1000, view.lengthInBytes);
  view = new Int64List.view(bytes, 24);
  Expect.equals(1000, view.lengthInBytes);
  view = new Float32List.view(bytes, 24);
  Expect.equals(1000, view.lengthInBytes);
  view = new Float64List.view(bytes, 24);
  Expect.equals(1000, view.lengthInBytes);

  view = bytes.asUint8List(24);
  Expect.equals(1000, view.lengthInBytes);
  view = bytes.asInt8List(24);
  Expect.equals(1000, view.lengthInBytes);
  view = bytes.asUint8ClampedList(24);
  Expect.equals(1000, view.lengthInBytes);
  view = bytes.asUint16List(24);
  Expect.equals(1000, view.lengthInBytes);
  view = bytes.asInt16List(24);
  Expect.equals(1000, view.lengthInBytes);
  view = bytes.asUint32List(24);
  Expect.equals(1000, view.lengthInBytes);
  view = bytes.asInt32List(24);
  Expect.equals(1000, view.lengthInBytes);
  view = bytes.asUint64List(24);
  Expect.equals(1000, view.lengthInBytes);
  view = bytes.asInt64List(24);
  Expect.equals(1000, view.lengthInBytes);
  view = bytes.asFloat32List(24);
  Expect.equals(1000, view.lengthInBytes);
  view = bytes.asFloat64List(24);
  Expect.equals(1000, view.lengthInBytes);

  view = bytes.asUint8List(24, 800);
  Expect.equals(800, view.lengthInBytes);
  view = bytes.asInt8List(24, 800);
  Expect.equals(800, view.lengthInBytes);
  view = bytes.asUint8ClampedList(24, 800);
  Expect.equals(800, view.lengthInBytes);
  view = bytes.asUint16List(24, 400);
  Expect.equals(800, view.lengthInBytes);
  view = bytes.asInt16List(24, 400);
  Expect.equals(800, view.lengthInBytes);
  view = bytes.asUint32List(24, 200 );
  Expect.equals(800, view.lengthInBytes);
  view = bytes.asInt32List(24, 200);
  Expect.equals(800, view.lengthInBytes);
  view = bytes.asUint64List(24, 100);
  Expect.equals(800, view.lengthInBytes);
  view = bytes.asInt64List(24, 100);
  Expect.equals(800, view.lengthInBytes);
  view = bytes.asFloat32List(24, 200);
  Expect.equals(800, view.lengthInBytes);
  view = bytes.asFloat64List(24, 100);
  Expect.equals(800, view.lengthInBytes);
}

testWhere() {
  var bytes = new Uint8List(13);
  bytes.setRange(0, 5, [1, 1, 1, 1, 1]);
  Expect.equals(5, bytes.where((v) => v > 0).length);
}

testCreationFromList() {
  // NOTE: Adding integers > 64bit to the list makes dartino throw ArgumentError.
  var intList =
    [-100000000000000000, -255, -127, 0, 128, 256, 1000000000000000000];
  var intLists = [];
  intLists.add(new Int8List.fromList(intList));
  intLists.add(new Int16List.fromList(intList));
  intLists.add(new Int32List.fromList(intList));
  intLists.add(new Int64List.fromList(intList));
  intLists.add(new Uint8List.fromList(intList));
  intLists.add(new Uint16List.fromList(intList));
  intLists.add(new Uint32List.fromList(intList));
  intLists.add(new Uint64List.fromList(intList));
  var doubleList =
    [-123123123123.123123123123, -123.0, 0.0, 123.0, 123123123123.123123123];
  var doubleLists = [];
  doubleLists.add(new Float32List.fromList(doubleList));
  doubleLists.add(new Float64List.fromList(doubleList));
  for (var ints in intLists) {
    for (var doubles in doubleLists) {
      Expect.throws(() => ints[0] = doubles[0]);
      Expect.throws(() => doubles[0] = ints[0]);
    }
  }
}

void testStrings() {
  test(list) {
    Uint16List uints = new Uint16List(list.length)..setAll(0, list);
    String string = new String.fromCharCodes(list);
    for (int i = 0; i < string.length; i++) {
      for (int j = i; j < string.length; j++) {
        int length = j - i;
        {
          Uint16List copy = new Uint16List(length);
          copy.setRange(0, length, string.codeUnits, i);
          Expect.listEquals(uints.sublist(i, j), copy);
        }
        {
          Uint8List buffer = new Uint8List(length * 2 + 8);
          Uint16List copy = new Uint16List.view(buffer.buffer, 4, length);
          copy.setRange(0, length, string.codeUnits, i);
          Expect.listEquals(uints.sublist(i, j), copy);
        }
        {
          String copy = new String.fromCharCodes(uints, i, j);
          Expect.equals(string.substring(i, j), copy);
        }
      }
    }
  }
  test([]);
  test([0x00, 0x7f, 0xff]);
  test([0x00, 0xdfff, 0xffff]);
  test([0xd800, 0xdc00, 0x20, 0xdbff, 0xdfff]);
}

main() {
  for (int i = 0; i < 20; i++) {
    testCreateUint8TypedData();
    testCreateClampedUint8TypedData();
    testTypedDataRange(false);
    testUnsignedTypedDataRange(false);
    testClampedUnsignedTypedDataRange(false);
    testSetRange();
    testIndexOutOfRange();
    testIndexOf();
  }
  testTypedDataRange(true);
  testUnsignedTypedDataRange(true);
  testViewCreation();
  testWhere();
  testCreationFromList();
  testStrings();
  testSetRange();
}
