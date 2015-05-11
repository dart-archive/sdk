// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io';
import 'dart:convert';

import 'parser.dart';
import 'primitives.dart' as primitives;
import 'struct_layout.dart';

import 'package:path/path.dart' show join, dirname;

Map<String, Unit> parseImports(Unit unit,
                               String path,
                               String packageDirectory) {
  Map<String, Unit> units = <String,Unit>{};
  ImportParser.parse(unit, path, packageDirectory, units);
  return units;
}

class ImportParser extends Visitor {
  final String unitPath;
  final String packageDirectory;
  final Map<String, Unit> units;

  static parse(Unit unit,
               String unitPath,
               String packageDirectory,
               Map<String, Unit> units) {
    var parser = new ImportParser(unitPath, packageDirectory, units);
    parser.visit(unit);
  }

  ImportParser(this.unitPath, this.packageDirectory, this.units);

  visit(Node node) => node.accept(this);

  visitUnit(Unit unit) {
    // TODO(zerny): Canonicalize the file path!
    if (!units.containsKey(unitPath)) {
      unit.imports.forEach(visit);
      units[unitPath] = unit;
    }
  }

  visitImport(Import import) {
    String importPath;
    if (import.prefix == 'package') {
      importPath = join(packageDirectory, import.file);
    } else {
      importPath = join(dirname(unitPath), import.file);
    }
    List<int> bytes = new File(importPath).readAsBytesSync();
    String input = UTF8.decode(bytes);
    Unit unit = parseUnit(input);
    parse(unit, importPath, packageDirectory, units);
  }
}
