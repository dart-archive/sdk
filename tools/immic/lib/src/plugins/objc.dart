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
  'uint64'  : 'uint63_t',

  'int8'    : 'int8_t',
  'int16'   : 'int16_t',
  'int32'   : 'int32_t',
  'int64'   : 'int64_t',

  'float32' : 'float',
  'float64' : 'double',

  'String' : 'NSString*',
  'node'   : 'Node',
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

class _HeaderVisitor extends CodeGenerationVisitor {
  _HeaderVisitor(String path) : super(path);

  List nodes = [];

  visitUnits(Map units) {
    units.values.forEach((unit) { nodes.addAll(unit.structs); });
    _writeHeader();
    _writeNodeBase();
    _writeRootPresenter();
    _writeImmiService();
    _writeImmiRoot();
    _writeNavigationRootPresenterCategory();
    units.values.forEach(visit);
  }

  visitUnit(Unit unit) {
    unit.structs.forEach(visit);
  }

  visitStruct(Struct node) {
    StructLayout layout = node.layout;
    String nodeName = "${node.name}Node";
    String nodeNameData = "${nodeName}Data";
    String nodeObserverBlock = "${nodeName}ObserverBlock";
    writeln('typedef void (^$nodeObserverBlock)(${nodeName}*);');
    writeln('@interface $nodeName : Node');
    writeln();
    forEachSlot(node, null, (Type slotType, String slotName) {
      write('@property (readonly) ');
      _writeNSType(slotType);
      writeln(' $slotName;');
    });
    writeln();
    writeln('- (void)observe:($nodeObserverBlock)block;');
    writeln();
    for (var method in node.methods) {
      write('- (void)dispatch${camelize(method.name)}');
      List arguments = method.arguments;
      if (!arguments.isEmpty) {
        var arg = arguments[0];
        _writeFormalWithKeyword(camelize(arg.name), arg);
        for (int i = 1; i < arguments.length; ++i) {
          arg = arguments[i];
          write(' ');
          _writeFormalWithKeyword(arg.name, arg);
        }
      }
      writeln(';');
    }
    if (!node.methods.isEmpty) writeln();
    writeln('@end');
    writeln();
  }

  void _writeFormalWithKeyword(String keyword, Formal formal) {
    write('$keyword:(${getTypeName(formal.type)})${formal.name}');
  }

  void _writeNodeBase() {
    writeln('@class ImmiRoot;');
    nodes.forEach((node) { writeln('@class ${node.name}Node;'); });
    writeln();
    writeln('@interface Node : NSObject');
    writeln();
    writeln('+ (bool)applyPatchSet:(const PatchSetData&)data');
    writeln('               atNode:(Node* __strong *)node');
    writeln('              inGraph:(ImmiRoot*)root;');
    writeln();
    nodes.forEach((node) { writeln('- (bool)is${node.name};'); });
    nodes.forEach((node) { writeln('- (${node.name}Node*)as${node.name};'); });
    writeln();
    writeln('@end');
    writeln();
  }

  void _writeRootPresenter() {
    writeln('@protocol RootPresenter <NSObject>');
    writeln('- (void)immi_setupRoot:(ImmiRoot*)root;');
    writeln('@end');
    writeln();
  }

  void _writeImmiService() {
    writeln('@interface ImmiService : NSObject');
    writeln('- (void)registerPresenter:(id <RootPresenter>)presenter');
    writeln('                  forName:(NSString*)name;');
    writeln('- (void)registerStoryboard:(UIStoryboard*)storyboard;');
    writeln('- (id <RootPresenter>)getPresenterByName:(NSString*)name;');
    writeln('@end');
    writeln();
  }

  void _writeImmiRoot() {
    writeln('typedef void (^ImmiDispatchBlock)(void);');
    writeln('@interface ImmiRoot : NSObject');
    writeln('@property (readonly) Node* rootNode;');
    writeln('- (void)refresh:(ImmiDispatchBlock)block;');
    writeln('- (void)reset;');
    writeln('- (void)dispatch:(ImmiDispatchBlock)block;');
    writeln('@end');
    writeln();
  }

  void _writeNavigationRootPresenterCategory() {
    write('@interface UINavigationController');
    writeln(' (ImmiNavigationRootPresenter) <RootPresenter>');
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
}

class _ImplementationVisitor extends CodeGenerationVisitor {
  _ImplementationVisitor(String path) : super(path);

  List<Struct> nodes = [];

  visitUnits(Map units) {
    units.values.forEach((unit) { nodes.addAll(unit.structs); });
    _writeHeader();
    _writeNodeBaseExtendedInterface();
    _writeImmiServiceExtendedInterface();
    _writeImmiRootExtendedInterface();

    _writeEventUtils();

    units.values.forEach((unit) {
      unit.structs.forEach(_writeNodeExtendedInterface);
    });

    _writeStringUtils();
    _writeListUtils();

    _writeNodeBaseImplementation();
    _writeImmiServiceImplementation();
    _writeImmiRootImplementation();
    _writeNavigationRootPresenterCategory();

    units.values.forEach((unit) {
      unit.structs.forEach(_writeNodeImplementation);
    });
  }

  visitUnit(Unit unit) {
    // Everything is done in visitUnits.
  }

  _writeImmiServiceExtendedInterface() {
    writeln('@interface ImmiService ()');
    writeln('@property NSMutableArray* storyboards;');
    writeln('@property NSMutableDictionary* presenters;');
    writeln('@end');
    writeln();
  }

  _writeImmiServiceImplementation() {
    writeln('@implementation ImmiService');
    writeln();
    writeln('- (id)init {');
    writeln('  _storyboards = [NSMutableArray array];');
    writeln('  _presenters = [NSMutableDictionary dictionary];');
    writeln('  return self;');
    writeln('}');
    writeln();
    writeln('- (void)registerPresenter:(id <RootPresenter>)presenter');
    writeln('                  forName:(NSString*)name {');
    writeln('  assert(self.presenters[name] == nil);');
    writeln('  int length = name.length;');
    writeln('  int size = 48 + PresenterDataBuilder::kSize + length;');
    writeln('  MessageBuilder message(size);');
    writeln('  PresenterDataBuilder builder =');
    writeln('      message.initRoot<PresenterDataBuilder>();');
    writeln('  List<unichar> chars = builder.initNameData(length);');
    writeln('  [name getCharacters:chars.data()');
    writeln('                range:NSMakeRange(0, length)];');
    writeln('  uint16_t pid = ImmiServiceLayer::getPresenter(builder);');
    writeln('  [presenter immi_setupRoot:[[ImmiRoot alloc] init:pid]];');
    writeln('  self.presenters[name] = presenter;');
    writeln('}');
    writeln();
    writeln('- (void)registerStoryboard:(UIStoryboard*)storyboard {');
    writeln('  [self.storyboards addObject:storyboard];');
    writeln('}');
    writeln();
    writeln('- (id <RootPresenter>)getPresenterByName:(NSString*)name {');
    writeln('  id <RootPresenter> presenter = self.presenters[name];');
    writeln('  if (presenter != nil) return presenter;');
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
    writeln('  [self registerPresenter:presenter forName:name];');
    writeln('  return presenter;');
    writeln('}');
    writeln();
    writeln('@end');
    writeln();
  }

  _writeImmiRootExtendedInterface() {
    writeln('@interface ImmiRoot ()');
    writeln('@property NSMutableSet* pendingObservers;');
    writeln('@property (readonly) uint16_t pid;');
    writeln('- (id)init:(uint16_t)pid;');
    writeln('@end');
    writeln();
  }

  _writeImmiRootImplementation() {
    writeln('typedef void (^ImmiRefreshBlock)(const PatchSetData&);');
    writeln('typedef void (*ImmiRefreshCallback)(PatchSetData, void*);');
    writeln('void ImmiRefresh(PatchSetData patchData, void* callbackData) {');
    writeln('  ImmiRefreshBlock block =');
    writeln('      (__bridge_transfer ImmiRefreshBlock)callbackData;');
    writeln('  block(patchData);');
    writeln('  patchData.Delete();');
    writeln('}');
    writeln('@implementation ImmiRoot');
    writeln();
    writeln('- (id)init:(uint16_t)pid {');
    writeln('  assert(pid > 0);');
    writeln('  _pid = pid;');
    writeln('  _rootNode = nil;');
    writeln('  _pendingObservers = [NSMutableSet set];');
    writeln('  return self;');
    writeln('}');
    writeln();
    writeln('- (void)refresh:(ImmiDispatchBlock)block {');
    writeln('  ImmiRefreshBlock doApply = ^(const PatchSetData& patchData) {');
    writeln('      if ([Node applyPatchSet:patchData');
    writeln('                       atNode:&_rootNode');
    writeln('                      inGraph:self]) {');
    writeln('        block();');
    writeln('        [self runPendingObservers];');
    writeln('      }');
    writeln('      assert(self.pendingObservers.count == 0);');
    writeln('  };');
    writeln('  ${serviceName}::refreshAsync(');
    writeln('      self.pid, ImmiRefresh, (__bridge_retained void*)doApply);');
    writeln('}');
    writeln();
    writeln('- (void)runPendingObservers {');
    writeln('  [self.pendingObservers');
    writeln('      enumerateObjectsUsingBlock:^(Node* node, BOOL* stop) {');
    writeln('      for (int i = 0; i < node.observers.count; ++i) {');
    writeln('        ((void (^)(Node*))node.observers[i])(node);');
    writeln('      }');
    writeln('  }];');
    writeln('  [self.pendingObservers removeAllObjects];');
    writeln('}');
    writeln();
    writeln('- (void)reset {');
    writeln('  _rootNode = nil;');
    writeln('  ${serviceName}::reset(self.pid);');
    writeln('}');
    writeln();
    writeln('- (void)dispatch:(ImmiDispatchBlock)block {');
    writeln('  block();');
    writeln('}');
    writeln();
    writeln('@end');
    writeln();
  }

  _writeNavigationRootPresenterCategory() {
    writeln(
        '@implementation UINavigationController (ImmiNavigationRootPresenter)');
    writeln();
    writeln('- (UIViewController <RootPresenter> *)presenter {');
    writeln(
        '  return (UIViewController<RootPresenter>*)self.topViewController;');
    writeln('}');
    writeln();
    writeln('- (void)immi_setupRoot:(ImmiRoot*)root {');
    writeln('  [self.presenter immi_setupRoot:root];');
    writeln('}');
    writeln();
    writeln('@end');
    writeln();
  }

  _writeNodeExtendedInterface(Struct node) {
    String name = node.name;
    String nodeName = "${node.name}Node";
    String nodeNameData = "${nodeName}Data";
    writeln('@interface $nodeName ()');
    if (node.methods.isNotEmpty) {
      writeln('@property (weak) ImmiRoot* root;');
    }
    writeln('- (id)initWith:(const $nodeNameData&)data inGraph:(ImmiRoot*)root;');
    writeln('@end');
    writeln();
  }

  _writeNodeImplementation(Struct node) {
    String name = node.name;
    String nodeName = "${node.name}Node";
    String nodeNameData = "${nodeName}Data";
    String nodeObserverBlock = "${nodeName}ObserverBlock";
    writeln('@implementation $nodeName');
    bool hasNodeSlots = false;
    bool hasListSlots = false;
    forEachSlot(node, null, (Type slotType, _) {
      if (slotType.isList) {
        hasListSlots = true;
      } else if (slotType.resolved != null) {
        hasNodeSlots = true;
      }
    });
    // Add internal instance variables.
    if (hasListSlots || node.methods.isNotEmpty) {
      writeln('{');
      for (var method in node.methods) {
        writeln('  EventID _${method.name}EventID;');
      }
      // Create hidden instance variables for lists holding mutable arrays.
      if (hasListSlots) {
        forEachSlot(node, null, (Type slotType, String slotName) {
          if (slotType.isList) writeln('  NSMutableArray* _$slotName;');
        });
      }
      writeln('}');
    }

    forEachSlot(node, null, (Type slotType, String slotName) {
      if (slotType.isList) {
        writeln('- (NSArray*)$slotName { return _$slotName; }');
      }
    });
    if (hasNodeSlots) {
      writeln('- (Node*)getSlot:(int)index {');
      writeln('  switch(index) {');
      int slotIndex = 0;
      forEachSlot(node, null, (Type slotType, String slotName) {
        if (!slotType.isList && slotType.resolved != null) {
          writeln('    case $slotIndex: return _$slotName;');
        }
        slotIndex++;
      });
      writeln('    default: abort();');
      writeln('  }');
      writeln('}');
    }

    writeln('- (bool)is$name { return true; }');
    writeln('- ($nodeName*)as$name { return self; }');
    writeln('- (id)initWith:(const $nodeNameData&)data inGraph:(ImmiRoot*)root {');
    if (node.methods.isNotEmpty) {
      writeln('  _root = root;');
    }
    forEachSlot(node, null, (Type slotType, String slotName) {
      String camelName = camelize(slotName);
      write('  _$slotName = ');
      if (slotType.isList) {
        String slotTypeName = getTypeName(slotType);
        String slotTypeData = "${slotTypeName}Data";
        writeln('ListUtils<$slotTypeData>::decodeList(');
        writeln('      data.get${camelName}(), create$slotTypeName, root);');
      } else if (slotType.isString) {
        writeln('decodeString(data.get${camelName}Data());');
      } else if (slotType.isNode) {
        writeln('[Node node:data.get${camelName}() inGraph:root];');
      } else if (slotType.resolved != null) {
        String slotTypeName = getTypeName(slotType);
        writeln('[[$slotTypeName alloc] initWith:data.get${camelName}() inGraph:(ImmiRoot*)root];');
      } else {
        writeln('data.get${camelName}();');
      }
    });
    for (var method in node.methods) {
      writeln('  _${method.name}EventID = data.get${camelize(method.name)}();');
    }
    writeln('  return self;');
    writeln('}');

    writeln('- (void)applyPatch:(const PatchData&)patch');
    writeln('            atSlot:(int)index');
    writeln('           inGraph:(ImmiRoot*)root {');
    int slotIndex = 0;
    writeln('  switch(index) {');
    forEachSlot(node, null, (Type slotType, String slotName) {
      writeln('  case $slotIndex:');
      if (slotType.isList) {
        writeln('    assert(patch.isListPatch());');
        writeln('    [Node applyListPatch:patch.getListPatch()');
        writeln('                 toArray:_$slotName');
        writeln('                 inGraph:root];');
      } else if (slotType.resolved != null) {
        String typeName = "${slotType.identifier}";
        String typeNodeName = "${slotType.identifier}Node";
        writeln('    assert(patch.isContent());');
        writeln('    assert(patch.getContent().isNode());');
        writeln('    assert(patch.getContent().getNode().is${typeName}());');
        writeln('    _$slotName = [[$typeNodeName alloc]');
        writeln('        initWith:patch.getContent().getNode().get${typeName}()');
        writeln('         inGraph:root];');
      } else {
        String typeName = camelize("${slotType.identifier}Data");
        writeln('    assert(patch.isContent());');
        writeln('    assert(patch.getContent().isPrimitive());');
        writeln('    assert(patch.getContent().getPrimitive().is${typeName}());');
        if (slotType.isString) {
          writeln('    _$slotName =');
          writeln('        decodeString(patch.getContent().getPrimitive().get${typeName}Data());');
        } else {
          writeln('    _$slotName =');
          writeln('        patch.getContent().getPrimitive().get${typeName}();');
        }
      }
      writeln('    break;');
      ++slotIndex;
    });
    for (var method in node.methods) {
      writeln('  case $slotIndex:');
      writeln('    assert(patch.isContent());');
      writeln('    assert(patch.getContent().isPrimitive());');
      writeln('    assert(patch.getContent().getPrimitive().isUint16Data());');
      writeln('    _${method.name}EventID =');
      writeln('         patch.getContent().getPrimitive().getUint16Data();');
      writeln('    break;');
      ++slotIndex;
    }
    writeln('  default: abort();');
    writeln('  }');
    writeln('}');
    writeln();

    // Observation
    writeln('- (void)observe:($nodeObserverBlock)block {');
    writeln('  if (self.observers == nil) {');
    writeln('    self.observers = [NSMutableArray array];');
    writeln('  }');
    writeln('  [self.observers addObject:block];');
    writeln('}');
    writeln();

    // Event dispatching
    String unitName = camelize(basenameWithoutExtension(path));
    for (var method in node.methods) {
      write('- (void)dispatch${camelize(method.name)}');
      List arguments = method.arguments;
      if (!arguments.isEmpty) {
        var arg = arguments[0];
        _writeFormalWithKeyword(camelize(arg.name), arg);
        for (int i = 1; i < arguments.length; ++i) {
          arg = arguments[i];
          write(' ');
          _writeFormalWithKeyword(arg.name, arg);
        }
      }
      writeln(' {');
      writeln('  [self.root dispatch:^{');
      write('    ${serviceName}::dispatch');
      for (var formal in method.arguments) {
        write(camelize(formal.type.identifier));
      }
      write('Async(_${method.name}EventID');
      for (var formal in method.arguments) {
        write(', ');
        write(formal.name);
      }
      writeln(', noopVoidEventCallback, NULL);');
      writeln('  }];');
      writeln('}');
    }

    writeln('@end');
    writeln();
  }

  void _writeNodeBaseExtendedInterface() {
    writeln('@interface Node ()');
    writeln('@property NSMutableArray* observers;');
    writeln('+ (Node*)node:(const NodeData&)data inGraph:(ImmiRoot*)root;');
    writeln('+ (void)applyListPatch:(const ListPatchData&)patch');
    writeln('               toArray:(NSMutableArray*)array');
    writeln('               inGraph:(ImmiRoot*)root;');
    writeln('- (Node*)getSlot:(int)index;');
    writeln('- (void)applyPatch:(const PatchData&)patch');
    writeln('            atSlot:(int)slot');
    writeln('           inGraph:(ImmiRoot*)root;');
    writeln('@end');
    writeln();
  }

  void _writeNodeBaseImplementation() {
    writeln('@implementation Node');
    writeln('- (Node*)getSlot:(int)index { abort(); }');
    nodes.forEach((node) {
      writeln('- (bool)is${node.name} { return false; }');
    });
    nodes.forEach((node) {
      writeln('- (${node.name}Node*)as${node.name} { abort(); }');
    });
    writeln('+ (Node*)node:(const NodeData&)data inGraph:(ImmiRoot*)root {');
    write(' ');
    nodes.forEach((node) {
      writeln(' if (data.is${node.name}()) {');
      writeln('    return [[${node.name}Node alloc]');
      writeln('            initWith:data.get${node.name}()');
      writeln('            inGraph:root];');
      write('  } else');
    });
    writeln(' {');
    writeln('    abort();');
    writeln('  }');
    writeln('}');

    write("""
- (id)init {
  @throw [NSException
          exceptionWithName:NSInternalInconsistencyException
          reason:@"-init is private"
          userInfo:nil];
  return nil;
}

- (void)applyPatch:(const PatchData&)patch
            atSlot:(int)slot
           inGraph:(ImmiRoot*)root {
  @throw [NSException
          exceptionWithName:NSInternalInconsistencyException
          reason:@"-applyPatch must be implemented by subclass"
          userInfo:nil];
}

+ (bool)applyPatchSet:(const PatchSetData&)data
               atNode:(Node* __strong *)node
              inGraph:(ImmiRoot*)root {
  List<PatchData> patches = data.getPatches();
  if (patches.length() == 0) return false;
  if (patches.length() == 1 && patches[0].getPath().length() == 0) {
    assert(patches[0].isContent());
    assert(patches[0].getContent().isNode());
    *node = [Node node:patches[0].getContent().getNode() inGraph:root];
    [Node registerObservers:*node inGraph:root];
  } else {
    [Node applyPatches:patches atNode:*node inGraph:root];
  }
  return true;
}

+ (void)applyPatches:(const List<PatchData>&)patches
              atNode:(Node*)node
             inGraph:(ImmiRoot*)root {
  for (int i = 0; i < patches.length(); ++i) {
    PatchData patch = patches[i];
    List<uint8_t> path = patch.getPath();
    assert(path.length() > 0);
    Node* current = node;
    int lastIndex = path.length() - 1;
    int lastSlot = path[lastIndex];
    for (int j = 0; j < lastIndex; ++j) {
      [Node registerObservers:current inGraph:root];
      current = [current getSlot:path[j]];
    }
    [Node registerObservers:current inGraph:root];
    [current applyPatch:patch atSlot:lastSlot inGraph:root];
  }
}

+ (void)applyListPatch:(const ListPatchData&)listPatch
               toArray:(NSMutableArray*)array
               inGraph:(ImmiRoot*)root {
  int index = listPatch.getIndex();
  if (listPatch.isRemove()) {
    NSRange range = NSMakeRange(index, listPatch.getRemove());
    NSIndexSet* indexes = [NSIndexSet indexSetWithIndexesInRange:range];
    [array removeObjectsAtIndexes:indexes];
  } else if (listPatch.isInsert()) {
    NSArray* addition = ListUtils<ContentData>::decodeList(
        listPatch.getInsert(), createContent, root);
    NSRange range = NSMakeRange(index, addition.count);
    NSIndexSet* indexes = [NSIndexSet indexSetWithIndexesInRange:range];
    [array insertObjects:addition atIndexes:indexes];
  } else {
    assert(listPatch.isUpdate());
    const List<PatchSetData>& updates = listPatch.getUpdate();
    for (int i = 0; i < updates.length(); ++i) {
      const List<PatchData>& patches = updates[i].getPatches();
      if (patches.length() == 1 && patches[0].getPath().length() == 0) {
        assert(patches[0].isContent());
        const ContentData& content = patches[0].getContent();
        // TODO(zerny): Support lists of primitive types.
        assert(content.isNode());
        array[index + i] = [Node node:content.getNode() inGraph:root];
        [Node registerObservers:array[index + i] inGraph:root];
      } else {
        [Node applyPatches:patches atNode:array[index + i] inGraph:root];
      }
    }
  }
}

+ (void)registerObservers:(Node*)node inGraph:(ImmiRoot*)root {
  if (node.observers != nil) [root.pendingObservers addObject:node];
}

@end

""");
  }

  void _writeListUtils() {
    nodes.forEach((Struct node) {
      String name = node.name;
      String nodeName = "${node.name}Node";
      String nodeNameData = "${nodeName}Data";
      writeln('id create$nodeName(const $nodeNameData& data, ImmiRoot* root) {');
      writeln('  return [[$nodeName alloc] initWith:data inGraph:root];');
      writeln('}');
      writeln();
    });
    // TODO(zerny): Support lists of primitive types.
    write("""
id createNode(const NodeData& data, ImmiRoot* root) {
  return [Node node:data inGraph:root];
}

id createContent(const ContentData& data, ImmiRoot* root) {
  assert(data.isNode());
  return createNode(data.getNode(), root);
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
}
