// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.compiler;

import 'dart:io';
import 'dart:convert';

import 'src/parser.dart';
import 'src/pretty_printer.dart';
import 'src/resolver.dart';

import 'src/plugins/cc.dart' as cc;
import 'src/plugins/dart.dart' as dart;
import 'src/plugins/java.dart' as java;

void compile(String path, String outputDirectory) {
  List<int> bytes = new File(path).readAsBytesSync();
  String input = UTF8.decode(bytes);

  Unit unit = parseUnit(input);
  resolve(unit);
  dump(path, unit);

  cc.generate(path, unit, outputDirectory);
  dart.generate(path, unit, outputDirectory);
  java.generate(path, unit, outputDirectory);
}

void dump(String path, Unit unit) {
  String banner = "Parsed IDL for $path";
  print(banner);
  print('-' * banner.length);
  var printer = new PrettyPrinter();
  printer.visit(unit);
  String printed = printer.buffer.toString().replaceAll('\n', '\n  ');
  print('  $printed');
}
