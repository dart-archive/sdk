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

void generate(String path,
              Map<String, Unit> units,
              String outputDirectory) {
  String directory = join(outputDirectory, 'dart');
  units.forEach((path, unit) => _generateNodeFile(path, unit, directory));
  _generateServiceFile(path, units, directory);
}

void _generateNodeFile(String unitPath, Unit unit, String directory) {
  _DartVisitor visitor = new _DartVisitor(unitPath);
  visitor.visit(unit);
  String content = visitor.buffer.toString();
  writeToFile(directory, unitPath, content, extension: 'dart');
}

void _generateServiceFile(String path,
                          Map<String, Unit> units,
                          String directory) {
  _DartVisitor visitor = new _DartVisitor(path);
  units.values.forEach(visitor._collectMethodSignatures);
  visitor._writeServiceImpl();
  String content = visitor.buffer.toString();
  String file = visitor.serviceImplFile;
  writeToFile(directory, file, content, extension: 'dart');
}

class _DartVisitor extends CodeGenerationVisitor {
  _DartVisitor(String path) : super(path);

  HashMap<String, List<Type>> _methodSignatures = {};

  visitUnit(Unit node) {
    _writeHeader();
    _writeLibrary();
    _writeImports();
    node.imports.forEach(visit);
    node.structs.forEach(visit);
  }

  visitImport(Import import) {
    String file = basenameWithoutExtension(import.file);
    writeln("import '${immiGenPkg}/dart/${file}.dart';");
  }

  visitStruct(Struct node) {
    String nodeName = "${node.name}Node";
    bool hasSlotsAndMethods =
        !node.layout.slots.isEmpty && !node.methods.isEmpty;
    writeln('class $nodeName extends Node {');
    // Final fields.
    forEachSlot(node, null, (Type slotType, String slotName) {
      write('  final ');
      writeType(slotType);
      writeln(' $slotName;');
    });
    for (var method in node.methods) {
      writeln('  final Function ${method.name};');
    }
    // Public keyword constructor.
    write('  factory $nodeName({');
    forEachSlot(node, writeComma, (Type slotType, String slotName) {
      writeType(slotType);
      write(' $slotName');
    });
    if (hasSlotsAndMethods) write(', ');
    write(node.methods.map((method) => 'Function ${method.name}').join(', '));
    writeln('}) =>');
    write('      new ${nodeName}._internal(');
    forEachSlot(node, writeComma, (_, String slotName) {
      write('$slotName');
    });
    if (hasSlotsAndMethods) write(', ');
    write(node.methods.map((method) => method.name).join(', '));
    writeln(');');
    // Positional constructor.
    write('  ${nodeName}._internal(');
    forEachSlot(node, writeComma, (_, String slotName) {
      write('this.${slotName}');
    });
    if (hasSlotsAndMethods) write(', ');
    write(node.methods.map((method) => 'this.${method.name}').join(', '));
    writeln(');');
    // Serialization
    writeln('  void serializeNode(NodeDataBuilder builder, ResourceManager manager) {');
    writeln('    serialize(builder.init${node.name}(), manager);');
    writeln('  }');
    writeln('  void serialize(${nodeName}DataBuilder builder, ResourceManager manager) {');
    forEachSlot(node, null, (Type slotType, String slotName) {
      String slotNameCamel = camelize(slotName);
      if (slotType.isList) {
        String localSlotLength = "${slotName}Length";
        String localSlotBuilder = "${slotName}Builder";
        String serialize =
            slotType.elementType.isNode ? 'serializeNode' : 'serialize';
        writeln('    var $localSlotLength = $slotName.length;');
        writeln('    List $localSlotBuilder =');
        writeln('        builder.init$slotNameCamel($localSlotLength);');
        writeln('    for (var i = 0; i < $localSlotLength; ++i) {');
        writeln('      $slotName[i].$serialize($localSlotBuilder[i], manager);');
        writeln('    }');
      } else if (slotType.isNode) {
        writeln('    $slotName.serializeNode(builder.init$slotNameCamel(), manager);');
      } else if (slotType.resolved != null) {
        writeln('var local$slotName = $slotName;');
        writeln('    $slotName.serialize(builder.init$slotNameCamel(), manager);');
      } else {
        writeln('    builder.$slotName = $slotName;');
      }
    });
    for (var method in node.methods) {
      String methodName = method.name;
      writeln('    builder.$methodName = manager.addHandler($methodName);');
    }
    writeln('  }');

    // Event handlers
    writeln('  void unregisterHandlers(ResourceManager manager) {');
    for (var method in node.methods) {
      writeln('    manager.removeHandler(${method.name});');
    }
    writeln('  }');

    // Difference
    writeln('  bool diff(Node previousNode, List<int> path, List<Patch> patches) {');
    writeln('    if (identical(this, previousNode)) return false;');
    writeln('    if (previousNode is! $nodeName) {');
    writeln('      patches.add(new NodePatch(this, previousNode, path));');
    writeln('      return true;');
    writeln('    }');
    writeln('    $nodeName previous = previousNode;');
    bool hasFields = node.layout.slots.isNotEmpty;
    bool hasMethods = node.methods.isNotEmpty;
    if (!hasFields && !hasMethods) {
      writeln('    return false;');
    } else {
      writeln('    bool changed = false;');
      writeln('    int pathIndex = path.length;');
      writeln('    path.add(-1);');
    }
    int slotIndex = 0;
    if (hasFields) {
      forEachSlot(node, null, (Type slotType, String slotName) {
        if (slotType.isList) {
          writeln('    path[pathIndex] = $slotIndex;');
          writeln('    if (diffList($slotName, previous.$slotName, path, patches)) {');
          writeln('      changed = true;');
          writeln('    }');
        } else if (slotType.resolved != null) {
          writeln('    path[pathIndex] = $slotIndex;');
          writeln('    if ($slotName.diff(previous.$slotName, path, patches)) {');
          writeln('      changed = true;');
          writeln('    }');
        } else {
          writeln('    if ($slotName != previous.$slotName) {');
          writeln('      changed = true;');
          writeln('      path[pathIndex] = $slotIndex;');
          writeln('      patches.add(new PrimitivePatch(');
          writeln('          "${slotType.identifier}", $slotName, previous.$slotName, path));');
          writeln('    }');
        }
        ++slotIndex;
      });
    }
    if (hasMethods) {
      for (var method in node.methods) {
        String slotName = method.name;
        writeln('    if ($slotName != previous.$slotName) {');
        writeln('      changed = true;');
        writeln('      path[pathIndex] = $slotIndex;');
        writeln('      patches.add(new MethodPatch($slotName, previous.$slotName, path));');
        writeln('    }');
        ++slotIndex;
      }
    }
    if (hasFields || hasMethods) {
      writeln('    path.length = pathIndex;');
      writeln('    return changed;');
    }
    writeln('  }');
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
    _writeHeader();
    write("""
library ${serviceImplLib};

import 'package:immi/immi.dart';
import '${immiGenPkg}/dart/${serviceFile}.dart';

class ${serviceImplName} extends ${serviceName} {
  var _nextPresenterId = 1;
  var _presenters = [null];
  var _presenterGraphs = [null];
  var _presenterNameToId = {};
  var _patches = [];

  // TODO(zerny): Implement per-graph resource management.
  ResourceManager _manager = new ResourceManager();

  ${serviceImplName}();
  void add(String name, presenter) {
    assert(!_presenterNameToId.containsKey(name));
    _presenterNameToId[name] = _addPresenter(presenter);
  }

  int _addPresenter(presenter) {
    assert(_presenters.length == _nextPresenterId);
    assert(_presenterGraphs.length == _nextPresenterId);
    _presenters.add(presenter);
    _presenterGraphs.add(null);
    return _nextPresenterId++;
  }

  int getPresenter(PresenterData data) {
    String name = data.name;
    int pid = _presenterNameToId[name];
    return pid == null ? 0 : pid;
  }

  void reset(int pid) {
    int length = _presenterGraphs.length;
    for (int i = 0; i < length; ++i) {
      _presenterGraphs[i] = null;
    }
    _manager.clear();
  }

  void refresh(int pid, PatchSetDataBuilder builder) {
    assert(0 < pid && pid < _nextPresenterId);
    var previous = _presenterGraphs[pid];
    var current = _presenters[pid].present(previous);
    var patches = _patches;
    if (current.diff(previous, [], patches)) {
      int length = _patches.length;
      _presenterGraphs[pid] = current;
      List<PatchDataBuilder> patchBuilder = builder.initPatches(length);
      for (int i = 0; i < length; ++i) {
        patches[i].serialize(patchBuilder[i], _manager);
      }
      patches.length = 0;
    } else {
      builder.initPatches(0);
    }
  }

  void run() {
    ${serviceName}.initialize(this);
    while (${serviceName}.hasNextEvent()) {
      ${serviceName}.handleNextEvent();
    }
  }

""");
    for (List<Type> formals in _methodSignatures.values) {
      write('  void dispatch');
      for (var formal in formals) {
        write(camelize(formal.identifier));
      }
      write('(int id');
      int i = 0;
      for (var formal in formals) {
        write(', ');
        writeType(formal);
        write(' arg${++i}');
      }
      writeln(') {');
      writeln('    var handler = _manager.getHandler(id);');
      write('    if (handler != null) handler(');
      for (int j = 1; j <= i; ++j) {
        if (j != 1) write(', ');
        write('arg$j');
      }
      writeln(');');

      writeln('  }');
      writeln();
    }
    write("""
}

""");
  }

  void _writeHeader() {
    writeln(COPYRIGHT);
    writeln('// Generated file. Do not edit.');
    writeln();
  }

  void _writeLibrary() {
    writeln('library $libraryName;');
    writeln();
  }

  void _writeImports() {
    writeln('import "package:immi/immi.dart";');
    writeln('import "package:immi_gen/dart/$serviceFile.dart";');
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
    'node'    : 'Node',
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
}
