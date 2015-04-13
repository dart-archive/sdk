// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library immic.plugins.dart;

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
  _DartVisitor visitor = new _DartVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  String directory = join(outputDirectory, 'dart');
  writeToFile(directory, path, contents, extension: 'dart');
}

class _DartVisitor extends CodeGenerationVisitor {
  _DartVisitor(String path) : super(path);

  visitUnit(Unit node) {
    _writeHeader();
    _writeLibrary();
    _writeImports();
    _writeServiceImpl();
    _writeNodeBase(node.structs);
    node.structs.forEach(visit);
  }

  visitStruct(Struct node) {
    String nodeName = "${node.name}Node";
    writeln('class $nodeName extends Node {');
    // Final fields.
    forEachSlot(node, null, (Type slotType, String slotName) {
      write('  final ');
      writeType(slotType);
      writeln(' $slotName;');
    });
    // Public keyword constructor.
    write('  factory $nodeName({');
    forEachSlot(node, writeComma, (Type slotType, String slotName) {
      writeType(slotType);
      write(' $slotName');
    });
    writeln('}) =>');
    write('      new ${nodeName}._internal(');
    forEachSlot(node, writeComma, (_, String slotName) {
      write('$slotName');
    });
    writeln(');');
    // Positional constructor.
    write('  ${nodeName}._internal(');
    forEachSlot(node, writeComma, (_, String slotName) {
      write('this.${slotName}');
    });
    writeln(');');
    writeln('}');
    writeln();
  }

  visitUnion(Union node) {
    // Ignored for now.
  }

  visitMethod(Method node) {
    // Ignored for now.
  }

  void _writeServiceImpl() {
    String baseName = camelize(basenameWithoutExtension(path));
    String serviceName = "${baseName}PresenterService";
    String implName = "${baseName}Impl";
    write("""
class ${implName} extends ${serviceName} {
  var _presenter;
  var _previous;
  ${implName}(this._presenter);
  void reset() {
    print("reset was called!");
    _previous = null;
  }
  void refresh(PatchSetDataBuilder builder) {
    builder.initPatches(0);
  }
  void run() {
    ${serviceName}.initialize(this);
    while (${serviceName}.hasNextEvent()) {
      ${serviceName}.handleNextEvent();
    }
  }
}

""");
  }

  void _writeNodeBase(List<Struct> nodes) {
    writeln('abstract class Node { }');
    writeln();
  }

  void _writeHeader() {
    writeln(COPYRIGHT);
    writeln('// Generated file. Do not edit.');
    writeln();
  }

  void _writeLibrary() {
    String libraryName = basenameWithoutExtension(path);
    writeln('library $libraryName;');
    writeln();
  }

  void _writeImports() {
    String servicePath = "${basenameWithoutExtension(path)}_presenter_service";
    writeln('import "${servicePath}.dart";');
    writeln();
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

    'String'  : 'String',
  };

  void writeType(Type node) {
    if (node.isList) write('List<');
    Node resolved = node.resolved;
    if (resolved != null) {
      write("${node.identifier}Node");
    } else {
      String type = _types[node.identifier];
      write(type);
    }
    if (node.isList) write('>');
  }
}
