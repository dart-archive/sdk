// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.plugins.cc;

import 'dart:core' hide Type;

import 'package:path/path.dart' show basenameWithoutExtension;
import 'package:strings/strings.dart' as strings;  // TODO(kasperl): Use this.

import '../parser.dart';

const COPYRIGHT = """
// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
""";

String generateHeaderFile(String path, Unit unit) {
  _HeaderVisitor visitor = new _HeaderVisitor(path);
  visitor.visit(unit);
  return visitor.buffer.toString();
}

class _HeaderVisitor extends Visitor {
  final String path;
  final StringBuffer buffer = new StringBuffer();
  _HeaderVisitor(this.path);

  visit(Node node) => node.accept(this);

  String computeHeaderGuard() {
    String base = basenameWithoutExtension(path).toUpperCase();
    return '${base}_H';
  }

  visitUnit(Unit node) {
    String headerGuard = computeHeaderGuard();
    buffer.writeln(COPYRIGHT);

    buffer.writeln('// Generated file. Do not edit.');
    buffer.writeln();

    buffer.writeln('#ifndef $headerGuard');
    buffer.writeln('#define $headerGuard');
    buffer.writeln();

    buffer.writeln('#include "include/service_api.h"');

    node.services.forEach(visit);

    buffer.writeln();
    buffer.writeln('#endif  // $headerGuard');
  }

  visitService(Service node) {
    buffer.writeln();
    buffer.writeln('class ${node.name} {');
    buffer.writeln(' public:');
    buffer.writeln('  static void Setup();');
    buffer.writeln('  static void TearDown();');

    node.methods.forEach(visit);

    buffer.writeln('};');
  }

  visitMethod(Method node) {
    const String type = 'ServiceApiValueType';
    const String ctype = 'ServiceApiCallback';
    String name = node.name;
    buffer.writeln('  static $type $name($type arg);');
    buffer.writeln('  static void ${name}Async($type arg, $ctype callback);');
  }

  visitType(Type node) {
    throw new Exception("Not used.");
  }
}
