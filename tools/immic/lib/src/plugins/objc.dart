// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.plugins.cc;

import 'dart:core' hide Type;
import 'dart:io' show Platform, File;

import 'package:path/path.dart' show basenameWithoutExtension, join, dirname;

import 'shared.dart';

import '../emitter.dart';
import '../primitives.dart' as primitives;
import '../struct_layout.dart';

const COPYRIGHT = """
// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
""";

const Map<String, String> _TYPES = const {
  'void'    : 'void',
  'bool'    : 'bool',

  'uint8'   : 'uint8_t',
  'uint16'  : 'uint16_t',
  'uint32'  : 'uint32_t',
  'uint64'  : 'uint64_t',

  'int8'    : 'int8_t',
  'int16'   : 'int16_t',
  'int32'   : 'int32_t',
  'int64'   : 'int64_t',

  'float32' : 'float',
  'float64' : 'double',

  'String' : 'NSString*',
};

String getTypePointer(Type type) {
  if (type.isNode) return 'Node*';
  if (type.resolved != null) {
    return "${type.identifier}Node*";
  }
  return _TYPES[type.identifier];
}

String getTypeName(Type type) {
  if (type.isNode) return 'Node';
  if (type.resolved != null) {
    return "${type.identifier}Node";
  }
  return _TYPES[type.identifier];
}

void generate(String path, Map units, String outputDirectory) {
  String directory = join(outputDirectory, "objc");
  _generateHeaderFile(path, units, directory);
  _generateImplementationFile(path, units, directory);
}

void _generateHeaderFile(String path, Map units, String directory) {
  _HeaderVisitor visitor = new _HeaderVisitor(path);
  visitor.visitUnits(units);
  String contents = visitor.buffer.toString();
  writeToFile(directory, path, contents, extension: 'h');
}

void _generateImplementationFile(String path, Map units, String directory) {
  _ImplementationVisitor visitor = new _ImplementationVisitor(path);
  visitor.visitUnits(units);
  String contents = visitor.buffer.toString();
  writeToFile(directory, path, contents, extension: 'mm');
}

  String getName(node) {
    if (node is Struct) return node.name;
    if (node is String) return node;
    throw 'Invalid arg';
  }

  String applyToMethodName(node) {
    return 'applyTo';
  }

  String presentMethodName(node) {
    String name = getName(node);
    return 'present${name}';
  }

  String patchMethodName(node) {
    String name = getName(node);
    return 'patch${name}';
  }

  String applyToMethodSignature(node) {
    String name = getName(node);
    return '- (void)${applyToMethodName(name)}:(id <${name}Presenter>)presenter';
  }

  String presentMethodSignature(node) {
    String name = getName(node);
    String type = name == 'Node' ? name : '${name}Node';
    return '- (void)${presentMethodName(name)}:(${type}*)node';
  }

  String patchMethodSignature(node) {
    String name = getName(node);
    return '- (void)${patchMethodName(name)}:(${name}Patch*)patch';
  }

  String applyToMethodDeclaration(Struct node) {
    return applyToMethodSignature(node) + ';';
  }

  String presentMethodDeclaration(Struct node) {
    return presentMethodSignature(node) + ';';
  }

  String patchMethodDeclaration(Struct node) {
    return patchMethodSignature(node) + ';';
  }

class _HeaderVisitor extends CodeGenerationVisitor {
  _HeaderVisitor(String path) : super(path);

  List nodes = [];

  visitUnits(Map units) {
    units.values.forEach(collectMethodSignatures);
    units.values.forEach((unit) { nodes.addAll(unit.structs); });
    _writeHeader();
    _writeNodeBase();
    _writePatchBase();
    _writePatchPrimitives();
    _writeActions();
    units.values.forEach(visit);
    _writeImmiRoot();
    _writeImmiService();
  }

  visitUnit(Unit unit) {
    unit.structs.forEach(visit);
  }

  visitStruct(Struct node) {
    StructLayout layout = node.layout;
    String nodeName = "${node.name}Node";
    String nodeNameData = "${nodeName}Data";
    String patchName = "${node.name}Patch";
    String patchNameData = "${nodeName}PatchData";
    String presenterName = "${node.name}Presenter";
    writeln('@interface $nodeName : NSObject <Node>');
    forEachSlot(node, null, (Type slotType, String slotName) {
      write('@property (readonly) ');
      _writeNSType(slotType);
      writeln(' $slotName;');
    });
    for (var method in node.methods) {
      List<Type> formalTypes = method.arguments.map((formal) => formal.type);
      String actionBlock = 'Action${actionTypeSuffix(formalTypes)}Block';
      writeln('@property (readonly) $actionBlock ${method.name};');
    }
    writeln('@end');
    writeln();
    writeln('@protocol $presenterName');
    writeln(presentMethodDeclaration(node));
    writeln(patchMethodDeclaration(node));
    writeln('@end');
    writeln();
    writeln('@interface $patchName : NSObject <NodePatch>');
    writeln('@property (readonly) bool changed;');
    forEachSlot(node, null, (Type slotType, String slotName) {
      writeln('@property (readonly) ${patchType(slotType)}* $slotName;');
    });
    for (var method in node.methods) {
      String actionPatch = actionPatchType(method);
      writeln('@property (readonly) $actionPatch* ${method.name};');
    }
    writeln('- ($nodeName*)applyWith:($nodeName*)node;');
    writeln(applyToMethodDeclaration(node));
    writeln('@end');
    writeln();
  }

  void _writeFormalWithKeyword(String keyword, Formal formal) {
    write('$keyword:(${getTypeName(formal.type)})${formal.name}');
  }

  void _writeNodeBase() {
    writeln('@protocol Node <NSObject>');
    writeln('@end');
    writeln();
    nodes.forEach((node) { writeln('@class ${node.name}Node;'); });
    writeln();
    writeln('@interface Node : NSObject <Node>');
    nodes.forEach((node) { writeln('- (bool)is${node.name};'); });
    nodes.forEach((node) { writeln('- (${node.name}Node*)as${node.name};'); });
    writeln('@end');
    writeln();
  }

  void _writePatchBase() {
    writeln('@protocol Patch <NSObject>');
    writeln('@property (readonly) bool changed;');
    writeln('@end');
    writeln();
    writeln('@class NodePatch;');
    nodes.forEach((node) { writeln('@class ${node.name}Patch;'); });
    writeln();
    writeln('@protocol NodePresenter <NSObject>');
    writeln(presentMethodDeclaration('Node'));
    writeln(patchMethodDeclaration('Node'));
    writeln('@end');
    writeln();
    writeln('@protocol NodePatch <Patch>');
    writeln('@property (readonly) bool replaced;');
    writeln('@property (readonly) bool updated;');
    writeln('- (id <Node>)node;');
    writeln('- (id <Node>)applyWith:(id <Node>)node;');
    writeln('@end');
    writeln();
    writeln('@interface NodePatch : NSObject <NodePatch>');
    writeln('@property (readonly) bool changed;');
    writeln('- (Node*)applyWith:(Node*)node;');
    writeln(applyToMethodDeclaration('Node'));
    nodes.forEach((node) { writeln('- (bool)is${node.name};'); });
    nodes.forEach((node) { writeln('- (${node.name}Patch*)as${node.name};'); });
    writeln('@end');
    writeln();
  }

  void _writePatchPrimitives() {
    _TYPES.forEach((String idlType, String objcType) {
      if (idlType == 'void') return;
      writeln('@interface ${camelize(idlType)}Patch : NSObject <Patch>');
      writeln('@property (readonly) bool changed;');
      writeln('@property (readonly) $objcType value;');
      writeln('- ($objcType)applyWith:($objcType)value;');
      writeln('@end');
      writeln();
    });
    writeln('@interface ListPatch : NSObject <Patch>');
    writeln('@property (readonly) bool changed;');
    writeln('- (NSArray*)applyWith:(NSArray*)array;');
    writeln('@end');
    writeln();
  }

  _writeActions() {
    for (List<Type> formals in methodSignatures.values) {
      String actionName = 'Action${actionTypeSuffix(formals)}';
      String actionBlock = '${actionName}Block';
      String actionPatch = '${actionName}Patch';
      write('typedef void (^$actionBlock)(${actionTypeFormals(formals)});');
      writeln();
      writeln('@interface $actionPatch : NSObject <Patch>');
      writeln('- ($actionBlock)applyWith:($actionBlock)block;');
      writeln('@end');
      writeln();
    }
  }

  void _writeImmiService() {
    writeln('@interface ImmiService : NSObject');
    writeln('- (ImmiRoot*)registerPresenter:(id <NodePresenter>)presenter');
    writeln('                       forName:(NSString*)name;');
    writeln('- (void)registerStoryboard:(UIStoryboard*)storyboard;');
    writeln('- (ImmiRoot*)getRootByName:(NSString*)name;');
    writeln('- (id <NodePresenter>)getPresenterByName:(NSString*)name;');
    writeln('@end');
    writeln();
  }

  void _writeImmiRoot() {
    writeln('typedef void (^ImmiDispatchBlock)();');
    writeln('@interface ImmiRoot : NSObject');
    writeln('- (void)refresh;');
    writeln('- (void)reset;');
    writeln('- (void)dispatch:(ImmiDispatchBlock)block;');
    writeln('@end');
    writeln();
  }

  void _writeNSType(Type type) {
    if (type.isList) {
      write('NSArray*');
    } else {
      write(getTypePointer(type));
    }
  }

  void _writeHeader() {
    String fileName = basenameWithoutExtension(path);
    writeln(COPYRIGHT);
    writeln('// Generated file. Do not edit.');
    writeln();
    writeln('#import <Foundation/Foundation.h>');
    writeln('#import <UIKit/UIKit.h>');
    writeln('#include "${serviceFile}.h"');
    writeln();
  }

  String patchType(Type type) {
    if (type.isList) return 'ListPatch';
    return '${camelize(type.identifier)}Patch';
  }

  String actionTypeSuffix(List<Type> types) {
    if (types.isEmpty) return 'Void';
    return types.map((Type type) => camelize(type.identifier)).join();
  }

  String actionTypeFormals(List<Type> types) {
    return types.map((Type type) => getTypeName(type)).join(', ');
  }

  String actionPatchType(Method method) {
    List<Type> types = method.arguments.map((formal) => formal.type);
    return 'Action${actionTypeSuffix(types)}Patch';
  }

  String actionBlockType(Method method) {
    List<Type> types = method.arguments.map((formal) => formal.type);
    return 'Action${actionTypeSuffix(types)}Block';
  }
}

class _ImplementationVisitor extends CodeGenerationVisitor {
  _ImplementationVisitor(String path) : super(path);

  List<Struct> nodes = [];

  visitUnits(Map units) {
    units.values.forEach(collectMethodSignatures);
    units.values.forEach((unit) { nodes.addAll(unit.structs); });
    _writeHeader();

    _writeNodeBaseExtendedInterface();
    _writePatchBaseExtendedInterface();
    _writePatchPrimitivesExtendedInterface();
    _writeActionsExtendedInterface();
    units.values.forEach((unit) {
      unit.structs.forEach(_writeNodeExtendedInterface);
    });

    _writeImmiServiceExtendedInterface();
    _writeImmiRootExtendedInterface();

    _writeEventUtils();
    _writeStringUtils();
    _writeListUtils();

    _writeNodeBaseImplementation();
    _writePatchBaseImplementation();
    _writePatchPrimitivesImplementation();
    _writeActionsImplementation();
    units.values.forEach((unit) {
      unit.structs.forEach(_writeNodeImplementation);
    });

    _writeImmiServiceImplementation();
    _writeImmiRootImplementation();
  }

  visitUnit(Unit unit) {
    // Everything is done in visitUnits.
  }

  _writeImmiServiceExtendedInterface() {
    writeln('@interface ImmiService ()');
    writeln('@property NSMutableArray* storyboards;');
    writeln('@property NSMutableDictionary* roots;');
    writeln('@end');
    writeln();
  }

  _writeImmiServiceImplementation() {
    writeln('@implementation ImmiService');
    writeln();
    writeln('- (id)init {');
    writeln('  _storyboards = [NSMutableArray array];');
    writeln('  _roots = [NSMutableDictionary dictionary];');
    writeln('  return self;');
    writeln('}');
    writeln();
    writeln('- (ImmiRoot*)registerPresenter:(id <NodePresenter>)presenter');
    writeln('                       forName:(NSString*)name {');
    writeln('  assert(self.roots[name] == nil);');
    writeln('  int length = name.length;');
    writeln('  int size = 48 + PresenterDataBuilder::kSize + length;');
    writeln('  MessageBuilder message(size);');
    writeln('  PresenterDataBuilder builder =');
    writeln('      message.initRoot<PresenterDataBuilder>();');
    writeln('  List<unichar> chars = builder.initNameData(length);');
    writeln('  [name getCharacters:chars.data()');
    writeln('                range:NSMakeRange(0, length)];');
    writeln('  uint16_t pid = ImmiServiceLayer::getPresenter(builder);');
    writeln('  ImmiRoot* root =');
    writeln('     [[ImmiRoot alloc] init:pid presenter:presenter];');
    writeln('  self.roots[name] = root;');
    writeln('  return root;');
    writeln('}');
    writeln();
    writeln('- (void)registerStoryboard:(UIStoryboard*)storyboard {');
    writeln('  [self.storyboards addObject:storyboard];');
    writeln('}');
    writeln();
    writeln('- (ImmiRoot*)getRootByName:(NSString*)name {');
    writeln('  ImmiRoot* root = self.roots[name];');
    writeln('  if (root != nil) return root;');
    writeln('  id <NodePresenter> presenter = nil;');
    writeln('  for (int i = 0; i < self.storyboards.count; ++i) {');
    writeln('    @try {');
    writeln('      presenter = [self.storyboards[i]');
    writeln('          instantiateViewControllerWithIdentifier:name];');
    writeln('      break;');
    writeln('    }');
    writeln('    @catch (NSException* e) {');
    writeln('      if (e.name != NSInvalidArgumentException) {');
    writeln('        @throw e;');
    writeln('      }');
    writeln('    }');
    writeln('  }');
    writeln('  if (presenter == nil) abort();');
    writeln('  return [self registerPresenter:presenter forName:name];');
    writeln('}');
    writeln();
    writeln('- (id <NodePresenter>)getPresenterByName:(NSString*)name {');
    writeln('  return [[self getRootByName:name] presenter];');
    writeln('}');
    writeln();
    writeln('@end');
    writeln();
  }

  _writeImmiRootExtendedInterface() {
    writeln('@interface ImmiRoot ()');
    writeln('@property (readonly) uint16_t pid;');
    writeln('@property (readonly) id <NodePresenter> presenter;');
    writeln('@property bool refreshPending;');
    writeln('@property bool refreshRequired;');
    writeln('@property (nonatomic) dispatch_queue_t refreshQueue;');
    writeln('- (id)init:(uint16_t)pid presenter:(id <NodePresenter>)presenter;');
    writeln('@end');
    writeln();
  }

  _writeImmiRootImplementation() {
    writeln('typedef void (^ImmiRefreshCallback)(const PatchData&);');
    writeln('void ImmiRefresh(PatchData patchData, void* callbackData) {');
    writeln('  ImmiRefreshCallback block =');
    writeln('      (__bridge_transfer ImmiRefreshCallback)callbackData;');
    writeln('  block(patchData);');
    writeln('  patchData.Delete();');
    writeln('}');
    writeln('@implementation ImmiRoot');
    writeln();
    writeln('- (id)init:(uint16_t)pid');
    writeln('    presenter:(id <NodePresenter>)presenter {');
    writeln('  assert(pid > 0);');
    writeln('  _pid = pid;');
    writeln('  _presenter = presenter;');
    writeln('  _refreshPending = false;');
    writeln('  _refreshRequired = false;');
    writeln('  _refreshQueue = dispatch_queue_create(');
    writeln('      "com.google.immi.refreshQueue", DISPATCH_QUEUE_SERIAL);');
    writeln('  return self;');
    writeln('}');
    writeln();
    writeln('- (void)refresh {');
    writeln('  ImmiRefreshCallback doApply = ^(const PatchData& patchData) {');
    writeln('      if (patchData.isNode()) {');
    writeln('        NodePatch* patch = [NodePatch patch:patchData.getNode()');
    writeln('                                    inGraph:self];');
    writeln('        [patch applyTo:self.presenter];');
    writeln('      }');
    writeln('      dispatch_async(self.refreshQueue, ^{');
    writeln('          if (self.refreshRequired) {');
    writeln('            self.refreshRequired = false;');
    writeln('            [self refresh];');
    writeln('          } else {');
    writeln('            self.refreshPending = false;');
    writeln('          }');
    writeln('      });');
    writeln('  };');
    writeln('  ${serviceName}::refreshAsync(');
    writeln('      self.pid, ImmiRefresh, (__bridge_retained void*)doApply);');
    writeln('}');
    writeln();
    writeln('- (void)reset {');
    writeln('  ${serviceName}::reset(self.pid);');
    writeln('}');
    writeln();
    writeln('- (void)dispatch:(ImmiDispatchBlock)block {');
    writeln('  block();');
    writeln('  [self requestRefresh];');
    writeln('}');
    writeln();
    writeln('- (void)requestRefresh {');
    writeln('  dispatch_async(self.refreshQueue, ^{');
    writeln('      if (self.refreshPending) {');
    writeln('        self.refreshRequired = true;');
    writeln('      } else {');
    writeln('        self.refreshPending = true;');
    writeln('        [self refresh];');
    writeln('      }');
    writeln('  });');
    writeln('}');
    writeln();
    writeln('@end');
    writeln();
  }

  _writeNodeExtendedInterface(Struct node) {
    String name = node.name;
    String nodeName = "${name}Node";
    String patchName = "${name}Patch";
    String nodeDataName = "${nodeName}Data";
    String patchDataName = "${patchName}Data";
    writeln('@interface $nodeName ()');
    if (node.methods.isNotEmpty) {
      writeln('@property (weak) ImmiRoot* root;');
    }
    writeln('- (id)initWith:(const $nodeDataName&)data');
    writeln('       inGraph:(ImmiRoot*)root;');
    writeln('- (id)initCopy:($nodeName*)node');
    writeln('     withPatch:($patchName*)patch;');
    writeln('@end');
    writeln();
    writeln('@interface $patchName ()');
    writeln('@property (readonly) $nodeName* node;');
    writeln('- (id)initWith:(const $patchDataName&)data');
    writeln('       inGraph:(ImmiRoot*)root;');
    writeln('@end');
    writeln();
  }

  _writeNodeImplementation(Struct node) {
    String name = node.name;
    String nodeName = "${node.name}Node";
    String patchName = "${node.name}Patch";
    String nodeDataName = "${nodeName}Data";
    String patchDataName = "${patchName}Data";
    String updateDataName = "${node.name}UpdateData";
    writeln('@implementation $nodeName');
    writeln('- (id)initWith:(const $nodeDataName&)data');
    writeln('       inGraph:(ImmiRoot*)root {');
    forEachSlot(node, null, (Type slotType, String slotName) {
      String camelName = camelize(slotName);
      write('  _$slotName = ');
      if (slotType.isList) {
        String slotTypeName = getTypeName(slotType.elementType.isNode ?
                                          slotType.elementType :
                                          slotType);
        String slotTypeData = "${slotTypeName}Data";
        writeln('ListUtils<$slotTypeData>::decodeList(');
        writeln('      data.get${camelName}(), create$slotTypeName, root);');
      } else if (slotType.isString) {
        writeln('decodeString(data.get${camelName}Data());');
      } else if (slotType.isNode) {
        writeln('[Node createNode:data.get${camelName}() inGraph:root];');
      } else if (slotType.resolved != null) {
        String slotTypeName = getTypeName(slotType);
        writeln('[[$slotTypeName alloc] initWith:data.get${camelName}()');
        writeln('                        inGraph:(ImmiRoot*)root];');
      } else {
        writeln('data.get${camelName}();');
      }
    });
    for (var method in node.methods) {
      List<Type> formals = method.arguments.map((formal) => formal.type);
      String suffix = actionTypeSuffix(formals);
      String actionBlock = actionBlockType(method);
      String actionBlockArgs = method.arguments.isEmpty ? '' :
                               '(${actionTypedArguments(method.arguments)})';
      String actionArgsComma = method.arguments.isEmpty ? '' :
                               '${actionArguments(method.arguments)}, ';
      String actionId = '${method.name}Id';
      writeln('  uint16_t $actionId = data.get${camelize(method.name)}();');
      writeln('  _${method.name} = ^$actionBlockArgs{');
      writeln('      [root dispatch:^{');
      writeln('          ${serviceName}::dispatch${suffix}Async(');
      writeln('            $actionId, $actionArgsComma');
      writeln('            noopVoidEventCallback, NULL);');
      writeln('      }];');
      writeln('  };');
    }
    writeln('  return self;');
    writeln('}');

    writeln('- (id)initCopy:($nodeName*)node withPatch:($patchName*)patch {');
    forEachSlot(node, null, (Type slotType, String slotName) {
      writeln('  _$slotName = [patch.$slotName applyWith:node.$slotName];');
    });
    for (Method method in node.methods) {
      String name = method.name;
      writeln('  _$name = [patch.$name applyWith:node.$name];');
    }
    writeln('  return self;');
    writeln('}');
    writeln('@end');
    writeln();
    writeln('@implementation $patchName');
    writeln('- (id)initEmptyPatch {');
    writeln('  _changed = false;');
    writeln('  return self;');
    writeln('}');
    writeln('- (id)initWith:(const $patchDataName&)data');
    writeln('       inGraph:(ImmiRoot*)root {');
    writeln('  _changed = true;');
    writeln('  if (data.isReplace()) {');
    writeln('    _node = [[$nodeName alloc] initWith:data.getReplace()');
    writeln('                                inGraph:root];');
    writeln('  } else {');
    if (node.layout.slots.isNotEmpty || node.methods.isNotEmpty) {
      // TODO(zerny): Ensure the order of updates and make the below O(n).
      writeln('    assert(data.isUpdates());');
      writeln('    List<$updateDataName> updates = data.getUpdates();');
      writeln('    for (int i = 0; i < updates.length(); ++i) {');
      writeln('      const ${updateDataName}& update = updates[i];');
      forEachSlot(node, null, (Type slotType, String slotName) {
        String slotPatchType = patchType(slotType);
        String slotNameCamel = camelize(slotName);
        writeln('      if (update.is${slotNameCamel}()) {');
        writeln('        _$slotName = [[$slotPatchType alloc]');
        write('                      ');
        if (!slotType.isList && slotType.isString) {
          writeln('initWith:decodeString(update.get${slotNameCamel}Data())');
        } else {
          writeln('initWith:update.get$slotNameCamel()');
        }
        writeln('                       inGraph:root];');
        writeln('        continue;');
        writeln('      }');
      });
      for (var method in node.methods) {
        String name = method.name;
        String camelName = camelize(name);
        List<Formal> formals = method.arguments.map((formal) => formal.type);
        String actionPatch = 'Action${actionTypeSuffix(formals)}Patch';
        String actionBlock = 'Action${actionTypeSuffix(formals)}Block';
        writeln('      if (update.is${camelName}()) {');
        writeln('        uint16_t actionId = update.get${camelName}();');
        write('        $actionBlock block =');
        _writeActionBlockImpl(method, 'actionId', '        ');
        writeln('        _${name} = [[$actionPatch alloc] initWith:block];');
        writeln('        continue;');
        writeln('      }');
      }
      writeln('    }');
    } else {
      writeln('    @throw [NSException');
      writeln('        exceptionWithName:NSInternalInconsistencyException');
      writeln('        reason:@"Singleton nodes cannot be updated"');
      writeln('        userInfo:nil];');
    }
    writeln('  }');
    forEachSlot(node, null, (Type slotType, String slotName) {
      writeln('  if (_$slotName == nil) {');
      String slotPatchType = patchType(slotType);
      writeln('    _$slotName = [[$slotPatchType alloc] initEmptyPatch];');
      writeln('  }');
    });
    for (Method method in node.methods) {
      String name = method.name;
      String actionPatch = actionPatchType(method);
      writeln('  if (_$name == nil) {');
      writeln('    _$name = [[$actionPatch alloc] initEmptyPatch];');
      writeln('  }');
    }
    writeln('  return self;');
    writeln('}');
    writeln('- (bool)replaced { return self.changed && self.node != nil; }');
    writeln('- (bool)updated { return self.changed && self.node == nil; }');
    write(applyToMethodSignature(node));
    writeln(' {');
    writeln('  if (self.node != nil) {');
    writeln('    [presenter present${node.name}:self.node];');
    writeln('  } else {');
    writeln('    [presenter patch${node.name}:self];');
    writeln('  }');
    writeln('}');
    writeln('- (${nodeName}*)applyWith:(${nodeName}*)node {');
    writeln('  if (!self.changed) return node;');
    writeln('  if (self.node) return self.node;');
    writeln('  return [[$nodeName alloc] initCopy:node withPatch:self];');
    writeln('}');
    writeln('@end');
    writeln();
  }

  void _writeNodeBaseExtendedInterface() {
    writeln('@interface Node ()');
    writeln('@property (readonly) id <Node> node;');
    writeln('- (id)init:(id <Node>)node;');
    writeln('+ (Node*)createNode:(const NodeData&)data');
    writeln('            inGraph:(ImmiRoot*)root;');
    writeln('+ (Node*)copyNode:(Node*)node');
    writeln('        withPatch:(NodePatch*)patch;');
    writeln('@end');
    writeln();
  }

  void _writeNodeBaseImplementation() {
    writeln('@implementation Node');
    nodes.forEach((node) {
      writeln('- (bool)is${node.name} {');
      writeln('  return [self.node isMemberOfClass:${node.name}Node.class];');
      writeln('}');
      writeln('- (${node.name}Node*)as${node.name} {');
      writeln('  NSAssert(');
      writeln('    self.is${node.name},');
      writeln('    @"Invalid cast. Expected ${node.name}Node, found %@",');
      writeln('    self.node.class);');
      writeln('  return (${node.name}Node*)self.node;');
      writeln('}');
    });
    writeln('+ (Node*)createNode:(const NodeData&)data');
    writeln('            inGraph:(ImmiRoot*)root {');
    writeln('  id <Node> node;');
    write(' ');
    nodes.forEach((node) {
      writeln(' if (data.is${node.name}()) {');
      writeln('    node = [[${node.name}Node alloc]');
      writeln('            initWith:data.get${node.name}()');
      writeln('             inGraph:root];');
      write('  } else');
    });
    writeln(' {');
    writeln('    abort();');
    writeln('  }');
    writeln('  return [[Node alloc] init:node];');
    writeln('}');
    writeln('+ (Node*)copyNode:(Node*)node withPatch:(NodePatch*)patch {');
    writeln('  id <Node> sub;');
    write(' ');
    nodes.forEach((node) {
      writeln(' if (node.is${node.name}) {');
      writeln('    sub = [[${node.name}Node alloc]');
      writeln('            initCopy:node.as${node.name}');
      writeln('           withPatch:patch.as${node.name}];');
      write('  } else');
    });
    writeln(' {');
    writeln('    abort();');
    writeln('  }');
    writeln('  return [[Node alloc] init:sub];');
    writeln('}');
    writeln('- (id)init:(id <Node>)node {');
    writeln('  _node = node;');
    writeln('  return self;');
    writeln('}');
    writeln('@end');
    writeln();
  }

  void _writePatchBaseExtendedInterface() {
    writeln('@interface NodePatch ()');
    writeln('@property (readonly) id <NodePatch> patch;');
    writeln('@property (readonly) Node* node;');
    writeln('- (id)initEmptyPatch;');
    writeln('+ (NodePatch*)patch:(const NodePatchData&)data');
    writeln('            inGraph:(ImmiRoot*)root;');
    writeln('@end');
    writeln();
  }

  void _writePatchBaseImplementation() {
    writeln('@implementation NodePatch');
    writeln('+ (NodePatch*)patch:(const NodePatchData&)data');
    writeln('            inGraph:(ImmiRoot*)root {');
    writeln('  return [[NodePatch alloc] initWith:data inGraph:root];');
    writeln('}');
    writeln('- (id)initEmptyPatch {');
    writeln('  _changed = false;');
    writeln('  _node = nil;');
    writeln('  return self;');
    writeln('}');
    writeln('- (id)initWith:(const NodePatchData&)data');
    writeln('       inGraph:(ImmiRoot*)root {');
    writeln('  _changed = true;');
    write(' ');
    nodes.forEach((node) {
      writeln(' if (data.is${node.name}()) {');
      writeln('    _patch = [[${node.name}Patch alloc]');
      writeln('              initWith:data.get${node.name}()');
      writeln('               inGraph:root];');
      write('  } else');
    });
    writeln(' {');
    writeln('    abort();');
    writeln('  }');
    writeln('  if (self.patch.node != nil) {');
    writeln('    _node = [[Node alloc] init:self.patch.node];');
    writeln('  }');
    writeln('  return self;');
    writeln('}');
    writeln();
    writeln('- (bool)replaced { return self.patch.replaced; }');
    writeln('- (bool)updated { return self.patch.updated; }');
    writeln();
    writeln('- (Node*)applyWith:(Node*)node {');
    writeln('  if (!self.changed) return node;');
    writeln('  if (self.node != nil) return self.node;');
    writeln('  return [Node copyNode:node withPatch:self];');
    writeln('}');
    writeln();
    write(applyToMethodSignature('Node'));
    writeln(' {');
    writeln('  if (!self.changed) return;');
    writeln('  if (self.node != nil) {');
    writeln('    [presenter presentNode:self.node];');
    writeln('  } else {');
    writeln('    [presenter patchNode:self];');
    writeln('  }');
    writeln('}');
    nodes.forEach((node) {
      writeln('- (bool)is${node.name} {');
      writeln('  return [self.patch isMemberOfClass:${node.name}Patch.class];');
      writeln('}');
      writeln('- (${node.name}Patch*)as${node.name} {');
      writeln('  NSAssert(');
      writeln('    self.is${node.name},');
      writeln('    @"Invalid cast. Expected ${node.name}Patch, found %@",');
      writeln('    self.patch.class);');
      writeln('  return (${node.name}Patch*)self.patch;');
      writeln('}');
    });
    writeln('@end');
    writeln();
  }

  void _writePatchPrimitivesExtendedInterface() {
    _TYPES.forEach((String idlType, String objcType) {
      if (idlType == 'void') return;
      String patchTypeName = '${camelize(idlType)}Patch';
      String patchDataName = objcType;
      writeln('@interface $patchTypeName ()');
      writeln('- (id)initEmptyPatch;');
      writeln('- (id)initWith:($patchDataName)data');
      writeln('       inGraph:(ImmiRoot*)root;');
      writeln('@end');
      writeln();
    });

    writeln('@interface ListRegionPatch : NSObject');
    writeln('@property (readonly) int countDelta;');
    writeln('- (int)index;');
    writeln('- (int)applyTo:(NSMutableArray*)outArray');
    writeln('          with:(NSArray*)inArray;');
    writeln('+ (ListRegionPatch*)regionPatch:(const ListRegionData&)data');
    writeln('                        inGraph:(ImmiRoot*)root;');
    writeln('@end');
    writeln('@interface ListRegionRemovePatch : ListRegionPatch');
    writeln('@property (readonly) int index;');
    writeln('@property (readonly) int count;');
    writeln('- (id)initWith:(const ListRegionData&)data');
    writeln('       inGraph:(ImmiRoot*)root;');
    writeln('@end');
    writeln('@interface ListRegionInsertPatch : ListRegionPatch');
    writeln('@property (readonly) int index;');
    writeln('@property (readonly) NSArray* nodes;');
    writeln('- (id)initWith:(const ListRegionData&)data');
    writeln('       inGraph:(ImmiRoot*)root;');
    writeln('@end');
    writeln('@interface ListRegionUpdatePatch : ListRegionPatch');
    writeln('@property (readonly) int index;');
    writeln('@property (readonly) NSArray* updates;');
    writeln('- (id)initWith:(const ListRegionData&)data');
    writeln('       inGraph:(ImmiRoot*)root;');
    writeln('@end');

    writeln('@interface ListPatch ()');
    writeln('@property NSMutableArray* regionPatches;');
    writeln('- (id)initEmptyPatch;');
    writeln('- (id)initWith:(const ListPatchData&)data');
    writeln('       inGraph:(ImmiRoot*)root;');
    writeln('@end');
    writeln();
  }

  void _writePatchPrimitivesImplementation() {
    _TYPES.forEach((String idlType, String objcType) {
      if (idlType == 'void') return;
      String patchTypeName = '${camelize(idlType)}Patch';
      String patchDataName = objcType;
      writeln('@implementation $patchTypeName {');
      writeln('  $objcType _value;');
      writeln('}');
      writeln('- (id)initEmptyPatch {');
      writeln('  _changed = false;');
      writeln('  return self;');
      writeln('}');
      writeln('- (id)initWith:($patchDataName)data');
      writeln('       inGraph:(ImmiRoot*)root {');
      writeln('  _changed = true;');
      writeln('  _value = data;');
      writeln('  return self;');
      writeln('}');
      writeln('- ($objcType)value {');
      writeln('  assert(self.changed);');
      writeln('  return _value;');
      writeln('}');
      writeln('- ($objcType)applyWith:($objcType)value {');
      writeln('  return self.changed ? self.value : value;');
      writeln('}');
      writeln('@end');
      writeln();
    });

    writeln('@implementation ListRegionPatch');
    writeln('+ (ListRegionPatch*)regionPatch:(const ListRegionData&)data');
    writeln('                        inGraph:(ImmiRoot*)root {');
    writeln('  if (data.isRemove()) {');
    writeln('    return [[ListRegionRemovePatch alloc] initWith:data');
    writeln('                                           inGraph:root];');
    writeln('  }');
    writeln('  if (data.isInsert()) {');
    writeln('    return [[ListRegionInsertPatch alloc] initWith:data');
    writeln('                                           inGraph:root];');
    writeln('  }');
    writeln('  NSAssert(data.isUpdate(), @"Invalid list patch for region");');
    writeln('  return [[ListRegionUpdatePatch alloc] initWith:data');
    writeln('                                         inGraph:root];');
    writeln('}');
    writeln('- (int)index {');
    writeln('    @throw [NSException');
    writeln('        exceptionWithName:NSInternalInconsistencyException');
    writeln('        reason:@"-index base is abstract"');
    writeln('        userInfo:nil];');
    writeln('}');
    writeln('- (int)applyTo:(NSMutableArray*)outArray');
    writeln('          with:(NSArray*)inArray {');
    writeln('    @throw [NSException');
    writeln('        exceptionWithName:NSInternalInconsistencyException');
    writeln('        reason:@"-applyTo:with: base is abstract"');
    writeln('        userInfo:nil];');
    writeln('}');
    writeln('@end');
    writeln();
    writeln('@implementation ListRegionRemovePatch');
    writeln('- (id)initWith:(const ListRegionData&)data');
    writeln('       inGraph:(ImmiRoot*)root {');
    writeln('  _index = data.getIndex();');
    writeln('  _count = data.getRemove();');
    writeln('  return self;');
    writeln('}');
    writeln('- (int)countDelta { return -self.count; }');
    writeln('- (int)applyTo:(NSMutableArray*)outArray');
    writeln('          with:(NSArray*)inArray {');
    writeln('  return self.count;');
    writeln('}');
    writeln('@end');
    writeln();
    writeln('@implementation ListRegionInsertPatch');
    writeln('- (id)initWith:(const ListRegionData&)data');
    writeln('       inGraph:(ImmiRoot*)root {');
    writeln('  _index = data.getIndex();');
    writeln('  const List<NodeData>& insertData = data.getInsert();');
    writeln('  NSMutableArray* nodes =');
    writeln('      [NSMutableArray arrayWithCapacity:insertData.length()];');
    writeln('  for (int i = 0; i < insertData.length(); ++i) {');
    // TODO(zerny): Support List<Node> in addition to List<FooNode>.
    writeln('    nodes[i] = [[Node createNode:insertData[i] inGraph:root]');
    writeln('                 node];');
    writeln('  }');
    writeln('  _nodes = nodes;');
    writeln('  return self;');
    writeln('}');
    writeln('- (int)countDelta { return self.nodes.count; }');
    writeln('- (int)applyTo:(NSMutableArray*)outArray');
    writeln('          with:(NSArray*)inArray {');
    writeln('  [outArray addObjectsFromArray:self.nodes];');
    writeln('  return 0;');
    writeln('}');
    writeln('@end');
    writeln();
    writeln('@implementation ListRegionUpdatePatch');
    writeln('- (id)initWith:(const ListRegionData&)data');
    writeln('       inGraph:(ImmiRoot*)root {');
    writeln('  _index = data.getIndex();');
    writeln('  const List<NodePatchData>& updateData = data.getUpdate();');
    writeln('  NSMutableArray* updates =');
    writeln('      [NSMutableArray arrayWithCapacity:updateData.length()];');
    writeln('  for (int i = 0; i < updateData.length(); ++i) {');
    // TODO(zerny): Support List<Node> in addition to List<FooNode>.
    writeln('    updates[i] = [[NodePatch patch:updateData[i] inGraph:root]');
    writeln('                  patch];');
    writeln('  }');
    writeln('  _updates = updates;');
    writeln('  return self;');
    writeln('}');
    writeln('- (int)countDelta { return 0; }');
    writeln('- (int)applyTo:(NSMutableArray*)outArray');
    writeln('          with:(NSArray*)inArray {');
    writeln('  for (int i = 0; i < self.updates.count; ++i) {');
    writeln('    id <NodePatch> patch = self.updates[i];');
    writeln('    [outArray addObject:[patch');
    writeln('                         applyWith:inArray[self.index + i]]];');
    writeln('  }');
    writeln('  return self.updates.count;');
    writeln('}');
    writeln('@end');
    writeln();
    writeln('@implementation ListPatch');
    writeln('- (id)initEmptyPatch {');
    writeln('  _changed = false;');
    writeln('  return self;');
    writeln('}');
    writeln('- (id)initWith:(const ListPatchData&)data');
    writeln('       inGraph:(ImmiRoot*)root {');
    writeln('  _changed = true;');
    writeln('  const List<ListRegionData>& regions = data.getRegions();');
    writeln('  NSMutableArray* patches =');
    writeln('      [NSMutableArray arrayWithCapacity:regions.length()];');
    writeln('  for (int i = 0; i < regions.length(); ++i) {');
    writeln('    patches[i] =');
    writeln('        [ListRegionPatch regionPatch:regions[i] inGraph:root];');
    writeln('  }');
    writeln('  _regionPatches = patches;');
    writeln('  return self;');
    writeln('}');
    writeln('- (NSArray*)applyWith:(NSArray*)array {');
    writeln('  int newCount = array.count;');
    writeln('  for (int i = 0; i < self.regionPatches.count; ++i) {');
    writeln('    ListRegionPatch* patch = self.regionPatches[i];');
    writeln('    newCount += patch.countDelta;');
    writeln('  }');
    writeln('  int sourceIndex = 0;');
    writeln('  NSMutableArray* newArray =');
    writeln('      [NSMutableArray arrayWithCapacity:newCount];');
    writeln('  for (int i = 0; i < self.regionPatches.count; ++i) {');
    writeln('    ListRegionPatch* patch = self.regionPatches[i];');
    writeln('    while (sourceIndex < patch.index) {');
    writeln('      [newArray addObject:array[sourceIndex++]];');
    writeln('    }');
    writeln('    sourceIndex += [patch applyTo:newArray with:array];');
    writeln('  }');
    writeln('  while (sourceIndex < array.count) {');
    writeln('    [newArray addObject:array[sourceIndex++]];');
    writeln('  }');
    writeln('  return newArray;');
    writeln('}');
    writeln('@end');
    writeln();
  }

  void _writeActionsExtendedInterface() {
    for (List<Type> formals in methodSignatures.values) {
      String actionName = 'Action${actionTypeSuffix(formals)}';
      String actionBlock = '${actionName}Block';
      String actionPatch = '${actionName}Patch';
      writeln('@interface $actionPatch ()');
      writeln('@property (readonly) $actionBlock block;');
      writeln('- (id)initEmptyPatch;');
      writeln('@end');
      writeln();
    }
  }

  void _writeActionsImplementation() {
    for (List<Type> formals in methodSignatures.values) {
      String actionName = 'Action${actionTypeSuffix(formals)}';
      String actionBlock = '${actionName}Block';
      String actionPatch = '${actionName}Patch';
      writeln('@implementation $actionPatch');
      writeln('- (id)initEmptyPatch {');
      writeln('  _block = nil;');
      writeln('  return self;');
      writeln('}');
      writeln('- (id)initWith:($actionBlock)block {');
      writeln('  _block = block;');
      writeln('  return self;');
      writeln('}');
      writeln('- (bool)changed { return self.block != nil; }');
      writeln('- ($actionBlock)applyWith:($actionBlock)block {');
      writeln('  return (self.block != nil) ? self.block : block;');
      writeln('}');
      writeln('@end');
      writeln();
    }
  }

  void _writeListUtils() {
    nodes.forEach((Struct node) {
      String name = node.name;
      String nodeName = "${node.name}Node";
      String patchName = "${node.name}Patch";
      String nodeDataName = "${nodeName}Data";
      String patchDataName = "${patchName}Data";
      writeln('id create$nodeName(const $nodeDataName& data, ImmiRoot* root) {');
      writeln('  return [[$nodeName alloc] initWith:data inGraph:root];');
      writeln('}');
      writeln('id create$patchName(const $patchDataName& data, ImmiRoot* root) {');
      writeln('  return [[$patchName alloc] initWith:data inGraph:root];');
      writeln('}');
      writeln();
    });
    // TODO(zerny): Support lists of primitive types.
    writeln("""
id createNode(const NodeData& data, ImmiRoot* root) {
  return [Node createNode:data inGraph:root];
}
id createNodePatch(const NodePatchData& data, ImmiRoot* root) {
  return [NodePatch patch:data inGraph:root];
}

template<typename T>
class ListUtils {
public:
  typedef id (*DecodeElementFunction)(const T&, ImmiRoot*);

  static NSMutableArray* decodeList(const List<T>& list,
                                    DecodeElementFunction decodeElement,
                                    ImmiRoot* root) {
    NSMutableArray* array = [NSMutableArray arrayWithCapacity:list.length()];
    for (int i = 0; i < list.length(); ++i) {
      [array addObject:decodeElement(list[i], root)];
    }
    return array;
  }
};
""");
  }

  void _writeStringUtils() {
    write("""
NSString* decodeString(const List<unichar>& chars) {
  List<unichar>& tmp = const_cast<List<unichar>&>(chars);
  return [[NSString alloc] initWithCharacters:tmp.data()
                                       length:tmp.length()];
}

void encodeString(NSString* string, List<unichar> chars) {
  assert(string.length == chars.length());
  [string getCharacters:chars.data()
                  range:NSMakeRange(0, string.length)];
}

""");
  }

  void _writeEventUtils() {
    writeln('typedef uint16_t EventID;');
    writeln('void noopVoidEventCallback(void*) {}');
    writeln();
  }

  void _writeHeader() {
    String fileName = basenameWithoutExtension(path);
    writeln(COPYRIGHT);
    writeln('// Generated file. Do not edit.');
    writeln();
    writeln('#import "${fileName}.h"');
    writeln();
  }

  void _writeFormalWithKeyword(String keyword, Formal formal) {
    write('$keyword:(${getTypeName(formal.type)})${formal.name}');
  }

  String patchType(Type type) {
    if (type.isList) return 'ListPatch';
    return '${camelize(type.identifier)}Patch';
  }

  void _writeNSType(Type type) {
    if (type.isList) {
      write('NSArray*');
    } else {
      write(getTypePointer(type));
    }
  }

  String actionFormalTypes(List<Type> types) {
    return types.map((Type type) => getTypeName(type)).join(', ');
  }

  String actionTypedArguments(List<Formal> types) {
    return types.map((Formal formal) {
      return '${getTypeName(formal.type)} ${formal.name}';
    }).join(', ');
  }

  String actionArguments(List<Formal> types) {
    return types.map((Formal formal) {
      return '${formal.name}';
    }).join(', ');
  }

  String actionPatchType(Method method) {
    List<Type> types = method.arguments.map((formal) => formal.type);
    return 'Action${actionTypeSuffix(types)}Patch';
  }

  String actionBlockType(Method method) {
    List<Type> types = method.arguments.map((formal) => formal.type);
    return 'Action${actionTypeSuffix(types)}Block';
  }

  _writeActionBlockImpl(Method method, String idVar, String indent) {
      List<Type> formals = method.arguments.map((formal) => formal.type);
      String suffix = actionTypeSuffix(formals);
      String actionName = 'Action$suffix';
      String actionBlock = '${actionName}Block';
      String actionBlockArgs = method.arguments.isEmpty ? '' :
                               '(${actionTypedArguments(method.arguments)})';
      String actionArgsComma = method.arguments.isEmpty ? '' :
                               '${actionArguments(method.arguments)},';
      String i1 = '$indent   ';
      String i2 = '$i1    ';
      String i3 = '$i2    ';
      writeln(' ^$actionBlockArgs{');
      writeln('$i1 [root dispatch:^{');
      writeln('$i2 ${serviceName}::dispatch${suffix}Async(');
      writeln('$i3 $idVar, $actionArgsComma noopVoidEventCallback, NULL);');
      writeln('$i1 }];');
      writeln('$indent};');
  }
}
