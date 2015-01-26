// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.plugins.cc;

import 'dart:core' hide Type;
import 'dart:io';

import 'package:path/path.dart' show basenameWithoutExtension, join;
import 'package:strings/strings.dart' as strings;  // TODO(kasperl): Use this.

import '../parser.dart';

const COPYRIGHT = """
// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
""";

void _writeToFile(String outputDirectory,
                  String path,
                  String extension,
                  String contents) {
  String base = basenameWithoutExtension(path);
  String headerFile = '$base.$extension';
  String headerFilePath = join(outputDirectory, headerFile);
  new File(headerFilePath).writeAsStringSync(contents);
}

void generateHeaderFile(String path, Unit unit, String outputDirectory) {
  _HeaderVisitor visitor = new _HeaderVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  _writeToFile(outputDirectory, path, "h", contents);
}

void generateImplementationFile(String path,
                                Unit unit,
                                String outputDirectory) {
  _ImplementationVisitor visitor = new _ImplementationVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  _writeToFile(outputDirectory, path, "cc", contents);
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

class _ImplementationVisitor extends Visitor {
  final String path;
  final StringBuffer buffer = new StringBuffer();

  int methodId = 1;
  String serviceName;

  _ImplementationVisitor(this.path);

  visit(Node node) => node.accept(this);

  String computeHeaderFile() {
    String base = basenameWithoutExtension(path);
    return '$base.h';
  }

  visitUnit(Unit node) {
    String headerFile = computeHeaderFile();
    buffer.writeln(COPYRIGHT);

    buffer.writeln('// Generated file. Do not edit.');
    buffer.writeln();

    buffer.writeln('#include "$headerFile"');

    node.services.forEach(visit);
  }

  visitService(Service node) {
    buffer.writeln();
    buffer.writeln('static ServiceId _service_id = kNoServiceId;');

    serviceName = node.name;

    buffer.writeln();
    buffer.writeln('void ${serviceName}::Setup() {');
    buffer.writeln('  _service_id = ServiceApiLookup("$serviceName");');
    buffer.writeln('}');

    buffer.writeln();
    buffer.writeln('void ${serviceName}::TearDown() {');
    buffer.writeln('  ServiceApiTerminate(_service_id);');
    buffer.writeln('  _service_id = kNoServiceId;');
    buffer.writeln('}');

    node.methods.forEach(visit);
  }

  visitMethod(Method node) {
    const String type = 'ServiceApiValueType';
    const String ctype = 'ServiceApiCallback';
    String name = node.name;
    String id = '_k${name}Id';

    buffer.writeln();
    buffer.write('static const MethodId $id = ');
    buffer.writeln('reinterpret_cast<MethodId>(${methodId++});');

    buffer.writeln();
    buffer.writeln('$type $serviceName::$name($type arg) {');
    buffer.writeln('  return ServiceApiInvoke(_service_id, $id, arg);');
    buffer.writeln('}');

    buffer.writeln();
    buffer.writeln('void $serviceName::${name}Async($type arg, $ctype cb) {');
    buffer.writeln('  ServiceApiInvokeAsync(_service_id, $id, arg, cb, NULL);');
    buffer.writeln('}');
  }

  visitType(Type node) {
    throw new Exception("Not used.");
  }
}
