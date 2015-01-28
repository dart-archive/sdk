// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.plugins.cc;

import 'dart:core' hide Type;

import 'package:path/path.dart' show basenameWithoutExtension, join;

import '../parser.dart';
import '../emitter.dart';

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
  String directory = join(outputDirectory, "cc");
  writeToFile(directory, path, "h", contents);
}

void _generateImplementationFile(String path,
                                 Unit unit,
                                 String outputDirectory) {
  _ImplementationVisitor visitor = new _ImplementationVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  String directory = join(outputDirectory, "cc");
  writeToFile(directory, path, "cc", contents);
}

abstract class CcVisitor extends Visitor {
  final String path;
  final StringBuffer buffer = new StringBuffer();
  CcVisitor(this.path);

  static String cast(String type, bool cStyle) => cStyle
      ? '($type)'
      : 'reinterpret_cast<$type>';

  visit(Node node) => node.accept(this);

  visitFormal(Formal node) {
    visit(node.type);
    buffer.write(' ${node.name}');
  }

  visitType(Type node) {
    Map<String, String> types = const { 'Int32': 'int' };
    String type = types[node.identifier];
    buffer.write(type);
  }

  visitArguments(List<Formal> formals) {
    bool first = true;
    formals.forEach((Formal formal) {
      if (!first) buffer.write(', ');
      first = false;
      visit(formal);
    });
  }

  visitMethodBody(String id, List<Formal> arguments,
                  {bool cStyle: false,
                   List<String> extraArguments: const [],
                   String callback}) {
    final bool async = callback != null;
    const int REQUEST_HEADER_SIZE = 32;
    int size = REQUEST_HEADER_SIZE + (arguments.length * 4);
    if (async) {
      buffer.write('  static const int kSize = ');
      buffer.writeln('${size} + ${extraArguments.length + 1} * sizeof(void*);');
    } else {
      buffer.writeln('  static const int kSize = ${size};');
    }

    String cast(String type) => CcVisitor.cast(type, cStyle);

    String pointerToArgument(int index, int pointers, [String type = 'int']) {
      int offset = REQUEST_HEADER_SIZE + index * 4;
      String prefix = cast('$type*');
      if (pointers == 0) return '$prefix(_buffer + $offset)';
      return '$prefix(_buffer + $offset + $pointers * sizeof(void*))';
   }

    if (async) {
      buffer.writeln('  char* _buffer = ${cast("char*")}(malloc(kSize));');
    } else {
      buffer.writeln('  char _bits[kSize];');
      buffer.writeln('  char* _buffer = _bits;');
    }

    int arity = arguments.length;
    for (int i = 0; i < arity; i++) {
      String name = arguments[i].name;
      buffer.writeln('  *${pointerToArgument(i, 0)} = $name;');
    }

    if (async) {
      String dataArgument = pointerToArgument(arity, 0, 'void*');
      buffer.writeln('  *$dataArgument = ${cast("void*")}(callback);');
      for (int i = 0; i < extraArguments.length; i++) {
        String dataArgument = pointerToArgument(arity, 1, 'void*');
        String arg = extraArguments[i];
        buffer.writeln('  *$dataArgument = ${cast("void*")}($arg);');
      }
      buffer.write('  ServiceApiInvokeAsync(_service_id, $id, $callback, ');
      buffer.writeln('_buffer, kSize);');
    } else {
      buffer.writeln('  ServiceApiInvoke(_service_id, $id, _buffer, kSize);');
      buffer.writeln('  return *${pointerToArgument(0, 0)};');
    }
  }
}

class _HeaderVisitor extends CcVisitor {
  _HeaderVisitor(String path) : super(path);

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
    buffer.write('  static ');
    visit(node.returnType);
    buffer.write(' ${node.name}(');
    visitArguments(node.arguments);
    buffer.writeln(');');

    buffer.write('  static void ${node.name}Async(');
    visitArguments(node.arguments);
    if (node.arguments.isNotEmpty) buffer.write(', ');
    buffer.write('void (*callback)(');
    visit(node.returnType);
    buffer.writeln('));');
  }
}

class _ImplementationVisitor extends CcVisitor {
  int methodId = 1;
  String serviceName;

  _ImplementationVisitor(String path) : super(path);

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
    buffer.writeln('#include <stdlib.h>');

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
    String name = node.name;
    String id = '_k${name}Id';

    buffer.writeln();
    buffer.write('static const MethodId $id = ');
    buffer.writeln('reinterpret_cast<MethodId>(${methodId++});');

    buffer.writeln();
    visit(node.returnType);
    buffer.write(' $serviceName::${name}(');
    visitArguments(node.arguments);
    buffer.writeln(') {');
    visitMethodBody(id, node.arguments);
    buffer.writeln('}');

    String callback = ensureCallback(node.returnType, node.arguments);

    buffer.writeln();
    buffer.write('void $serviceName::${name}Async(');
    visitArguments(node.arguments);
    if (node.arguments.isNotEmpty) buffer.write(', ');
    buffer.write('void (*callback)(');
    visit(node.returnType);
    buffer.writeln(')) {');
    visitMethodBody(id, node.arguments, callback: callback);
    buffer.writeln('}');
  }

  final Map<String, String> callbacks = {};
  String ensureCallback(Type type, List<Formal> arguments,
                        {bool cStyle: false}) {
    String key = '${type.identifier}_${arguments.length}';
    return callbacks.putIfAbsent(key, () {
      String cast(String type) => CcVisitor.cast(type, cStyle);
      String name = 'Unwrap_$key';
      buffer.writeln();
      buffer.writeln('static void $name(void* raw) {');
      buffer.writeln('  typedef void (*cbt)(int);');
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
