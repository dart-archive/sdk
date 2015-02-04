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

  static Map<String, String> _SETTERS = const {
    'Int16': 'setInt16',
    'Int32': 'setInt32',
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
      String name = listType.identifier;
      Struct element = listType.resolved;
      StructLayout elementLayout = element.layout;
      int elementSize = elementLayout.size;

      writeln();
      writeln('class _${name}List extends ListReader implements List<$name> {');
      writeln('  $name operator[](int index) => '
              'readListElement(new $name(), index, $elementSize);');
      writeln('}');

      writeln();
      writeln('class _${name}BuilderList extends ListBuilder '
              'implements List<${name}Builder> {');
      writeln('  ${name}Builder operator[](int index) => '
              'readListElement(new ${name}Builder(), index, $elementSize);');
      writeln('}');
    }
  }

  writeImplCall(Method method) {
    write('_impl.${method.name}(');
    if (method.inputKind == InputKind.STRUCT) {
      write('getRoot(new ');
      writeType(method.arguments.single.type);
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

    String setInt32() => 'request.setInt32(32, result)';
    String setInt64() => 'request.setInt64(32, result)';

    for (int i = 0; i < methods.length; ++i) {
      Method method = methods[i];
      writeln('      case ${methodIds[i]}:');
      Node resolvedReturnType = method.returnType.resolved;
      if (resolvedReturnType == null) {
        write('        var result = ');
        writeImplCall(method);
        writeln(');');
        writeln('        ${setInt32()};');
      } else {
        StructLayout resultLayout = new StructLayout(resolvedReturnType);
        int size = resultLayout.size;
        writeln('        MessageBuilder mb = new MessageBuilder($size);');
        String builderName = '${method.returnType.identifier}Builder';
        writeln('        $builderName builder = '
                'mb.NewRoot(new $builderName(), $size);');
        write('        ');
        writeImplCall(method);
        write('${method.arguments.length > 0 ? ", " : ""}builder');
        writeln(');');
        writeln('        var result = builder._segment._memory.value;');
        writeln('        ${setInt64()};');
      }
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
    StructLayout layout = node.layout;

    writeln();
    writeln('class ${node.name} extends Reader {');
    for (StructSlot slot in layout.slots) {
      Type type = slot.slot.type;
      if (type.isList) {
        write('  List<');
        writeType(type);
        write('> get ${slot.slot.name} => ');
        neededListTypes.add(type);
        writeln('readList(new _${type.identifier}List(), ${slot.offset});');
      } else if (type.isPrimitive) {
        String getter = _GETTERS[type.identifier];
        String offset = '_offset + ${slot.offset}';

        write('  ');
        writeType(type);
        writeln(' get ${slot.slot.name} => _segment.memory.$getter($offset);');
      } else {
        write('  ');
        writeType(type);
        write(' get ${slot.slot.name} => ');
        write('readStruct(new ');
        writeType(type);
        writeln('(), ${slot.offset});');
      }
    }
    writeln('}');

    writeln();
    writeln('class ${node.name}Builder extends Builder {');
    for (StructSlot slot in layout.slots) {
      String slotName = slot.slot.name;
      Type slotType = slot.slot.type;
      if (slotType.isList) {
        String camel = strings.camelize(strings.underscore(slotName));
        write('  List<');
        writeReturnType(slotType);
        writeln('> New$camel(int length) {');
        Struct element = slotType.resolved;
        StructLayout elementLayout = element.layout;
        int size = elementLayout.size;
        write('    return NewList(new _');
        writeReturnType(slotType);
        writeln('List(), ${slot.offset}, length, $size);');
        writeln('  }');
      } else if (slotType.isPrimitive) {
        String setter = _SETTERS[slotType.identifier];
        write('  void set ${slotName}(');
        writeType(slotType);
        writeln(' value) => $setter(${slot.offset}, value);');
      } else {
        String camel = strings.camelize(strings.underscore(slotName));
        write('  ');
        writeType(slotType);
        write(' New$camel() => ');
        Struct element = slotType.resolved;
        StructLayout elementLayout = element.layout;
        int size = elementLayout.size;
        writeln('NewStruct(${slot.offset}, $size);');
      }
    }
    writeln('}');
  }

  visitMethod(Method node) {
    methods.add(node);
    if (node.outputKind == OutputKind.STRUCT) {
      String builderName = '${node.returnType.identifier}Builder';
      write('  void ${node.name}(');
      visitNodes(node.arguments, (first) => first ? '' : ', ');
      write('${node.arguments.length > 0 ? ", " : ""}$builderName result');
    } else {
      assert(node.outputKind == OutputKind.PRIMITIVE);
      write('  ');
      writeType(node.returnType);
      write(' ${node.name}(');
      visitNodes(node.arguments, (first) => first ? '' : ', ');
    }
    writeln(');');
  }

  visitFormal(Formal node) {
    writeType(node.type);
    write(' ${node.name}');
  }

  static const Map<String, String> _types = const {
    'Int16': 'int',
    'Int32': 'int'
  };

  void writeType(Type node) {
    Node resolved = node.resolved;
    if (resolved != null) {
      write(node.identifier);
    } else {
      Map<String, String> types = const {
        'Int16': 'int',
        'Int32': 'int'
      };
      String type = _types[node.identifier];
      write(type);
    }
  }

  void writeReturnType(Type node) {
    Node resolved = node.resolved;
    if (resolved != null) {
      write('${node.identifier}Builder');
    } else {
      String type = _types[node.identifier];
      write(type);
    }
  }

}
