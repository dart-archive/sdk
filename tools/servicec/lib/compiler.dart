// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.compiler;

import 'dart:io';
import 'dart:convert';

import 'src/parser.dart';
import 'src/pretty_printer.dart';

void compile(String path) {
  List<int> bytes = new File(path).readAsBytesSync();
  String input = UTF8.decode(bytes);

  Unit unit = parseUnit(input);
  PrettyPrinter printer = new PrettyPrinter()
      ..visit(unit);
  print(printer.buffer);
}
