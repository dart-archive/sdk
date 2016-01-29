// Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
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
// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
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
    _writeActionArgumentStructs();
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
    writeln('  uint16 getPresenter(PresenterData* data);');
    writeln('  void reset(uint16 pid);');
    writeln('  PatchData* refresh(uint16 pid);');
    for (List<Type> formals in _methodSignatures.values) {
      String suffix = actionTypeSuffix(formals);
      bool boxedArguments = formals.any((t) => t.isString);
      if (boxedArguments) {
        writeln('  void dispatch$suffix(Action${suffix}Args* args);');
        continue;
      }
      write('  void dispatch$suffix(uint16 id');
      int i = 0;
      for (var formal in formals) {
        write(', ${formal.identifier} arg${i++}');
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

    writeln('struct NodePatchData {');
    writeln('  union {');
    nodes.forEach((Struct node) {
      String patchType = "${node.name}PatchData";
      String nodeField = camelize(node.name);
      writeln('    $patchType* $nodeField;');
    });
    writeln('  }');
    writeln('}');
    writeln();

    nodes.forEach((Struct node) {
      String nodeType = "${node.name}NodeData";
      String patchType = "${node.name}PatchData";
      String updateType = "${node.name}UpdateData";
      writeln('struct $patchType {');
      writeln('  union {');
      writeln('    $nodeType* replace;');
      writeln('    List<${updateType}> updates;');
      writeln('  }');
      writeln('}');
      writeln('struct $updateType {');
      writeln('  union {');
      forEachSlot(node, null, (Type slotType, String slotName) {
        if (slotType.isList) {
          writeln('    ListPatchData $slotName;');
        } else if (slotType.isNode || slotType.resolved != null) {
          writeln('    ${camelize(slotType.identifier)}PatchData $slotName;');
        } else {
          write('    ');
          writeType(slotType);
          writeln(' $slotName;');
        }
      });
      for (Method method in node.methods) {
        writeln('    uint16 ${method.name};');
      }
      writeln('  }');
      writeln('}');
      writeln();
      });
  }

  void _writePatchDataStructs() {
    writeln("""
struct PresenterData {
  String name;
}

struct ListPatchData {
  uint8 type;
  List<ListRegionData> regions;
}

// TODO(zerny): Support lists of primitives.
struct ListRegionData {
  int32 index;
  union {
    int32 remove;
    List<NodeData> insert;
    List<NodePatchData> update;
  }
}

struct PatchData {
  union {
    void noPatch;
    NodePatchData* node;
  }
}
""");
  }

  void _writeActionArgumentStructs() {
    for (List<Type> formals in _methodSignatures.values) {
      String suffix = actionTypeSuffix(formals);
      bool boxedArguments = formals.any((t) => t.isString);
      if (!boxedArguments) continue;
      writeln('struct Action${suffix}Args {');
      int i = 0;
      writeln('  uint16 id;');
      for (Type formal in formals) {
        writeln('  ${formal.identifier} arg${i++};');
      }
      writeln('}');
    }
  }
}
