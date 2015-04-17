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
};

String getTypeName(Type type) {
  if (type.resolved != null) {
    return "${type.identifier}Node";
  }
  return _TYPES[type.identifier];
}

void generate(String path, Unit unit, String outputDirectory) {
  String directory = join(outputDirectory, "objc");
  _generateHeaderFile(path, unit, directory);
  _generateImplementationFile(path, unit, directory);
}

void _generateHeaderFile(String path, Unit unit, String directory) {
  _HeaderVisitor visitor = new _HeaderVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  writeToFile(directory, path, contents, extension: 'h');
}

void _generateImplementationFile(String path, Unit unit, String directory) {
  _ImplementationVisitor visitor = new _ImplementationVisitor(path);
  visitor.visit(unit);
  String contents = visitor.buffer.toString();
  writeToFile(directory, path, contents, extension: 'mm');
}

class _HeaderVisitor extends CodeGenerationVisitor {
  _HeaderVisitor(String path) : super(path);

  List nodes;

  visitUnit(Unit unit) {
    nodes = unit.structs;
    _writeHeader();
    _writeNodeBase();
    unit.structs.forEach(visit);
  }

  visitStruct(Struct node) {
    StructLayout layout = node.layout;
    String nodeName = "${node.name}Node";
    String nodeNameData = "${nodeName}Data";
    writeln('@interface $nodeName : Node');
    writeln();
    forEachSlot(node, null, (Type slotType, String slotName) {
      write('@property (readonly) ');
      _writeNSType(slotType);
      writeln(' $slotName;');
    });
    writeln();
    writeln('@end');
    writeln();
  }

  void _writeNodeBase() {
    nodes.forEach((node) { writeln('@class ${node.name}Node;'); });
    writeln();
    writeln('@interface Node : NSObject');
    writeln();
    writeln('+ (bool)applyPatchSet:(const PatchSetData&)data');
    writeln('               atNode:(Node* __strong *)node;');
    writeln();
    nodes.forEach((node) { writeln('- (bool)is${node.name};'); });
    nodes.forEach((node) { writeln('- (${node.name}Node*)as${node.name};'); });
    writeln();
    writeln('@end');
    writeln();
  }

  void _writeNSType(Type type) {
    if (type.isList) {
      write('NSArray*');
    } else {
      write(getTypeName(type));
    }
  }

  void _writeHeader() {
    String fileName = basenameWithoutExtension(path);
    writeln(COPYRIGHT);
    writeln('// Generated file. Do not edit.');
    writeln();
    writeln('#import <Foundation/Foundation.h>');
    writeln('#include "${fileName}_presenter_service.h"');
    writeln();
  }
}

class _ImplementationVisitor extends CodeGenerationVisitor {
  _ImplementationVisitor(String path) : super(path);

  List<Struct> nodes;

  visitUnit(Unit unit) {
    nodes = unit.structs;

    _writeHeader();
    _writeNodeBaseExtendedInterface();
    nodes.forEach(_writeNodeExtendedInterface);

    _writeStringUtils();
    _writeListUtils();

    _writeNodeBaseImplementation();
    nodes.forEach(_writeNodeImplementation);
  }

  _writeNodeExtendedInterface(Struct node) {
    String name = node.name;
    String nodeName = "${node.name}Node";
    String nodeNameData = "${nodeName}Data";
    writeln('@interface $nodeName ()');
    writeln('- (id)initWith:(const $nodeNameData&)data;');
    writeln('@end');
    writeln();
  }

  _writeNodeImplementation(Struct node) {
    String name = node.name;
    String nodeName = "${node.name}Node";
    String nodeNameData = "${nodeName}Data";
    writeln('@implementation $nodeName');
    bool hasNodeSlots = false;
    bool hasListSlots = false;
    forEachSlot(node, null, (Type slotType, _) {
      if (slotType.isList) {
        hasListSlots = true;
      } else if (slotType.resolved) {
        hasNodeSlots = true;
      }
    });
    // Create hidden instance variables for lists holding mutable arrays.
    if (hasListSlots) {
      forEachSlot(node, null, (Type slotType, String slotName) {
        if (slotType.isList) writeln('NSMutableArray* _$slotName;');
      });
      forEachSlot(node, null, (Type slotType, String slotName) {
        if (slotType.isList) {
          writeln('- (NSArray*)$slotName { return _$slotName; }');
        }
      });
    }
    if (hasNodeSlots) {
      writeln('- (Node*)getSlot:(int)index {');
      writeln('  abort();');
      writeln('}');
    }
    writeln('- (bool)is$name { return true; }');
    writeln('- ($nodeName*)as$name { return self; }');
    writeln('- (id)initWith:(const $nodeNameData&)data {');
    forEachSlot(node, null, (Type slotType, String slotName) {
      String camelName = camelize(slotName);
      write('  _$slotName = ');
      if (slotType.isList) {
        String slotTypeName = getTypeName(slotType);
        String slotTypeData = "${slotTypeName}Data";
        writeln('ListUtils<$slotTypeData>::decodeList(');
        writeln('      data.get${camelName}(), create$slotTypeName);');
      } else if (slotType.isString) {
        writeln('decodeString(data.get${camelName}Data());');
      } else {
        writeln('data.get${camelName}();');
      }
    });
    writeln('  return self;');
    writeln('}');

    writeln('- (void)applyPatch:(const PatchData&)patch atSlot:(int)index {');
    int slotIndex = 0;
    writeln('  switch(index) {');
    forEachSlot(node, null, (Type slotType, String slotName) {
      writeln('  case $slotIndex:');
      if (slotType.isList) {
        writeln('    assert(patch.isListPatch());');
        writeln('    [Node applyListPatch:patch.getListPatch()');
        writeln('                 toArray:_$slotName];');
      } else if (slotType.resolved != null) {
        String typeName = "${slotType.identifier}Node";
        writeln('    assert(patch.isContent());');
        writeln('    assert(patch.getContent().isNode());');
        writeln('    assert(patch.getContent().getNode().is${typeName}());');
        writeln('    _$slotName = [[$typeName alloc]');
        writeln('        initWith:patch.getContent().getNode().get${typeName}()];');
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
    writeln('  default: abort();');
    writeln('  }');
    writeln('}');

    writeln('@end');
    writeln();
  }

  void _writeNodeBaseExtendedInterface() {
    writeln('@interface Node ()');
    writeln('+ (Node*)node:(const NodeData&)data;');
    writeln('+ (void)applyListPatch:(const ListPatchData&)patch');
    writeln('               toArray:(NSMutableArray*)array;');
    writeln('- (Node*)getSlot:(int)index;');
    writeln('- (void)applyPatch:(const PatchData&)patch');
    writeln('            atSlot:(int)slot;');
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
    writeln('+ (Node*)node:(const NodeData&)data {');
    write(' ');
    nodes.forEach((node) {
      writeln(' if (data.is${node.name}()) {');
      writeln('    return [[${node.name}Node alloc] initWith:data.get${node.name}()];');
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
            atSlot:(int)slot {
  @throw [NSException
          exceptionWithName:NSInternalInconsistencyException
          reason:@"-applyPatch must be implemented by subclass"
          userInfo:nil];
}

+ (bool)applyPatchSet:(const PatchSetData&)data
               atNode:(Node* __strong *)node {
  List<PatchData> patches = data.getPatches();
  if (patches.length() == 0) return false;
  if (patches.length() == 1 && patches[0].getPath().length() == 0) {
    assert(patches[0].isContent());
    assert(patches[0].getContent().isNode());
    *node = [Node node:patches[0].getContent().getNode()];
  } else {
    [Node applyPatches:patches atNode:*node];
  }
  return true;
}

+ (void)applyPatches:(const List<PatchData>&)patches
              atNode:(Node*)node {
  for (int i = 0; i < patches.length(); ++i) {
    PatchData patch = patches[i];
    List<uint8_t> path = patch.getPath();
    assert(path.length() > 0);
    Node* current = node;
    int lastIndex = path.length() - 1;
    int lastSlot = path[lastIndex];
    for (int j = 0; j < lastIndex; ++j) {
      current = [current getSlot:path[j]];
    }
    [current applyPatch:patch atSlot:lastSlot];
  }
}

+ (void)applyListPatch:(const ListPatchData&)listPatch
               toArray:(NSMutableArray*)array {
  int index = listPatch.getIndex();
  if (listPatch.isRemove()) {
    NSRange range = NSMakeRange(index, listPatch.getRemove());
    NSIndexSet* indexes = [NSIndexSet indexSetWithIndexesInRange:range];
    [array removeObjectsAtIndexes:indexes];
  } else if (listPatch.isInsert()) {
    NSArray* addition = ListUtils<ContentData>::decodeList(
        listPatch.getInsert(), createContent);
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
        array[index + i] = [Node node:content.getNode()];
      } else {
        [Node applyPatches:patches atNode:array[index + i]];
      }
    }
  }
}

@end

""");
  }

  void _writeListUtils() {
    nodes.forEach((Struct node) {
      String name = node.name;
      String nodeName = "${node.name}Node";
      String nodeNameData = "${nodeName}Data";
      writeln('static id create$nodeName(const $nodeNameData& data) {');
      writeln('  return [[$nodeName alloc] initWith:data];');
      writeln('}');
      writeln();
    });
    // TODO(zerny): Support lists of primitive types.
    write("""
static id createContent(const ContentData& data) {
  assert(data.isNode());
  return [Node node:data.getNode()];
}

template<typename T>
class ListUtils {
public:
  typedef id (*DecodeElementFunction)(const T&);

  static NSMutableArray* decodeList(const List<T>& list,
                                    DecodeElementFunction decodeElement) {
    NSMutableArray* array = [NSMutableArray arrayWithCapacity:list.length()];
    for (int i = 0; i < list.length(); ++i) {
      [array addObject:decodeElement(list[i])];
    }
    return array;
  }
};

""");
  }

  void _writeStringUtils() {
    write("""
static NSString* decodeString(const List<unichar>& chars) {
  List<unichar>& tmp = const_cast<List<unichar>&>(chars);
  return [[NSString alloc] initWithCharacters:tmp.data()
                                       length:tmp.length()];
}

static void encodeString(NSString* string, List<unichar> chars) {
  assert(string.length == chars.length());
  [string getCharacters:chars.data()
                  range:NSMakeRange(0, string.length)];
}

""");
  }

  void _writeHeader() {
    String fileName = basenameWithoutExtension(path);
    writeln(COPYRIGHT);
    writeln('// Generated file. Do not edit.');
    writeln();
    writeln('#import "${fileName}.h"');
    writeln();
  }
}
