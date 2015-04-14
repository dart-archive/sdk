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
  return _types[type.identifier];
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

  visitUnit(Unit unit) {
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
    writeln('- (id)initWith:(const $nodeNameData&)data;');
    writeln();
    writeln('@end');
    writeln();
  }

  void _writeNodeBase() {
    writeln('@interface Node : NSObject');
    writeln('@end');
    writeln();
  }

  void _writeNSType(Type type) {
    if (type.isList) {
      write('NSArray*');
    } else if (type.resolved != null) {
      write('${node.identifier}Node');
    } else {
      write(_TYPES[type.identifier]);
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

  visitUnit(Unit unit) {
    _writeHeader();
    _writeStringUtils();
    _writeListUtils();
    _writeNodeBase();
    unit.structs.forEach(visit);
  }

  visitStruct(Struct node) {
    StructLayout layout = node.layout;
    String name = node.name;
    String nodeName = "${node.name}Node";
    String nodeNameData = "${nodeName}Data";
    write("""
static id create$nodeName(const $nodeNameData& data) {
  return [[$nodeName alloc] initWith:data];
}

@implementation $nodeName

- (id)init {
  @throw [NSException
          exceptionWithName:NSInternalInconsistencyException
          reason:@"-init is private"
          userInfo:nil];
  return nil;
}

- (id)initWith:(const $nodeNameData&)data {
""");
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
    write("""
  return self;
}

@end

""");
  }

  void _writeNodeBase() {
    write("""
@implementation Node
@end

""");
  }

  void _writeListUtils() {
    write("""
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
