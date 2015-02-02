// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.plugins.cc;

import 'dart:core' hide Type;

import 'package:path/path.dart' show basenameWithoutExtension, join;

import 'shared.dart';
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

abstract class CcVisitor extends CodeGenerationVisitor {
  CcVisitor(String path) : super(path);

  static String cast(String type, bool cStyle) => cStyle
      ? '($type)'
      : 'reinterpret_cast<$type>';

  visit(Node node) => node.accept(this);

  visitFormal(Formal node) {
    visit(node.type);
    write(' ${node.name}');
  }

  visitType(Type node) {
    Map<String, String> types = const { 'Int32': 'int' };
    String type = types[node.identifier];
    write(type);
  }

  visitArguments(List<Formal> formals) {
    visitNodes(formals, (first) => first ? '' : ', ');
  }

  visitMethodBody(String id, List<Formal> arguments,
                  {bool cStyle: false,
                   List<String> extraArguments: const [],
                   String callback}) {
    final bool async = callback != null;
    const int REQUEST_HEADER_SIZE = 32;
    int size = REQUEST_HEADER_SIZE + (arguments.length * 4);
    if (async) {
      write('  static const int kSize = ');
      writeln('${size} + ${extraArguments.length + 1} * sizeof(void*);');
    } else {
      writeln('  static const int kSize = ${size};');
    }

    String cast(String type) => CcVisitor.cast(type, cStyle);

    String pointerToArgument(int index, int pointers, [String type = 'int']) {
      int offset = REQUEST_HEADER_SIZE + index * 4;
      String prefix = cast('$type*');
      if (pointers == 0) return '$prefix(_buffer + $offset)';
      return '$prefix(_buffer + $offset + $pointers * sizeof(void*))';
   }

    if (async) {
      writeln('  char* _buffer = ${cast("char*")}(malloc(kSize));');
    } else {
      writeln('  char _bits[kSize];');
      writeln('  char* _buffer = _bits;');
    }

    int arity = arguments.length;
    for (int i = 0; i < arity; i++) {
      String name = arguments[i].name;
      writeln('  *${pointerToArgument(i, 0)} = $name;');
    }

    if (async) {
      String dataArgument = pointerToArgument(arity, 0, 'void*');
      writeln('  *$dataArgument = ${cast("void*")}(callback);');
      for (int i = 0; i < extraArguments.length; i++) {
        String dataArgument = pointerToArgument(arity, 1, 'void*');
        String arg = extraArguments[i];
        writeln('  *$dataArgument = ${cast("void*")}($arg);');
      }
      write('  ServiceApiInvokeAsync(_service_id, $id, $callback, ');
      writeln('_buffer, kSize);');
    } else {
      writeln('  ServiceApiInvoke(_service_id, $id, _buffer, kSize);');
      writeln('  return *${pointerToArgument(0, 0)};');
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
    writeln(COPYRIGHT);

    writeln('// Generated file. Do not edit.');
    writeln();

    writeln('#ifndef $headerGuard');
    writeln('#define $headerGuard');

    node.services.forEach(visit);

    writeln();
    writeln('#endif  // $headerGuard');
  }

  visitService(Service node) {
    writeln();
    writeln('class ${node.name} {');
    writeln(' public:');
    writeln('  static void Setup();');
    writeln('  static void TearDown();');

    node.methods.forEach(visit);

    writeln('};');
  }

  visitMethod(Method node) {
    write('  static ');
    visit(node.returnType);
    write(' ${node.name}(');
    visitArguments(node.arguments);
    writeln(');');

    write('  static void ${node.name}Async(');
    visitArguments(node.arguments);
    if (node.arguments.isNotEmpty) write(', ');
    write('void (*callback)(');
    visit(node.returnType);
    writeln('));');
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
    writeln(COPYRIGHT);

    writeln('// Generated file. Do not edit.');
    writeln();

    writeln('#include "$headerFile"');
    writeln('#include "include/service_api.h"');
    writeln('#include <stdlib.h>');

    node.services.forEach(visit);
  }

  visitService(Service node) {
    writeln();
    writeln('static ServiceId _service_id = kNoServiceId;');

    serviceName = node.name;

    writeln();
    writeln('void ${serviceName}::Setup() {');
    writeln('  _service_id = ServiceApiLookup("$serviceName");');
    writeln('}');

    writeln();
    writeln('void ${serviceName}::TearDown() {');
    writeln('  ServiceApiTerminate(_service_id);');
    writeln('  _service_id = kNoServiceId;');
    writeln('}');

    node.methods.forEach(visit);
  }

  visitMethod(Method node) {
    String name = node.name;
    String id = '_k${name}Id';

    writeln();
    write('static const MethodId $id = ');
    writeln('reinterpret_cast<MethodId>(${methodId++});');

    writeln();
    visit(node.returnType);
    write(' $serviceName::${name}(');
    visitArguments(node.arguments);
    writeln(') {');
    visitMethodBody(id, node.arguments);
    writeln('}');

    String callback = ensureCallback(node.returnType, node.arguments);

    writeln();
    write('void $serviceName::${name}Async(');
    visitArguments(node.arguments);
    if (node.arguments.isNotEmpty) write(', ');
    write('void (*callback)(');
    visit(node.returnType);
    writeln(')) {');
    visitMethodBody(id, node.arguments, callback: callback);
    writeln('}');
  }

  final Map<String, String> callbacks = {};
  String ensureCallback(Type type, List<Formal> arguments,
                        {bool cStyle: false}) {
    String key = '${type.identifier}_${arguments.length}';
    return callbacks.putIfAbsent(key, () {
      String cast(String type) => CcVisitor.cast(type, cStyle);
      String name = 'Unwrap_$key';
      writeln();
      writeln('static void $name(void* raw) {');
      writeln('  typedef void (*cbt)(int);');
      writeln('  char* buffer = ${cast('char*')}(raw);');
      writeln('  int result = *${cast('int*')}(buffer + 32);');
      int offset = 32 + (arguments.length * 4);
      writeln('  cbt callback = *${cast('cbt*')}(buffer + $offset);');
      writeln('  free(buffer);');
      writeln('  callback(result);');
      writeln('}');
      return name;
    });
  }
}
