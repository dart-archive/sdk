// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.plugins.dart;

import 'dart:core' hide Type;
import 'dart:io' show Platform, File;

import 'package:path/path.dart' show basenameWithoutExtension, join, dirname;
import 'package:strings/strings.dart' as strings;

import 'shared.dart';
import '../emitter.dart';
import '../struct_layout.dart';
import '../primitives.dart' as primitives;

const COPYRIGHT = """
// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
""";

const List<String> RESOURCES = const [
  "struct.dart",
];

void generate(String path, Unit unit, String outputDirectory) {
  _DartVisitor visitor = new _DartVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  String directory = join(outputDirectory, 'dart');
  writeToFile(directory, path, contents, extension: 'dart');

  String resourcesDirectory = join(dirname(Platform.script.path),
      '..', 'lib', 'src', 'resources', 'dart');
  for (String resource in RESOURCES) {
    String resourcePath = join(resourcesDirectory, resource);
    File file = new File(resourcePath);
    String contents = file.readAsStringSync();
    writeToFile(directory, resource, contents);
  }
}

class _DartVisitor extends CodeGenerationVisitor {
  final Set<Type> neededListTypes = new Set<Type>();
  final List<Method> methods = new List();
  _DartVisitor(String path) : super(path);

  static Map<String, String> _GETTERS = const {
    'bool'    : 'getUint8',

    'uint8'   : 'getUint8',
    'uint16'  : 'getUint16',
    'uint32'  : 'getUint32',
    'uint64'  : 'getUint64',

    'int8'    : 'getInt8',
    'int16'   : 'getInt16',
    'int32'   : 'getInt32',
    'int64'   : 'getInt64',

    'float32' : 'getFloat32',
    'float64' : 'getFloat64',
  };

  static Map<String, String> _SETTERS = const {
    'bool'    : 'setUint8',

    'uint8'   : 'setUint8',
    'uint16'  : 'setUint16',
    'uint32'  : 'setUint32',
    'uint64'  : 'setUint64',

    'int8'    : 'setInt8',
    'int16'   : 'setInt16',
    'int32'   : 'setInt32',
    'int64'   : 'setInt64',

    'float32' : 'setFloat32',
    'float64' : 'setFloat64',
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
      if (listType.isPrimitive) {
        int elementSize = primitives.size(listType.primitiveType);
        String getter = '_segment.memory.${_GETTERS[name]}';
        String setter = '_segment.memory.${_SETTERS[name]}';
        String offset = '_offset + index * $elementSize';

        writeln();
        writeln('class _${name}List extends ListReader '
                'implements List<$name> {');
        write('  ');
        writeType(listType);
        writeln(' operator[](int index) => $getter($offset);');
        writeln('}');

        writeln();
        writeln('class _${name}BuilderList extends ListBuilder '
                'implements List<$name> {');
        write('  ');
        writeType(listType);
        writeln(' operator[](int index) => $getter($offset);');
        write('  void operator[]=(int index, ');
        writeType(listType);
        writeln(' value) => $setter($offset, value);');
        writeln('}');
      } else {
        Struct element = listType.resolved;
        StructLayout elementLayout = element.layout;
        int elementSize = elementLayout.size;

        writeln();
        writeln('class _${name}List extends ListReader '
                'implements List<$name> {');
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
        int offset = inputLayout[argument].offset + 48;
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

    String setInt32() => 'request.setInt32(48, result)';
    String setInt64() => 'request.setInt64(48, result)';

    for (int i = 0; i < methods.length; ++i) {
      Method method = methods[i];
      writeln('      case ${methodIds[i]}:');
      if (method.returnType.isVoid) {
        write('        ');
        writeImplCall(method);
        writeln(');');
      } else if (method.returnType.isPrimitive) {
        write('        var result = ');
        writeImplCall(method);
        writeln(');');
        writeln('        ${setInt32()};');
      } else {
        Struct resultType = method.returnType.resolved;
        StructLayout resultLayout = new StructLayout(resultType);
        int size = resultLayout.size;
        writeln('        MessageBuilder mb = new MessageBuilder(${size + 8});');
        String builderName = '${method.returnType.identifier}Builder';
        writeln('        $builderName builder = '
                'mb.initRoot(new $builderName(), $size);');
        write('        ');
        writeImplCall(method);
        write('${method.arguments.length > 0 ? ", " : ""}builder');
        writeln(');');
        writeln('        var result = getResultMessage(builder);');
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
      String slotName = slot.slot.name;
      Type slotType = slot.slot.type;

      if (slot.isUnionSlot) {
        String camel = camelize(slotName);
        String tagName = slot.union.tag.name;
        int tag = slot.unionTag;
        writeln('  bool get is$camel => $tag == this.$tagName;');
      }

      if (slotType.isList) {
        write('  List<');
        writeType(slotType);
        write('> get $slotName => ');
        neededListTypes.add(slotType);
        writeln('readList(new _${slotType.identifier}List(), ${slot.offset});');
      } else if (slotType.isVoid) {
        // No getters for void slots.
      } else if (slotType.isString) {
        Type uint8ListType = new ListType(new SimpleType("uint8", false));
        uint8ListType.primitiveType = primitives.lookup("uint8");
        neededListTypes.add(uint8ListType);
        writeln('  String get $slotName => '
                'readString(new _uint8List(), ${slot.offset});');
        writeln('  List<int> get ${slotName}Data => '
                'readList(new _uint8List(), ${slot.offset});');
      } else if (slotType.isPrimitive) {
        String getter = _GETTERS[slotType.identifier];
        String offset = '_offset + ${slot.offset}';

        write('  ');
        writeType(slotType);
        if (slotType.isBool) {
          writeln(' get $slotName => _segment.memory.$getter($offset) != 0;');
        } else {
          writeln(' get $slotName => _segment.memory.$getter($offset);');
        }
      } else {
        write('  ');
        writeType(slotType);
        write(' get $slotName => ');
        if (!slotType.isPointer) {
          write('new ');
          writeType(slotType);
          writeln('()');
          writeln('      .._segment = _segment');
          writeln('      .._offset = _offset + ${slot.offset};');
        } else {
          write('readStruct(new ');
          writeType(slotType);
          writeln('(), ${slot.offset});');
        }
      }
    }
    writeln('}');

    writeln();
    writeln('class ${node.name}Builder extends Builder {');
    for (StructSlot slot in layout.slots) {
      String slotName = slot.slot.name;
      Type slotType = slot.slot.type;

      String updateTag = '';
      if (slot.isUnionSlot) {
        String tagName = slot.union.tag.name;
        int tag = slot.unionTag;
        updateTag = '    $tagName = $tag;\n';
      }

      String camel = camelize(slotName);
      if (slotType.isList) {
        write('  List<');
        writeReturnType(slotType);
        writeln('> init$camel(int length) {');
        write(updateTag);
        int size = 0;
        if (slotType.isPrimitive) {
          size = primitives.size(slotType.primitiveType);
        } else {
          Struct element = slotType.resolved;
          StructLayout elementLayout = element.layout;
          size = elementLayout.size;
        }
        write('    return NewList(new _');
        if (slotType.isPrimitive) {
          write('${slotType.identifier}Builder');
        } else {
          writeReturnType(slotType);
        }
        writeln('List(), ${slot.offset}, length, $size);');
        writeln('  }');
      } else if (slotType.isVoid) {
        writeln('  void set$camel() {');
        write(updateTag);
        writeln('  }');
      } else if (slotType.isString) {
        writeln('  void set ${slotName}(String value) {');
        writeln('    NewString(new _uint8BuilderList(), ${slot.offset}, value);');
        writeln('  }');
        writeln('  List<int> init${camel}Data(int length) {');
        writeln('    return NewList(new _uint8BuilderList(), ${slot.offset},'
                ' length, 1);');
        writeln('  }');
      } else if (slotType.isPrimitive) {
        String setter = _SETTERS[slotType.identifier];
        write('  void set ${slotName}(');
        writeType(slotType);
        writeln(' value) {');
        write(updateTag);
        String offset = '_offset + ${slot.offset}';
        if (slotType.isBool) {
          writeln('    _segment.memory.$setter($offset, value ? 1 : 0);');
        } else {
          writeln('    _segment.memory.$setter($offset, value);');
        }
        writeln('  }');
      } else {
        write('  ');
        writeReturnType(slotType);
        writeln(' init$camel() {');
        write(updateTag);
        if (!slotType.isPointer) {
          write('    return new ');
          writeReturnType(slotType);
          writeln('()');
          writeln('        .._segment = _segment');
          writeln('        .._offset = _offset + ${slot.offset};');
        } else {
          Struct element = slotType.resolved;
          StructLayout elementLayout = element.layout;
          int size = elementLayout.size;
          write('    return NewStruct(new ');
          writeReturnType(slotType);
          writeln('(), ${slot.offset}, $size);');
        }
        writeln('  }');
      }
    }
    writeln('}');
  }

  visitUnion(Union node) {
    // Ignored for now.
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
    'void'    : 'void',
    'bool'    : 'bool',

    'uint8'   : 'int',
    'uint16'  : 'int',
    'uint32'  : 'int',
    'uint64'  : 'int',

    'int8'    : 'int',
    'int16'   : 'int',
    'int32'   : 'int',
    'int64'   : 'int',

    'float32' : 'double',
    'float64' : 'double',
  };

  void writeType(Type node) {
    Node resolved = node.resolved;
    if (resolved != null) {
      write(node.identifier);
    } else {
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
