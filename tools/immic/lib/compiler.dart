// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library immic.compiler;

import 'dart:io';
import 'dart:convert';

import 'src/parser.dart';
import 'src/resolver.dart';

import 'src/plugins/idl.dart' as idl;
import 'src/plugins/dart.dart' as dart;
import 'src/plugins/objc.dart' as objc;

void compile(String path, String outputDirectory) {
  List<int> bytes = new File(path).readAsBytesSync();
  String input = UTF8.decode(bytes);
  Unit unit = parseUnit(input);
  resolve(unit);
  idl.generate(path, unit, outputDirectory);
  dart.generate(path, unit, outputDirectory);
  objc.generate(path, unit, outputDirectory);
}
