// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.plugins.cc;

import 'dart:core' hide Type;
import 'dart:io' show Platform, File;

import 'package:strings/strings.dart' as strings;
import 'package:path/path.dart' show basenameWithoutExtension, join, dirname;

import 'shared.dart';

import '../emitter.dart';
import '../primitives.dart' as primitives;
import '../struct_layout.dart';

const List<String> RESOURCES = const [
  'AnyNodePresenter.java',
  'ImmiRoot.java',
  'ImmiService.java',
  'ListPatch.java',
  'Node.java',
  'NodePatch.java',
  'NodePresenter.java',
  'Patch.java',
];

const Map<String, String> _TYPES = const <String, String>{
  'void'    : 'void',
  'bool'    : 'boolean',

  'uint8'   : 'int',
  'uint16'  : 'int',

  'int8'    : 'int',
  'int16'   : 'int',
  'int32'   : 'int',
  'int64'   : 'long',

  'float32' : 'float',
  'float64' : 'double',

  'String' : 'String',
};

void generate(String path, Map units, String outputDirectory) {
  String directory = join(outputDirectory, 'java', 'immi');
  _generateNodeFiles(path, units, directory);

  String resourcesDirectory = join(dirname(Platform.script.path),
      '..', 'lib', 'src', 'resources', 'java', 'immi');
  for (String resource in RESOURCES) {
    String resourcePath = join(resourcesDirectory, resource);
    File file = new File(resourcePath);
    String contents = file.readAsStringSync();
    writeToFile(directory, resource, contents);
  }
}

void _generateNodeFiles(String path, Map units, String outputDirectory) {
  new _AnyNodeWriter(units).writeTo(outputDirectory);
  new _AnyNodePatchWriter(units).writeTo(outputDirectory);
  for (Unit unit in units.values) {
    for (Struct node in unit.structs) {
      new _JavaNodeWriter(node).writeTo(outputDirectory);
      new _JavaNodePatchWriter(node).writeTo(outputDirectory);
      new _JavaNodePresenterWriter(node).writeTo(outputDirectory);
    }
  }
  _TYPES.forEach((idlType, javaType) {
    if (idlType == 'void') return;
    new _JavaPrimitivePatchWriter(idlType, javaType).writeTo(outputDirectory);
  });
}

class _JavaVisitor extends CodeGenerationVisitor {
  static const COPYRIGHT = """
// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
""";

  _JavaVisitor(String path) : super(path);
}

class _JavaWriter extends _JavaVisitor {

  final String className;

  bool shouldWriteHeader = false;
  Set<String> imports = new Set<String>();

  _JavaWriter(String className)
      : super(className),
        className = className;

  void writeHeader([List<String> imports]) {
    shouldWriteHeader = true;
    if (imports != null) imports.forEach((i) { this.imports.add(i); });
  }

  void writeTo(String directory) {
    var content = buffer.toString();
    buffer.clear();
    if (shouldWriteHeader) {
      writeln(_JavaVisitor.COPYRIGHT);
      writeln('// Generated file. Do not edit.');
      writeln();
      writeln('package immi;');
      writeln();
      if (imports.isNotEmpty) {
        var sorted = imports.toList()..sort();
        var inJava = <String>[];
        var inOther = <String>[];
        for (var import in sorted) {
          if (import.startsWith('java')) {
            inJava.add(import);
          } else {
            inOther.add(import);
          }
        }
        inJava.forEach(writeImport);
        if (inJava.isNotEmpty) writeln();
        inOther.forEach(writeImport);
        if (inOther.isNotEmpty) writeln();
      }
    }
    buffer.write(content);
    writeToFile(directory, className, buffer.toString(), extension: 'java');
  }

  writeImport(import) {
    writeln('import $import;');
  }

  String instanceOrNull(String name, String type) {
    return '($name instanceof $type) ? ($type)$name : null';
  }

  String getTypeName(Type type) {
    if (type.isList) {
      imports.add('java.util.List');
      return 'List<${getNonListTypeName(type)}>';
    }
    return getNonListTypeName(type);
  }

  String getNonListTypeName(Type type) {
    // TODO(zerny): Make the type structure regular!
    if (type.isNode || type.isList && type.elementType.isNode) return 'AnyNode';
    if (type.resolved != null) {
      return "${type.identifier}Node";
    }
    return _TYPES[type.identifier];
  }

  String getPatchTypeName(Type type) {
    if (type.isList) return 'ListPatch';
    if (type.isNode) return 'AnyNodePatch';
    if (type.resolved != null) {
      return "${type.identifier}Patch";
    }
    return "${camelize(type.identifier)}Patch";
  }
}

class _JavaPrimitivePatchWriter extends _JavaWriter {
  _JavaPrimitivePatchWriter(String idlType, javaType)
      : super('${strings.camelize(strings.underscore(idlType))}Patch') {
    writeHeader();
    writeln('public class $className implements Patch {');
    writeln();
    writeln('  // Public interface.');
    writeln();
    writeln('  @Override');
    writeln('  public boolean hasChanged() { return previous != current; }');
    writeln();
    writeln('  public $javaType getCurrent() { return current; }');
    writeln('  public $javaType getPrevious() { return previous; }');
    writeln();
    writeln('  // Package private implementation.');
    writeln();
    writeln('  $className($javaType data, $javaType previous, ImmiRoot root) {');
    writeln('    this.previous = previous;');
    writeln('    current = data;');
    writeln('  }');
    writeln();
    writeln('  private $javaType previous;');
    writeln('  private $javaType current;');
    writeln('}');
  }
}

class _JavaNodeBaseWriter extends _JavaWriter {
  final String name;
  final String nodeName;
  final String patchName;
  final String presenterName;

  _JavaNodeBaseWriter(String name, String fileName)
      : super(fileName),
        name = name,
        nodeName = '${name}Node',
        patchName = '${name}Patch',
        presenterName = '${name}Presenter';
}

class _JavaNodePresenterWriter extends _JavaNodeBaseWriter {

  _JavaNodePresenterWriter(Struct node)
      : super(node.name, '${node.name}Presenter') {
    visitStruct(node);
  }

  visitStruct(Struct node) {
    writeHeader();
    write('public interface $presenterName');
    writeln(' extends NodePresenter<$nodeName, $patchName> {');
    writeln('  void present$name($nodeName node);');
    writeln('  void patch$name($patchName patch);');
    writeln('}');
  }
}

class _JavaNodeWriter extends _JavaNodeBaseWriter {

  _JavaNodeWriter(Struct node)
      : super(node.name, '${node.name}Node') {
    visitStruct(node);
  }

  visitStruct(Struct node) {
    writeHeader([
      'fletch.${nodeName}Data',
    ]);
    writeln('public final class $nodeName implements Node {');
    writeln();
    writeln('  // Public interface.');
    writeln();
    forEachSlot(node, null, writeFieldGetter);
    // TODO(zerny): Implement actions.
    writeln();
    writeln('  // Package private implementation.');
    writeln();
    writeConstructorFromData(node);
    writeln();
    writeConstructorFromPatch(node);
    writeln();
    forEachSlot(node, null, writeFieldBacking);
    writeln('}');
  }

  writeConstructorFromData(Struct node) {
    writeln('  $nodeName(${nodeName}Data data, ImmiRoot root) {');
    forEachSlot(node, null, writeFieldInitializationFromData);
    // TODO(zerny): Implement actions.
    writeln('  }');
  }

  writeConstructorFromPatch(Struct node) {
    writeln('  $nodeName($patchName patch) {');
    forEachSlot(node, null, writeFieldInitializationFromPatch);
    // TODO(zerny): Implement actions.
    writeln('  }');
  }

  writeFieldGetter(Type type, String name) {
    String typeName = getTypeName(type);
    writeln('  public $typeName get${camelize(name)}() { return $name; }');
  }

  writeFieldBacking(Type type, String name) {
    String typeName = getTypeName(type);
    writeln('  private $typeName $name;');
  }

  writeFieldInitializationFromData(Type type, String name) {
    String camelName = camelize(name);
    String typeName = getTypeName(type);
    write('    $name = ');
    if (type.isList) {
      // TODO(zerny): Implement list support.
      imports.add('java.util.Collections');
      imports.add('java.util.ArrayList');
      writeln('Collections.unmodifiableList(new ArrayList());');
    } else if (type.isNode || type.resolved != null) {
      writeln('new $typeName(data.get$camelName(), root);');
    } else {
      writeln('data.get$camelName();');
    }
  }

  writeFieldInitializationFromPatch(Type type, String name) {
    String camelName = camelize(name);
    writeln('    $name = patch.get$camelName().getCurrent();');
  }
}

class _JavaNodePatchWriter extends _JavaNodeBaseWriter {

  _JavaNodePatchWriter(Struct node)
      : super(node.name, '${node.name}Patch') {
    visitStruct(node);
  }

  visitStruct(Struct node) {
    writeHeader([
      'fletch.${patchName}Data',
      'fletch.${node.name}UpdateData',
      'fletch.${node.name}UpdateDataList',
      'java.util.List',
    ]);
    write('public final class $patchName');
    writeln(' implements NodePatch<$nodeName, $presenterName> {');
    writeln();
    writeln('  // Public interface.');
    writeln();
    writeln('  @Override');
    write('  public boolean hasChanged()');
    writeln(' { return type != PatchType.IdentityNodePatch; }');
    writeln('  @Override');
    write('  public boolean wasReplaced()');
    writeln(' { return type == PatchType.ReplaceNodePatch; }');
    writeln('  @Override');
    write('  public boolean wasUpdated()');
    writeln(' { return type == PatchType.UpdateNodePatch; }');
    writeln();
    writeln('  @Override');
    writeln('  public $nodeName getCurrent() { return current; }');
    writeln('  @Override');
    writeln('  public $nodeName getPrevious() { return previous; }');
    writeln();
    forEachSlot(node, null, writeFieldGetter);
    writeln();
    writeln('  @Override');
    writeln('  public void applyTo($presenterName presenter) {');
    writeln('    if (!hasChanged()) return;');
    writeln('    if (wasReplaced()) {');
    writeln('      presenter.presentNode(current);');
    writeln('    } else {');
    writeln('      assert wasUpdated();');
    writeln('      presenter.patchNode(this);');
    writeln('    }');
    writeln('  }');
    writeln();
    writeln('  // Package private implementation.');
    writeln();
    writeConstructorIdentity();
    writeln();
    writeConstructorFromData(node);
    writeln();
    writeln('  private PatchType type;');
    writeln('  private $nodeName current;');
    writeln('  private $nodeName previous;');
    forEachSlot(node, null, writeFieldBacking);
    writeln('}');
  }

  writeConstructorIdentity() {
    writeln('  $patchName($nodeName previous) {');
    writeln('    this.previous = previous;');
    writeln('    current = previous;');
    writeln('    type = PatchType.IdentityNodePatch;');
    writeln('  }');
  }

  writeConstructorFromData(Struct node) {
    writeln('  $patchName(${patchName}Data data, $nodeName previous, ImmiRoot root) {');
    writeln('    this.previous = previous;');
    if (node.layout.slots.isNotEmpty || node.methods.isNotEmpty) {
      // The updates list is ordered consistently with the struct members.
      writeln('    if (data.isUpdates()) {');
      writeln('      ${name}UpdateDataList updates = data.getUpdates();');
      writeln('      int length = updates.size();');
      writeln('      int next = 0;');
      forEachSlot(node, null, writeFieldInitializationFromData);
      // TODO(zerny): Implement actions.
      writeln('      assert next == length;');
      writeln('      type = PatchType.UpdateNodePatch;');
      writeln('      current = new $nodeName(this);');
      writeln('      return;');
      writeln('    }');
    }
    writeln('    assert data.isReplace();');
    writeln('    type = PatchType.ReplaceNodePatch;');
    writeln('    current = new $nodeName(data.getReplace(), root);');
    writeln('  }');
  }

  writeFieldGetter(Type type, String name) {
    String camelName = camelize(name);
    String patchTypeName = getPatchTypeName(type);
    writeln('  public $patchTypeName get$camelName() { return $name; }');
  }

  writeFieldBacking(Type type, String name) {
    String patchTypeName = getPatchTypeName(type);
    writeln('  private $patchTypeName $name;');
  }

  writeFieldInitializationFromData(Type type, String name) {
    String camelName = camelize(name);
    String patchTypeName = getPatchTypeName(type);
    String dataGetter = 'updates.get(next++).get$camelName';
    writeln('      if (next < length && updates.get(next).is$camelName()) {');
    writeln('        $name = new $patchTypeName(');
    writeln('            $dataGetter(), previous.get$camelName(), root);');
    writeln('      }');
  }
}

class _AnyNodeWriter extends _JavaNodeBaseWriter {
  final String nodeName = 'AnyNode';

  _AnyNodeWriter(Map units)
      : super('AnyNode', 'AnyNode') {
    writeHeader([
      'fletch.NodeData',
    ]);
    writeln('public final class $nodeName implements Node {');
    writeln();
    writeln('  // Public interface.');
    writeln();
    writeln('  public boolean is(java.lang.Class clazz) {');
    writeln('    return clazz.isInstance(node);');
    writeln('  }');
    writeln('  public <T> T as(java.lang.Class<T> clazz) {');
    writeln('    return clazz.cast(node);');
    writeln('  }');
    writeln();
    writeln('  // Package private implementation.');
    writeln();
    writeln('  $nodeName(Node node) {');
    writeln('    this.node = node;');
    writeln('  }');
    writeln();
    writeln('  $nodeName(NodeData data, ImmiRoot root) {');
    units.values.forEach(visit);
    writeln('    throw new RuntimeException("Invalid node-type tag");');
    writeln('  }');
    writeln();
    writeln('  private Node node;');
    writeln('}');
  }

  visitUnit(Unit unit) {
    unit.structs.forEach(visit);
  }

  visitStruct(Struct node) {
    writeln('    if (data.is${node.name}()) {');
    writeln('      node = new ${node.name}Node(data.get${node.name}(), root);');
    writeln('      return;');
    writeln('    }');
  }
}

class _AnyNodePatchWriter extends _JavaNodeBaseWriter {
  final String nodeName = 'AnyNode';

  _AnyNodePatchWriter(Map units)
      : super('AnyNode', 'AnyNodePatch') {
    writeHeader([
      'fletch.NodePatchData',
    ]);
    write('public final class $patchName');
    writeln(' implements NodePatch<$nodeName, $presenterName> {');
    writeln();
    writeln('  // Public interface.');
    writeln();
    writeln('  @Override');
    write('  public boolean hasChanged()');
    writeln(' { return patch != null; }');
    writeln('  @Override');
    write('  public boolean wasReplaced()');
    writeln(' { return patch != null && patch.wasReplaced(); }');
    writeln('  @Override');
    write('  public boolean wasUpdated()');
    writeln(' { return patch != null && patch.wasUpdated(); }');
    writeln();
    writeln('  @Override');
    writeln('  public $nodeName getCurrent() { return current; }');
    writeln('  @Override');
    writeln('  public $nodeName getPrevious() { return previous; }');
    writeln();
    writeln('  @Override');
    writeln('  public void applyTo($presenterName presenter) {');
    writeln('    if (!hasChanged()) return;');
    writeln('    if (wasReplaced()) {');
    writeln('      presenter.presentNode(current);');
    writeln('    } else {');
    writeln('      assert wasUpdated();');
    writeln('      presenter.patchNode(this);');
    writeln('    }');
    writeln('  }');
    writeln();
    writeln('  // Package private implementation.');
    writeln();
    writeln('  $patchName(NodePatchData data, $nodeName previous, ImmiRoot root) {');
    writeln('    this.previous = previous;');
    // Create the patch based on the concrete type-tag.
    units.values.forEach(visit);
    writeln('    throw new RuntimeException("Unknown node-patch tag");');
    writeln('  }');
    writeln();
    writeln('  private NodePatch patch;');
    writeln('  private $nodeName current;');
    writeln('  private $nodeName previous;');
    writeln('}');
  }

  visitUnit(Unit unit) {
    unit.structs.forEach(visit);
  }

  visitStruct(Struct node) {
    String name = node.name;
    String patchName = '${name}Patch';
    String nodeName = '${name}Node';
    writeln('    if (data.is$name()) {');
    writeln('      $nodeName typedPrevious = null;');
    writeln('      if (previous != null && previous.is($nodeName.class)) {');
    writeln('        typedPrevious = previous.as($nodeName.class);');
    writeln('      }');
    writeln('      $patchName typedPatch =');
    writeln('          new $patchName(data.get$name(), typedPrevious, root);');
    writeln('      current = new AnyNode(typedPatch.getCurrent());');
    writeln('      patch = typedPatch;');
    writeln('      return;');
    writeln('    }');
  }
}
