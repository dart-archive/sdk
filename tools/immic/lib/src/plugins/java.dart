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
  'Action.java',
  'ActionPatch.java',
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
  var actions = new _ActionsCollector();
  new _AnyNodeWriter(units).writeTo(outputDirectory);
  new _AnyNodePatchWriter(units).writeTo(outputDirectory);
  for (Unit unit in units.values) {
    actions.collectMethodSignatures(unit);
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
  for (var types in actions.methodSignatures.values) {
    _JavaActionWriter.fromTypes(types.toList()).writeTo(outputDirectory);
  }
}

class _ActionsCollector extends CodeGenerationVisitor {
  _ActionsCollector() : super(null);
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

  String getNodeDataTypeName(Type type) {
    if (type.isList && type.elementType.isNode) return 'NodeDataList';
    if (type.isList) return '${getNonListTypeName(type)}DataList';
    if (type.isNode) return 'NodeData';
    assert(type.resolved != null);
    return '${type.identifier}NodeData';
  }

  String getPatchTypeName(Type type) {
    if (type.isList) return 'ListPatch<${getNonListTypeName(type)}>';
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
    writeln('  $className($javaType previous) {');
    writeln('    this.previous = previous;');
    writeln('    current = previous;');
    writeln('  }');
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

class _JavaActionWriter extends _JavaWriter {
  Method method;
  List<Type> types;
  List<String> arguments;

  _JavaActionWriter(this.method, this.types, this.arguments)
      : super(null);

  static _JavaActionWriter fromTypes(List<Type> types) {
    int i = 0;
    return new _JavaActionWriter(
        null,
        types,
        types.map((_) => 'arg${i++}').toList());
  }

  static _JavaActionWriter fromMethod(Method method) {
    return new _JavaActionWriter(
        method,
        method.arguments.map((f) => f.type).toList(),
        method.arguments.map((f) => f.name).toList());
  }

  writeTo(String outputDirectory) {
    bool boxedArguments = types.any((t) => t.isString);
    writeHeader([
      'fletch.ImmiServiceLayer',
    ]);
    writeln('public final class $className implements Action {');
    writeln();
    writeln('  // Public interface.');
    writeln();
    writeln('  public void dispatch($actionFormals) {');
    writeln('    root.dispatch(new Runnable() {');
    writeln('      @Override');
    writeln('      public void run() {');
    if (boxedArguments) {
      String builder = actionArgsBuilder;
      imports.add('fletch.MessageBuilder');
      imports.add('fletch.$builder');
      writeln('        int space = 48 + $builder.kSize;');
      for (int i = 0; i < types.length; ++i) {
        if (types[i].isString) {
          writeln('        space += ${arguments[i]}.length();');
        }
      }
      writeln('        MessageBuilder message = new MessageBuilder(space);');
      writeln('        $builder args = new $builder();');
      writeln('        message.initRoot(args, $builder.kSize);');
      writeln('        args.setId(id);');
      arguments.forEach((a) {
        writeln('        args.set${camelize(a)}($a);');
      });
    }
    write('        ImmiServiceLayer.dispatch${actionSuffix}Async(');
    if (boxedArguments) {
      write('args, ');
    } else {
      write('id, ');
      arguments.forEach((a) { write('$a, '); });
    }
    writeln('null);');
    writeln('      }');
    writeln('    });');
    writeln('  }');
    writeln();
    writeln('  // Package private implementation.');
    writeln();
    writeln('  $className(int id, ImmiRoot root) {');
    writeln('    this.id = id;');
    writeln('    this.root = root;');
    writeln('  }');
    writeln();
    writeln('  private int id;');
    writeln('  private ImmiRoot root;');
    writeln('}');
    super.writeTo(outputDirectory);
  }

  // Override className since we can't provide it in the constructor.
  String get className => actionName;

  String get actionFormals {
    int i = 0;
    return types.map((t) => 'final ${getTypeName(t)} arg${i++}').join(', ');
  }

  String get actionName {
    return 'Action${actionSuffix}';
  }

  String get actionPatchName {
    return 'ActionPatch<$actionName>';
  }

  String get actionSuffix {
    if (types.isEmpty) return 'Void';
    return types.map((t) => camelize(t.identifier)).join();
  }

  String get actionArgsBuilder {
    return '${actionName}ArgsBuilder';
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
  Struct node;
  Iterable<_JavaNodeWriter> actions;

  _JavaNodeWriter(Struct node)
      : super(node.name, '${node.name}Node') {
    visitStruct(node);
  }

  visitStruct(Struct node) {
    this.node = node;
    actions = node.methods.map(_JavaActionWriter.fromMethod);
    writeHeader([
      'fletch.${nodeName}Data',
    ]);
    writeln('public final class $nodeName implements Node {');
    writeln();
    writeln('  // Public interface.');
    writeln();
    forEachSlot(node, null, writeFieldGetter);
    actions.forEach(writeActionGetter);
    writeln();
    writeln('  // Package private implementation.');
    writeln();
    writeConstructorFromData();
    writeln();
    writeConstructorFromPatch();
    writeln();
    forEachSlot(node, null, writeFieldBacking);
    actions.forEach(writeActionBacking);
    writeln('}');
  }

  writeConstructorFromData() {
    writeln('  $nodeName(${nodeName}Data data, ImmiRoot root) {');
    forEachSlot(node, null, writeFieldInitializationFromData);
    actions.forEach(writeActionInitializationFromData);
    writeln('  }');
  }

  writeConstructorFromPatch() {
    writeln('  $nodeName($patchName patch) {');
    forEachSlot(node, null, writeFieldInitializationFromPatch);
    actions.forEach(writeActionInitializationFromPatch);
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
    if (type.isList) {
      String typeName = getNonListTypeName(type);
      String dataName = getNodeDataTypeName(type);
      imports.add('fletch.$dataName');
      imports.add('java.util.Collections');
      imports.add('java.util.ArrayList');
      writeln('    {');
      writeln('      $dataName dataList = data.get$camelName();');
      writeln('      int length = dataList.size();');
      writeln('      List<$typeName> list = new ArrayList<$typeName>(length);');
      writeln('      for (int i = 0; i < length; ++i) {');
      writeln('        list.add(new $typeName(dataList.get(i), root));');
      writeln('      }');
      writeln('      $name = Collections.unmodifiableList(list);');
      writeln('    }');
    } else if (type.isNode || type.resolved != null) {
      writeln('    $name = new $typeName(data.get$camelName(), root);');
    } else {
      writeln('    $name = data.get$camelName();');
    }
  }

  writeFieldInitializationFromPatch(Type type, String name) {
    String camelName = camelize(name);
    writeln('    $name = patch.get$camelName().getCurrent();');
  }

  writeActionBacking(_JavaActionWriter action) {
    String name = action.method.name;
    writeln('  private ${action.actionName} $name;');
  }

  writeActionGetter(_JavaActionWriter action) {
    String name = action.method.name;
    String camelName = camelize(name);
    writeln('  public ${action.actionName} get$camelName() { return $name; }');
  }

  writeActionInitializationFromData(_JavaActionWriter action) {
    String name = action.method.name;
    Strin camelName = camelize(name);
    writeln('    $name = new ${action.actionName}(data.get$camelName(), root);');
  }

  writeActionInitializationFromPatch(_JavaActionWriter action) {
    String name = action.method.name;
    Strin camelName = camelize(name);
    writeln('    $name = patch.get$camelName().getCurrent();');
  }
}

class _JavaNodePatchWriter extends _JavaNodeBaseWriter {
  Struct node;
  Iterable<_JavaNodeWriter> actions;

  _JavaNodePatchWriter(Struct node)
      : super(node.name, '${node.name}Patch') {
    visitStruct(node);
  }

  visitStruct(Struct node) {
    this.node = node;
    actions = node.methods.map(_JavaActionWriter.fromMethod);
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
    actions.forEach(writeActionGetter);
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
    writeConstructorFromData();
    writeln();
    writeln('  private PatchType type;');
    writeln('  private $nodeName current;');
    writeln('  private $nodeName previous;');
    forEachSlot(node, null, writeFieldBacking);
    actions.forEach(writeActionBacking);
    writeln('}');
  }

  writeConstructorIdentity() {
    writeln('  $patchName($nodeName previous) {');
    writeln('    this.previous = previous;');
    writeln('    current = previous;');
    writeln('    type = PatchType.IdentityNodePatch;');
    writeln('  }');
  }

  writeConstructorFromData() {
    writeln('  $patchName(${patchName}Data data, $nodeName previous, ImmiRoot root) {');
    writeln('    this.previous = previous;');
    if (node.layout.slots.isNotEmpty || node.methods.isNotEmpty) {
      // The updates list is ordered consistently with the struct members.
      writeln('    if (data.isUpdates()) {');
      writeln('      ${name}UpdateDataList updates = data.getUpdates();');
      writeln('      int length = updates.size();');
      writeln('      int next = 0;');
      forEachSlot(node, null, writeFieldInitializationFromData);
      actions.forEach(writeActionInitializationFromData);
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
    writeln('      } else {');
    writeln('        $name = new $patchTypeName(previous.get$camelName());');
    writeln('      }');
  }

  writeActionGetter(_JavaActionWriter action) {
    String name = action.method.name;
    String camelName = camelize(name);
    writeln('  public ${action.actionPatchName} get$camelName() {');
    writeln('    return $name;');
    writeln('  }');
  }

  writeActionBacking(_JavaActionWriter action) {
    String name = action.method.name;
    writeln('  private ${action.actionPatchName} $name;');
  }

  writeActionInitializationFromData(_JavaActionWriter action) {
    String name = action.method.name;
    String camelName = camelize(name);
    String actionName = action.actionName;
    String patchTypeName = action.actionPatchName;
    String dataGetter = 'updates.get(next++).get$camelName';
    writeln('      if (next < length && updates.get(next).is$camelName()) {');
    writeln('        $name = new $patchTypeName(');
    writeln('            new $actionName($dataGetter(), root),');
    writeln('            previous.get$camelName(),');
    writeln('            root);');
    writeln('      } else {');
    writeln('        $name = new $patchTypeName(previous.get$camelName());');
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
    writeln('    node = fromData(data, root);');
    writeln('  }');
    writeln();
    writeln('  static Node fromData(NodeData data, ImmiRoot root) {');
    units.values.forEach(visit);
    writeln('    throw new RuntimeException("Invalid node-type tag");');
    writeln('  }');
    writeln();
    writeln('  Node getNode() { return node; }');
    writeln();
    writeln('  private Node node;');
    writeln('}');
  }

  visitUnit(Unit unit) {
    unit.structs.forEach(visit);
  }

  visitStruct(Struct node) {
    write('    if (data.is${node.name}())');
    writeln(' return new ${node.name}Node(data.get${node.name}(), root);');
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
    writeln('  public boolean is(java.lang.Class clazz) {');
    writeln('    return clazz.isInstance(patch);');
    writeln('  }');
    writeln('  public <T> T as(java.lang.Class<T> clazz) {');
    writeln('    return clazz.cast(patch);');
    writeln('  }');
    writeln();
    writeln('  // Package private implementation.');
    writeln();
    writeln('  $patchName($nodeName previous) {');
    writeln('    this.previous = previous;');
    writeln('    current = previous;');
    writeln('  }');
    writeln();
    writeln('  $patchName(');
    writeln('        NodePatchData data,');
    writeln('        $nodeName previous,');
    writeln('        ImmiRoot root) {');
    writeln('    Node node = previous == null ? null : previous.getNode();');
    writeln('    patch = fromData(data, node, root);');
    writeln('    current = new AnyNode(patch.getCurrent());');
    writeln('    this.previous = previous;');
    writeln('  }');
    writeln();
    writeln('  static NodePatch fromData(');
    writeln('      NodePatchData data,');
    writeln('      Node previous,');
    writeln('      ImmiRoot root) {');
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
    writeln('      if (previous instanceof $nodeName) {');
    writeln('        typedPrevious = ($nodeName)previous;');
    writeln('      }');
    writeln('      return new $patchName(');
    writeln('          data.get$name(), typedPrevious, root);');
    writeln('    }');
  }
}
