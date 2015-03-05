// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io';

import 'package:expect/expect.dart';

import '../json.dart';

void main() {
  testParser();
}

void testParser() {
  Expect.equals(null, new JsonParser('null').parse());
  Expect.equals(true, new JsonParser('true').parse());
  Expect.equals(false, new JsonParser('false').parse());
  Expect.equals(42, new JsonParser('42').parse());
  Expect.equals("hello world", new JsonParser('"hello world"').parse());

  Expect.listEquals([], new JsonParser('[]').parse());
  Expect.listEquals([], new JsonParser(' [ ] ').parse());
  Expect.listEquals([42], new JsonParser('[42]').parse());
  Expect.listEquals([42], new JsonParser(' [ 42 ] ').parse());

  Expect.listEquals(
    [true, "hello world", 42],
    new JsonParser('[true,"hello world",42]').parse());

  Expect.listEquals(
    [true, "hello world", 42],
    new JsonParser(' [ true , "hello world" , 42 ] ').parse());

  Expect.throws(() => new JsonParser('[1 2 3]').parse());

  Expect.mapEquals({}, new JsonParser('{}').parse());
  Expect.mapEquals({}, new JsonParser(' { } ').parse());
  Expect.mapEquals({"x":42}, new JsonParser('{"x":42}').parse());
  Expect.mapEquals({"x":42}, new JsonParser(' { "x" : 42 } ').parse());

  Expect.mapEquals(
    {"foo":true, "bar":"hello world", "baz":42},
    new JsonParser('{"foo":true,"bar":"hello world","baz":42}').parse());

  Expect.mapEquals(
     {"foo":true, "bar":"hello world", "baz":42},
     new JsonParser(' { "foo" :\t true , "bar" : "hello world" , "baz" : 42 } ')
   .parse());

  Expect.throws(() => new JsonParser('{"x"}').parse());
  Expect.throws(() => new JsonParser('{42}').parse());
  Expect.throws(() => new JsonParser('{"x":1 "y":2}').parse());
}
