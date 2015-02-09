// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.plugins.objc;

import 'dart:core' hide Type;

import 'package:path/path.dart' show basenameWithoutExtension, join;

import '../emitter.dart';
import '../struct_layout.dart';

import 'shared.dart';
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
    write('(');
    writeType(node.type);
    write(')${node.name}');
  }

  visitArguments(List<Formal> arguments) {
    visitNodes(arguments, (first) => first ? ':' : ' with:');
  }
}

class _HeaderVisitor extends _ObjcVisitor {
  _HeaderVisitor(String path) : super(path);

  visitUnit(Unit node) {
    writeln(COPYRIGHT);

    writeln('// Generated file. Do not edit.');
    writeln();

    writeln('#include <Foundation/Foundation.h>');

    node.services.forEach(visit);
  }

  visitService(Service node) {
    writeln();
    writeln('@interface ${node.name} : NSObject');
    writeln();
    writeln('+ (void)Setup;');
    writeln('+ (void)TearDown;');
    writeln();

    node.methods.forEach(visit);

    writeln();
    writeln('@end');
  }

  visitMethod(Method node) {
    String name = node.name;
    write('+ (');
    writeType(node.returnType);
    write(')${name}');
    visitArguments(node.arguments);
    writeln(';');

    // TODO(ager): Methods with no arguments and a callback.
    write('+ (void)${name}Async');
    visitArguments(node.arguments);
    writeln(' withCallback:(void (*)(int))callback;');

    // TODO(ager): Methods with no arguments and a callback.
    write('+ (void)${name}Async');
    visitArguments(node.arguments);
    writeln(' withBlock:(void (^)(int))callback;');
  }
}

class _ImplementationVisitor extends _ObjcVisitor {
  int methodId = 1;
  String serviceName;

  _ImplementationVisitor(String path) : super(path);

  String computeHeaderFile() {
    String base = basenameWithoutExtension(path);
    return '$base.h';
  }

  visitUnit(Unit node) {
    String headerFile = computeHeaderFile();
    writeln(COPYRIGHT);

    writeln('// Generated file. Do not edit.');
    writeln();

    writeln('#include "$headerFile"');
    writeln('#include "include/service_api.h"');

    node.services.forEach(visit);
  }

  visitService(Service node) {
    writeln();
    writeln('static ServiceId _service_id;');

    serviceName = node.name;

    writeln();
    writeln('@implementation $serviceName');

    writeln();
    writeln('+ (void)Setup {');
    writeln('  _service_id = kNoServiceId;');
    writeln('  _service_id = ServiceApiLookup("$serviceName");');
    writeln('}');

    writeln();
    writeln('+ (void)TearDown {');
    writeln('  ServiceApiTerminate(_service_id);');
    writeln('  _service_id = kNoServiceId;');
    writeln('}');

    node.methods.forEach(visit);

    writeln();
    writeln('@end');
  }

  visitMethod(Method node) {
    String name = node.name;
    String camel = camelize(name);
    String id = 'k${camel}Id_';

    writeln();
    writeln('static const MethodId $id = (MethodId)${methodId++};');

    if (node.inputKind != InputKind.PRIMITIVES) return;  // Not handled yet.

    StructLayout layout = node.inputPrimitiveStructLayout;
    writeln();
    write('+ (');
    writeType(node.returnType);
    write(')$name');
    visitArguments(node.arguments);
    writeln(' {');
    visitMethodBody(id, node, cStyle: true);
    writeln('}');

    String callback = ensureCallback(node.returnType, layout, false);
    writeln();
    write('+ (void)${name}Async');
    visitArguments(node.arguments);
    writeln(' withCallback:(void (*)(int))callback {');
    visitMethodBody(id, node, cStyle: true, callback: callback);
    writeln('}');

    callback = ensureCallback(node.returnType, layout, true);
    writeln();
    write('+ (void)${name}Async');
    visitArguments(node.arguments);
    writeln(' withBlock:(void (^)(int))callback {');
    visitMethodBody(id, node, cStyle: true, callback: callback);
    writeln('}');
  }

  final Map<String, String> callbacks = {};
  String ensureCallback(Type type, StructLayout layout, bool block) {
    String suffix = block ? "_Block" : "";
    String key = '${type.identifier}_${layout.size}$suffix';
    return callbacks.putIfAbsent(key, () {
      String cast(String type) => CcVisitor.cast(type, true);
      String name = 'Unwrap_$key';
      writeln();
      writeln('static void $name(void* raw) {');
      writeln('  typedef void (${block ? "^" : "*"}cbt)(int);');
      writeln('  char* buffer = ${cast('char*')}(raw);');
      writeln('  int result = *${cast('int*')}(buffer + 32);');
      int offset = 32 + layout.size;
      writeln('  cbt callback = *${cast('cbt*')}(buffer + $offset);');
      writeln('  free(buffer);');
      writeln('  callback(result);');
      writeln('}');
      return name;
    });
  }
}
