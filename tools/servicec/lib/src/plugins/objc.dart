// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.plugins.objc;

import 'dart:core' hide Type;

import 'package:path/path.dart' show basenameWithoutExtension, join;

import '../emitter.dart';
import '../parser.dart';
import 'cc.dart' show CcVisitor;

const COPYRIGHT = """
// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
""";

const String _type = 'ServiceApiValueType';
const String _ctype = 'ServiceApiCallback';
const String _btype = 'ServiceApiBlock';

void generateHeaderFile(String path, Unit unit, String outputDirectory) {
  _HeaderVisitor visitor = new _HeaderVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  String directory = join(outputDirectory, 'objc');
  writeToFile(directory, path, "h", contents);
}

void generateImplementationFile(String path,
                                Unit unit,
                                String outputDirectory) {
  _ImplementationVisitor visitor = new _ImplementationVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  String directory = join(outputDirectory, 'objc');
  writeToFile(directory, path, "m", contents);
}

class _HeaderVisitor extends CcVisitor {
  _HeaderVisitor(String path) : super(path);

  visit(Node node) => node.accept(this);

  visitUnit(Unit node) {
    buffer.writeln(COPYRIGHT);

    buffer.writeln('// Generated file. Do not edit.');
    buffer.writeln();

    buffer.writeln('#include <Foundation/Foundation.h>');
    buffer.writeln();

    buffer.writeln('#include "include/service_api.h"');
    buffer.writeln();

    buffer.writeln('typedef void (^ServiceApiBlock)(ServiceApiValueType);');

    node.services.forEach(visit);
  }

  visitService(Service node) {
    buffer.writeln();
    buffer.writeln('@interface ${node.name} : NSObject');
    buffer.writeln();
    buffer.writeln('+ (void)Setup;');
    buffer.writeln('+ (void)TearDown;');
    buffer.writeln();

    node.methods.forEach(visit);

    buffer.writeln();
    buffer.writeln('@end');
  }

  visitMethod(Method node) {
    if (node.arguments.length != 1) return;

    String name = node.name;
    buffer.writeln('+ ($_type)$name:($_type)arg;');
    buffer.writeln('+ (void)${name}Async:($_type)arg WithCallback:($_ctype)cb;');
    buffer.writeln('+ (void)${name}Async:($_type)arg WithBlock:($_btype)block;');
  }

  visitFormal(Formal node) {
    throw new Exception("Not used.");
  }

  visitType(Type node) {
    throw new Exception("Not used.");
  }
}

class _ImplementationVisitor extends CcVisitor {
  int methodId = 1;
  String serviceName;

  _ImplementationVisitor(String path) : super(path);

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
    buffer.writeln();

    buffer.writeln('static void _BlockCallback($_type result, void* data) {');
    buffer.writeln('  ((ServiceApiBlock)data)(result);');
    buffer.writeln('}');

    node.services.forEach(visit);
  }

  visitService(Service node) {
    buffer.writeln();
    buffer.writeln('static ServiceId _service_id;');

    serviceName = node.name;

    buffer.writeln();
    buffer.writeln('@implementation $serviceName');

    buffer.writeln();
    buffer.writeln('+ (void)Setup {');
    buffer.writeln('  _service_id = kNoServiceId;');
    buffer.writeln('  _service_id = ServiceApiLookup("$serviceName");');
    buffer.writeln('}');

    buffer.writeln();
    buffer.writeln('+ (void)TearDown {');
    buffer.writeln('  ServiceApiTerminate(_service_id);');
    buffer.writeln('  _service_id = kNoServiceId;');
    buffer.writeln('}');

    node.methods.forEach(visit);

    buffer.writeln();
    buffer.writeln('@end');
  }

  visitMethod(Method node) {
    String name = node.name;
    String id = '_k${name}Id';
    String sid = '_service_id';

    buffer.writeln();
    buffer.writeln('static const MethodId $id = (MethodId)${methodId++};');

    if (node.arguments.length != 1) return;

    buffer.writeln();
    buffer.write('+ (');
    visit(node.returnType);
    buffer.write(')$name:');
    visit(node.arguments.single);
    buffer.writeln(' {');
    visitMethodBody(id, node.arguments);
    buffer.writeln('}');

    buffer.writeln();
    buffer.writeln('+ (void)${name}Async:($_type)arg '
                   'WithCallback:($_ctype)cb {');
    buffer.writeln('  ServiceApiInvokeAsync($sid, $id, arg, cb, (void*)0);');
    buffer.writeln('}');

    buffer.writeln();
    buffer.writeln('+ (void)${name}Async:($_type)arg '
                   'WithBlock:($_btype)block {');
    buffer.writeln('  ServiceApiInvokeAsync($sid, $id, arg, '
                   '_BlockCallback, (void*)block);');
    buffer.writeln('}');
  }

  visitFormal(Formal node) {
    buffer.write('(');
    visit(node.type);
    buffer.write(')${node.name}');
  }
}
