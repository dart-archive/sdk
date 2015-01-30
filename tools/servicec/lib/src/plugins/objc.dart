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

void generate(String path, Unit unit, String outputDirectory) {
  _generateHeaderFile(path, unit, outputDirectory);
  _generateImplementationFile(path, unit, outputDirectory);
}

void _generateHeaderFile(String path, Unit unit, String outputDirectory) {
  _HeaderVisitor visitor = new _HeaderVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  String directory = join(outputDirectory, 'objc');
  writeToFile(directory, path, "h", contents);
}

void _generateImplementationFile(String path,
                                 Unit unit,
                                 String outputDirectory) {
  _ImplementationVisitor visitor = new _ImplementationVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  String directory = join(outputDirectory, 'objc');
  writeToFile(directory, path, "m", contents);
}

abstract class _ObjcVisitor extends CcVisitor {
  _ObjcVisitor(String path) : super(path);

  visitFormal(Formal node) {
    buffer.write('(');
    visit(node.type);
    buffer.write(')${node.name}');
  }

  visitArguments(List<Formals> arguments) {
    visitNodes(arguments, (first) => first ? ':' : ' with:');
  }
}

class _HeaderVisitor extends _ObjcVisitor {
  _HeaderVisitor(String path) : super(path);

  visit(Node node) => node.accept(this);

  visitUnit(Unit node) {
    buffer.writeln(COPYRIGHT);

    buffer.writeln('// Generated file. Do not edit.');
    buffer.writeln();

    buffer.writeln('#include <Foundation/Foundation.h>');

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
    String name = node.name;
    buffer.write('+ (');
    visit(node.returnType);
    buffer.write(')${name}');
    visitArguments(node.arguments);
    buffer.writeln(';');

    // TODO(ager): Methods with no arguments and a callback.
    buffer.write('+ (void)${name}Async');
    visitArguments(node.arguments);
    buffer.writeln(' withCallback:(void (*)(int))callback;');

    // TODO(ager): Methods with no arguments and a callback.
    buffer.write('+ (void)${name}Async');
    visitArguments(node.arguments);
    buffer.writeln(' withBlock:(void (^)(int))callback;');
  }
}

class _ImplementationVisitor extends _ObjcVisitor {
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
    buffer.writeln('#include "include/service_api.h"');

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

    int arity = node.arguments.length;

    buffer.writeln();
    buffer.writeln('static const MethodId $id = (MethodId)${methodId++};');

    buffer.writeln();
    buffer.write('+ (');
    visit(node.returnType);
    buffer.write(')$name');
    visitArguments(node.arguments);
    buffer.writeln(' {');
    visitMethodBody(id, node.arguments, cStyle: true);
    buffer.writeln('}');

    String callback = ensureCallback(node.returnType, node.arguments, false);
    buffer.writeln();
    buffer.write('+ (void)${name}Async');
    visitArguments(node.arguments);
    buffer.writeln(' withCallback:(void (*)(int))callback {');
    visitMethodBody(id, node.arguments, cStyle: true, callback: callback);
    buffer.writeln('}');

    callback = ensureCallback(node.returnType, node.arguments, true);
    buffer.writeln();
    buffer.write('+ (void)${name}Async');
    visitArguments(node.arguments);
    buffer.writeln(' withBlock:(void (^)(int))callback {');
    visitMethodBody(id, node.arguments, cStyle: true, callback: callback);
    buffer.writeln('}');
  }

  final Map<String, String> callbacks = {};
  String ensureCallback(Type type, List<Formal> arguments, bool block) {
    String suffix = block ? "_Block" : "";
    String key = '${type.identifier}_${arguments.length}$suffix';
    return callbacks.putIfAbsent(key, () {
      String cast(String type) => CcVisitor.cast(type, true);
      String name = 'Unwrap_$key';
      buffer.writeln();
      buffer.writeln('static void $name(void* raw) {');
      buffer.writeln('  typedef void (${block ? "^" : "*"}cbt)(int);');
      buffer.writeln('  char* buffer = ${cast('char*')}(raw);');
      buffer.writeln('  int result = *${cast('int*')}(buffer + 32);');
      int offset = 32 + (arguments.length * 4);
      buffer.writeln('  cbt callback = *${cast('cbt*')}(buffer + $offset);');
      buffer.writeln('  free(buffer);');
      buffer.writeln('  callback(result);');
      buffer.writeln('}');
      return name;
    });
  }
}
