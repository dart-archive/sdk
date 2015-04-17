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

void generate(String path, Unit unit, String outputDirectory) {
  _IDLVisitor visitor = new _IDLVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  String directory = join(outputDirectory, 'idl');
  String outPath = "${basenameWithoutExtension(path)}_presenter_service";
  writeToFile(directory, outPath, contents, extension: 'idl');
}

class _IDLVisitor extends CodeGenerationVisitor {
  _IDLVisitor(String path) : super(path);

  visitUnit(Unit node) {
    _writeCopyright();
    _writeService();
    node.structs.forEach(visit);
    _writeNodeDataStruct(node.structs);
    _writePatchDataStructs();
  }

  visitStruct(Struct node) {
    StructLayout layout = node.layout;
    writeln('struct ${node.name}NodeData {');
    for (StructSlot slot in layout.slots) {
      String slotName = slot.slot.name;
      Type slotType = slot.slot.type;
      write('  ');
      writeType(slotType);
      writeln(' $slotName;');
    }
    writeln('}');
    writeln();
  }

  visitUnion(Union node) {
    // Ignored for now.
  }

  visitMethod(Method node) {
    // Ignored for now.
  }

  void writeType(Type node) {
    if (node.isList) write('List<');
    Node resolved = node.resolved;
    if (resolved != null) {
      write("${node.identifier}NodeData");
    } else {
      write(node.identifier);
    }
    if (node.isList) write('>');
  }

  void _writeCopyright() {
    writeln(COPYRIGHT);
    writeln('// Generated file. Do not edit.');
    writeln();
  }

  void _writeService() {
    String serviceName = camelize(basenameWithoutExtension(path));
    writeln('service ${serviceName}PresenterService {');
    // TODO(zerny): Don't assume a root entry point for the scene.
    writeln('  void reset();');
    writeln('  PatchSetData* refresh();');
    writeln('}');
    writeln();
  }

  void _writeNodeDataStruct(List<Struct> nodes) {
    writeln('struct NodeData {');
    writeln('  union {');
    nodes.forEach((Struct node) {
      String nodeType = "${node.name}NodeData";
      String nodeField = camelize(node.name);
      writeln('  $nodeType $nodeField;');
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
    PrimitiveData primitive;
    NodeData node;
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
