// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.plugins.cc;

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

  static const int REQUEST_HEADER_SIZE = 32;
  static const PRIMITIVE_TYPES = const <String, String> {
    'Int16': 'short',
    'Int32': 'int',
  };

  static String cast(String type, bool cStyle) => cStyle
      ? '($type)'
      : 'reinterpret_cast<$type>';

  visitUnion(Union node) {
    throw "Unreachable";
  }

  visitFormal(Formal node) {
    writeType(node.type);
    write(' ${node.name}');
  }

  void writeType(Type node) {
    Node resolved = node.resolved;
    if (resolved != null) {
      write('${node.identifier}Builder');
    } else {
      String type = PRIMITIVE_TYPES[node.identifier];
      write(type);
    }
  }

  void writeReturnType(Type node) {
    Node resolved = node.resolved;
    if (resolved != null) {
      write('${node.identifier}');
    } else {
      String type = PRIMITIVE_TYPES[node.identifier];
      write(type);
    }
  }

  visitArguments(List<Formal> formals) {
    visitNodes(formals, (first) => first ? '' : ', ');
  }

  visitMethodBody(String id,
                  Method method,
                  {bool cStyle: false,
                   List<String> extraArguments: const [],
                   String callback}) {
    List<Formal> arguments = method.arguments;
    assert(method.inputKind == InputKind.PRIMITIVES);
    StructLayout layout = method.inputPrimitiveStructLayout;
    final bool async = callback != null;
    int size = REQUEST_HEADER_SIZE + layout.size;
    if (async) {
      write('  static const int kSize = ');
      writeln('${size} + ${extraArguments.length + 1} * sizeof(void*);');
    } else {
      writeln('  static const int kSize = ${size};');
    }

    String cast(String type) => CcVisitor.cast(type, cStyle);

    String pointerToArgument(int offset, int pointers, String type) {
      offset += REQUEST_HEADER_SIZE;
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
      int offset = layout[arguments[i]].offset;
      String type = PRIMITIVE_TYPES[arguments[i].type.identifier];
      writeln('  *${pointerToArgument(offset, 0, type)} = $name;');
    }

    if (async) {
      String dataArgument = pointerToArgument(layout.size, 0, 'void*');
      writeln('  *$dataArgument = ${cast("void*")}(callback);');
      for (int i = 0; i < extraArguments.length; i++) {
        String dataArgument = pointerToArgument(layout.size, 1, 'void*');
        String arg = extraArguments[i];
        writeln('  *$dataArgument = ${cast("void*")}($arg);');
      }
      write('  ServiceApiInvokeAsync(_service_id, $id, $callback, ');
      writeln('_buffer, kSize);');
    } else {
      writeln('  ServiceApiInvoke(_service_id, $id, _buffer, kSize);');
      if (method.outputKind == OutputKind.STRUCT) {
        writeln('  int64_t result = *${pointerToArgument(0, 0, 'int64_t')};');
        writeln('  char* memory = reinterpret_cast<char*>(result);');
        StructLayout resultLayout = new StructLayout(method.returnType.resolved);
        int size = resultLayout.size;
        writeln('  Segment* segment = '
                'MessageReader::GetRootSegment(memory, $size);');
        writeln('  return ${method.returnType.identifier}(segment, 8);');
      } else {
        writeln('  return *${pointerToArgument(0, 0, 'int')};');
      }
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

    if (node.structs.isNotEmpty) {
      writeln();
      writeln('#include "struct.h"');
    }

    if (node.structs.isNotEmpty) writeln();
    for (Struct struct in node.structs) {
      writeln('class ${struct.name};');
      writeln('class ${struct.name}Builder;');
    }

    node.services.forEach(visit);
    node.structs.forEach(visit);

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
    writeReturnType(node.returnType);
    write(' ${node.name}(');
    visitArguments(node.arguments);
    writeln(');');

    // TODO(kasperl): Cannot deal with async methods accepting structs yet.
    if (node.inputKind == InputKind.STRUCT ||
        node.outputKind == OutputKind.STRUCT) return;

    write('  static void ${node.name}Async(');
    visitArguments(node.arguments);
    if (node.arguments.isNotEmpty) write(', ');
    write('void (*callback)(');
    writeReturnType(node.returnType);
    writeln('));');
  }

  visitStruct(Struct node) {
    writeReader(node);
    writeBuilder(node);
  }

  void writeReader(Struct node) {
    String name = node.name;
    StructLayout layout = node.layout;

    writeln();
    writeln('class $name : public Reader {');
    writeln(' public:');
    writeln('  static const int kSize = ${layout.size};');

    writeln('  $name(Segment* segment, int offset)');
    writeln('      : Reader(segment, offset) { }');
    writeln();

    for (StructSlot slot in layout.slots) {
      Type slotType = slot.slot.type;

      // TODO(kasperl): Don't skip.
      if (!(slotType.isPrimitive || slotType.isList)) continue;

      String slotName = slot.slot.name;

      if (slot.isUnionSlot) {
        String tagName = slot.union.tag.name;
        int tag = slot.unionTag;
        writeln('  bool is_$slotName() const { return $tag == $tagName(); }');
      }

      if (slotType.isPrimitive) {
        write('  ');
        writeType(slotType);
        write(' ${slot.slot.name}() const { return *PointerTo<');
        writeType(slotType);
        writeln('>(${slot.offset}); }');
      } else if (slotType.isList) {
        write('  ');
        write('List<');
        writeReturnType(slotType);
        write('> ${slot.slot.name}() const { return ReadList<');
        writeReturnType(slotType);
        writeln('>(${slot.offset}); }');
      }
    }

    writeln('};');
  }

  void writeBuilder(Struct node) {
    String name = "${node.name}Builder";
    StructLayout layout = node.layout;

    writeln();
    writeln('class $name : public Builder {');
    writeln(' public:');
    writeln('  static const int kSize = ${layout.size};');
    writeln();

    writeln('  explicit $name(const Builder& builder)');
    writeln('      : Builder(builder) { }');
    writeln('  $name(Segment* segment, int offset)');
    writeln('      : Builder(segment, offset) { }');
    writeln();

    for (StructSlot slot in layout.slots) {
      String slotName = slot.slot.name;
      Type slotType = slot.slot.type;

      String camel = strings.camelize(strings.underscore(slotName));
      if (slotType.isList) {
        write('  List<');
        writeType(slotType);
        writeln('> New$camel(int length);');
      } else if (slotType.isPrimitive) {
        write('  void set_${slotName}(');
        writeType(slotType);
        write(' value) { ');
        if (slot.isUnionSlot) {
          String tagName = slot.union.tag.name;
          int tag = slot.unionTag;
          write('set_$tagName($tag); ');
        }
        write('*PointerTo<');
        writeType(slotType);
        writeln('>(${slot.offset}) = value; }');
      } else {
        write('  ');
        writeType(slotType);
        writeln(' New$camel();');
      }
    }

    writeln('};');
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
    node.structs.forEach(visit);
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

  visitStruct(Struct node) {
    writeBuilder(node);
  }

  void writeBuilder(Struct node) {
    String name = "${node.name}Builder";
    StructLayout layout = node.layout;

    for (StructSlot slot in layout.slots) {
      String slotName = slot.slot.name;
      Type slotType = slot.slot.type;

      String updateTag = '';
      if (slot.isUnionSlot) {
        String tagName = slot.union.tag.name;
        int tag = slot.unionTag;
        updateTag = '  set_$tagName($tag);\n';
      }

      if (slotType.isList) {
        writeln();
        String camel = strings.camelize(strings.underscore(slotName));
        write('List<');
        writeType(slotType);
        writeln('> $name::New$camel(int length) {');
        Struct element = slot.slot.type.resolved;
        StructLayout elementLayout = element.layout;
        int size = elementLayout.size;
        write(updateTag);
        writeln('  Reader result = NewList(${slot.offset}, length, $size);');
        writeln('  return List<$name>(result, length);');
        writeln('}');
      } else if (!slotType.isPrimitive) {
        writeln();
        String camel = strings.camelize(strings.underscore(slotName));
        writeType(slotType);
        writeln(' $name::New$camel() {');
        Struct element = slot.slot.type.resolved;
        StructLayout elementLayout = element.layout;
        int size = elementLayout.size;
        write(updateTag);
        writeln('  Builder result = NewStruct(${slot.offset}, $size);');
        write('  return ');
        writeType(slotType);
        writeln('(result);');
        writeln('}');
      }
    }
  }

  visitMethod(Method node) {
    String name = node.name;
    String id = '_k${name}Id';

    writeln();
    write('static const MethodId $id = ');
    writeln('reinterpret_cast<MethodId>(${methodId++});');

    writeln();
    writeReturnType(node.returnType);
    write(' $serviceName::${name}(');
    visitArguments(node.arguments);
    writeln(') {');

    if (node.inputKind == InputKind.STRUCT) {
      if (node.outputKind == OutputKind.STRUCT) {
        writeln('  int64_t result = ${node.arguments.single.name}.'
                'InvokeMethod(_service_id, $id);');
        writeln('  char* memory = reinterpret_cast<char*>(result);');
        Struct resultStruct = node.returnType.resolved;
        StructLayout resultLayout = resultStruct.layout;
        int size = resultLayout.size;
        writeln('  Segment* segment = '
                'MessageReader::GetRootSegment(memory, $size);');
        writeln('  return ${node.returnType.identifier}(segment, 0);');
      } else {
        writeln('  return ${node.arguments.single.name}.'
                'InvokeMethod(_service_id, $id);');
      }
      writeln('}');

    } else {
      assert(node.inputKind == InputKind.PRIMITIVES);

      visitMethodBody(id, node);
      writeln('}');

      // TODO(ager): Deal with struct return in async version.
      if (node.outputKind == OutputKind.STRUCT) return;

      String callback = ensureCallback(node.returnType,
          node.inputPrimitiveStructLayout);

      writeln();
      write('void $serviceName::${name}Async(');
      visitArguments(node.arguments);
      if (node.arguments.isNotEmpty) write(', ');
      write('void (*callback)(');
      writeReturnType(node.returnType);
      writeln(')) {');
      visitMethodBody(id, node, callback: callback);
      writeln('}');
    }
  }

  final Map<String, String> callbacks = {};
  String ensureCallback(Type type,
                        StructLayout layout,
                        {bool cStyle: false}) {
    String key = '${type.identifier}_${layout.size}';
    return callbacks.putIfAbsent(key, () {
      String cast(String type) => CcVisitor.cast(type, cStyle);
      String name = 'Unwrap_$key';
      writeln();
      writeln('static void $name(void* raw) {');
      writeln('  typedef void (*cbt)(int);');
      writeln('  char* buffer = ${cast('char*')}(raw);');
      int offset = CcVisitor.REQUEST_HEADER_SIZE;
      writeln('  int result = *${cast('int*')}(buffer + $offset);');
      offset += layout.size;
      writeln('  cbt callback = *${cast('cbt*')}(buffer + $offset);');
      writeln('  free(buffer);');
      writeln('  callback(result);');
      writeln('}');
      return name;
    });
  }
}
