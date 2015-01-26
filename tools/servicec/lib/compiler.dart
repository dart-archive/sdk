// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.compiler;

import 'dart:io';
import 'dart:convert';

import 'src/parser.dart';
import 'src/plugins/cc.dart' as cc;
import 'src/plugins/dart.dart' as dart;
import 'src/plugins/objc.dart' as objc;

void compile(String path, String outputDirectory) {
  List<int> bytes = new File(path).readAsBytesSync();
  String input = UTF8.decode(bytes);

  Unit unit = parseUnit(input);
  // TODO(kasperl): Perform static semantic analysis.

  cc.generateHeaderFile(path, unit, outputDirectory);
  cc.generateImplementationFile(path, unit, outputDirectory);

  dart.generate(path, unit, outputDirectory);

  objc.generateHeaderFile(path, unit, outputDirectory);
  objc.generateImplementationFile(path, unit, outputDirectory);
}
