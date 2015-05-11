// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library immic.plugins.idl;

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

void generate(String path,
              Map<String, Unit> units,
              String outputDirectory) {
  _IDLVisitor visitor = new _IDLVisitor(path);
  visitor.visitUnits(units);
  String content = visitor.buffer.toString();
  String directory = join(outputDirectory, 'idl');
  String outPath = visitor.serviceFile;
  writeToFile(directory, outPath, content, extension: 'idl');
}

class _IDLVisitor extends CodeGenerationVisitor {
  List<Struct> nodes = <Struct>[];
  _IDLVisitor(String path) : super(path);

  HashMap<String, List<Type>> _methodSignatures = {};

  void visitUnits(Map<String, Unit> units) {
    _writeCopyright();
    units.values.forEach(_collectMethodSignatures);
    _writeService();
    // Genereate node specific IDL entries.
    units.values.forEach(visit);
    // Genereate shared definitions.
    _writeNodeDataStruct(nodes);
    _writePatchDataStructs();
  }

  visitUnit(Unit node) {
    node.structs.forEach(visit);
  }

  visitStruct(Struct node) {
    nodes.add(node);
    StructLayout layout = node.layout;
    writeln('struct ${node.name}NodeData {');
    for (StructSlot slot in layout.slots) {
      String slotName = slot.slot.name;
      Type slotType = slot.slot.type;
      write('  ');
      writeType(slotType);
      writeln(' $slotName;');
    }
    node.methods.forEach(visit);
    writeln('}');
    writeln();
  }

  visitUnion(Union node) {
    // Ignored for now.
  }

  visitMethod(Method node) {
    writeln('  uint16 ${node.name};');
  }

  void writeType(Type node) {
    if (node.isList) write('List<');
    Node resolved = node.resolved;
    if (resolved != null) {
      write("${node.identifier}NodeData");
    } else if (node.isNode || node.isList && node.elementType.isNode) {
      write("NodeData");
    } else {
      write(node.identifier);
    }
    if (node.isList) write('>');
  }

  void _collectMethodSignatures(Unit unit) {
    for (var node in unit.structs) {
      for (var method in node.methods) {
        assert(method.returnType.isVoid);
        String signature =
            method.arguments.map((formal) => formal.type.identifier);
        _methodSignatures.putIfAbsent('$signature', () {
          return method.arguments.map((formal) => formal.type);
        });
      }
    }
  }

  void _writeCopyright() {
    writeln(COPYRIGHT);
    writeln('// Generated file. Do not edit.');
    writeln();
  }

  void _writeService() {
    writeln('service ${serviceName} {');
    // TODO(zerny): Don't assume a root entry point for the scene.
    writeln('  void reset();');
    writeln('  PatchSetData* refresh();');
    for (List<Type> formals in _methodSignatures.values) {
      write('  void dispatch');
      for (var formal in formals) {
        write(camelize(formal.identifier));
      }
      write('(uint16 id');
      int i = 0;
      for (var formal in formals) {
        write(', ${formal.identifier} arg${++i}');
      }
      writeln(');');
    }
    writeln('}');
    writeln();
  }

  void _writeNodeDataStruct(List<Struct> nodes) {
    writeln('struct NodeData {');
    writeln('  union {');
    nodes.forEach((Struct node) {
      String nodeType = "${node.name}NodeData";
      String nodeField = camelize(node.name);
      writeln('    $nodeType* $nodeField;');
    });
    writeln('  }');
    writeln('}');
    writeln();
  }

  void _writePatchDataStructs() {
    write("""
struct PrimitiveData {
  union {
    bool boolData;
    uint8 uint8Data;
    uint16 uint16Data;
    uint32 uint32Data;
    uint64 uint64Data;
    int8 int8Data;
    int16 int16Data;
    int32 int32Data;
    int64 int64Data;
    float32 float32Data;
    float64 float64Data;
    String StringData;
  }
}

struct ContentData {
  union {
    PrimitiveData* primitive;
    NodeData* node;
  }
}

struct ListPatchData {
  uint32 index;
  union {
    uint32 remove;
    List<ContentData> insert;
    List<PatchSetData> update;
  }
}

struct PatchData {
  List<uint8> path;
  union {
    ContentData* content;
    ListPatchData* listPatch;
  }
}

struct PatchSetData {
  List<PatchData> patches;
}

""");
  }
}
