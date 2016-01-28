// Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library old_servicec.compiler;

import 'dart:io';

import 'src/emitter.dart';
import 'src/parser.dart';
import 'src/pretty_printer.dart';
import 'src/resolver.dart';

import 'src/plugins/cc.dart' as cc;
import 'src/plugins/dart.dart' as dart;
import 'src/plugins/java.dart' as java;

import 'package:path/path.dart' show join, dirname;

const List<String> RESOURCES = const [
  "Service.podspec",
];

void compile(String path,
             Unit unit,
             String resourcesDirectory,
             String outputDirectory) {
  resolve(unit);
  dump(path, unit);

  cc.generate(path, unit, resourcesDirectory, outputDirectory);
  dart.generate(path, unit, resourcesDirectory, outputDirectory);
  java.generate(path, unit, resourcesDirectory, outputDirectory);

  for (String resource in RESOURCES) {
    String resourcePath = join(resourcesDirectory, resource);
    File file = new File(resourcePath);
    String contents = file.readAsStringSync();
    writeToFile(outputDirectory, resource, contents);
  }
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
