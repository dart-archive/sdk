// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io';
import 'dart:convert';

import 'parser.dart';
import 'primitives.dart' as primitives;
import 'struct_layout.dart';

import 'package:path/path.dart' show join, dirname;

Future<Map> parseImports(Unit unit, ImportResolver resolver, context) async {
  Map units = {};
  await ImportParser.parse(unit, resolver, context, units);
  return units;
}

abstract class ImportResolver<Context> {
  Context resolve(Import import, Context context);
  Future<String> read(Context context);
}

class ImportParser<Context> extends Visitor {
  final ImportResolver resolver;
  final Context context;
  final Map<Context, Unit> units;

  static parse(Unit unit, ImportResolver resolver, Context context, Map units) {
    var parser = new ImportParser(resolver, context, units);
    return parser.visitUnit(unit);
  }

  ImportParser(this.resolver, this.context, this.units);

  visitUnit(Unit unit) async {
    units[context] = unit;
    for (var import in unit.imports) {
      await visitImport(import);
    }
  }

  visitImport(Import import) async {
    var newContext = resolver.resolve(import, context);
    if (newContext != null) {
      String input = await resolver.read(newContext);
      Unit unit = parseUnit(input);
      await parse(unit, resolver, newContext, units);
    }
  }
}
