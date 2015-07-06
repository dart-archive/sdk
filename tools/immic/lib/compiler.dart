// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library immic.compiler;

import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;

import 'src/parser.dart';
import 'src/resolver.dart';
import 'src/importer.dart';

import 'src/plugins/idl.dart' as idl;
import 'src/plugins/dart.dart' as dart;
import 'src/plugins/objc.dart' as objc;

class ImportResolverWithPackageRoot implements ImportResolver<String> {
  final String packageDirectory;
  final Set<String> visited = new Set();

  ImportResolverWithPackageRoot(this.packageDirectory);

  Future<String> read(String importPath) async {
    List<int> bytes = new File(importPath).readAsBytesSync();
    return UTF8.decode(bytes);
  }

  String resolve(Import import, String unitPath) {
    String importPath;
    if (import.package != null) {
      importPath = p.join(packageDirectory, import.package, import.path);
    } else {
      importPath = p.join(p.dirname(unitPath), import.path);
    }
    // TODO(zerny): Canonicalize unit paths.
    if (visited.contains(importPath)) return null;
    visited.add(importPath);
    return importPath;
  }
}

void compile(String path,
             String outputDirectory,
             String packageDirectory) async {
  List<int> bytes = new File(path).readAsBytesSync();
  String input = UTF8.decode(bytes);
  Unit topUnit = parseUnit(input);
  Map<String, Unit> units = await parseImports(
      topUnit, new ImportResolverWithPackageRoot(packageDirectory), path);

  resolve(units);
  idl.generate(path, units, outputDirectory);
  objc.generate(path, units, outputDirectory);
}
