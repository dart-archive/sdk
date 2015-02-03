// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.plugins.dart;

import 'dart:core' hide Type;

import 'package:path/path.dart' show basenameWithoutExtension, join;
import 'package:strings/strings.dart' as strings;

import 'shared.dart';
import '../emitter.dart';
import '../struct_layout.dart';

const COPYRIGHT = """
// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
""";

void generate(String path, Unit unit, String outputDirectory) {
  _DartVisitor visitor = new _DartVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  String directory = join(outputDirectory, 'dart');
  writeToFile(directory, path, "dart", contents);
}

class _DartVisitor extends CodeGenerationVisitor {
  final Set<Type> neededListTypes = new Set<Type>();
  final List<Method> methods = new List();
  _DartVisitor(String path) : super(path);

  static Map<String, String> _GETTERS = const {
    'Int16': 'getInt16',
    'Int32': 'getInt32',
  };

  visitUnit(Unit node) {
    writeln(COPYRIGHT);

    writeln('// Generated file. Do not edit.');
    writeln();

    String libraryName = basenameWithoutExtension(path);
    writeln('library $libraryName;');
    writeln();

    writeln('import "dart:ffi";');
    writeln('import "dart:service" as service;');
    if (node.structs.isNotEmpty) {
      writeln('import "struct.dart";');
    }
    writeln();

    writeln('final Channel _channel = new Channel();');
    writeln('final Port _port = new Port(_channel);');
    write('final Foreign _postResult = ');
    writeln('Foreign.lookup("PostResultToService");');

    node.services.forEach(visit);
    node.structs.forEach(visit);

    for (Type listType in neededListTypes) {
      writeln('');
      String name = listType.identifier;
      writeln('class _${name}List extends ListReader implements List<$name> {');

      StructLayout targetLayout = new StructLayout(listType.resolved);
      int targetSize = targetLayout.size;
      writeln('  $name operator[](int index) => '
              'readListElement(new $name(), index, $targetSize);');

      writeln('}');
    }
  }

  visitService(Service node) {
    String serviceName = node.name;

    writeln();
    writeln('bool _terminated = false;');
    writeln('$serviceName _impl;');

    writeln();
    writeln('abstract class $serviceName {');

    node.methods.forEach(visit);

    writeln();
    writeln('  static void initialize($serviceName impl) {');
    writeln('    if (_impl != null) {');
    writeln('      throw new UnsupportedError();');
    writeln('    }');
    writeln('    _impl = impl;');
    writeln('    _terminated = false;');
    writeln('    service.register("$serviceName", _port);');
    writeln('  }');

    writeln();
    writeln('  static bool hasNextEvent() {');
    writeln('    return !_terminated;');
    writeln('  }');


    List<String> methodIds = methods.map((method) =>
        '_${strings.underscore(method.name).toUpperCase()}_METHOD_ID')
        .toList();

    writeln();
    writeln('  static void handleNextEvent() {');
    writeln('    var request = _channel.receive();');
    writeln('    switch (request.getInt32(0)) {');
    writeln('      case _TERMINATE_METHOD_ID:');
    writeln('        _terminated = true;');
    writeln('        _postResult.icall\$1(request);');
    writeln('        break;');

    String setInt(int index) => 'request.setInt32(${32 + index * 4}, result)';

    for (int i = 0; i < methods.length; ++i) {
      Method method = methods[i];
      writeln('      case ${methodIds[i]}:');
      write('        var result = _impl.${method.name}(');
      if (method.inputKind == InputKind.STRUCT) {
        write('getRoot(new ');
        visit(method.arguments.single.type);
        write('(), request)');
      } else {
        assert(method.inputKind == InputKind.PRIMITIVES);
        StructLayout inputLayout = method.inputPrimitiveStructLayout;

        for (int i = 0; i < method.arguments.length; i++) {
          if (i != 0) write(', ');
          Formal argument = method.arguments[i];
          String getter = _GETTERS[argument.type.identifier];
          int offset = inputLayout[argument].offset + 32;
          write('request.$getter($offset)');
        }
      }
      writeln(');');
      writeln('        ${setInt(0)};');
      writeln('        _postResult.icall\$1(request);');
      writeln('        break;');
    }
    writeln('      default:');
    writeln('        throw UnsupportedError();');
    writeln('    }');
    writeln('  }');

    writeln();
    int nextId = 0;
    writeln('  const int _TERMINATE_METHOD_ID = ${nextId++};');
    for (String id in methodIds) {
      writeln('  const int $id = ${nextId++};');
    }

    writeln('}');
  }

  visitStruct(Struct node) {
    StructLayout layout = new StructLayout(node);

    writeln();
    writeln('class ${node.name} extends Reader {');

    for (StructSlot slot in layout.slots) {
      Type type = slot.slot.type;

      if (type.isList) {
        write('  List<');
        visit(type);
        write('> get ${slot.slot.name} => ');
        neededListTypes.add(type);
        writeln('readList(new _${type.identifier}List(), ${slot.offset});');
      } else if (type.isPrimitive) {
        String getter = _GETTERS[type.identifier];
        String offset = '_offset + ${slot.offset}';

        write('  ');
        visit(type);
        writeln(' get ${slot.slot.name} => _segment.memory.$getter($offset);');
      }
    }

    writeln('}');
  }

  visitMethod(Method node) {
    methods.add(node);
    write('  int ${node.name}(');
    visitNodes(node.arguments, (first) => first ? '' : ', ');
    writeln(');');
  }

  visitFormal(Formal node) {
    visit(node.type);
    write(' ${node.name}');
  }

  visitType(Type node) {
    Node resolved = node.resolved;
    if (resolved != null) {
      write(node.identifier);
    } else {
      Map<String, String> types = const {
        'Int16': 'int',
        'Int32': 'int'
      };
      String type = types[node.identifier];
      write(type);
    }
  }
}

