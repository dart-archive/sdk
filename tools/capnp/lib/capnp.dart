// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library capnp;

import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:async';
import 'dart:core' hide Type;

import 'message.dart';
import 'serialize.dart';
import 'schema.capnp.dart';

final Map<int, Node> nodes = <int, Node>{};
final Set<Node> usedLists = new Set<Node>();

Future run() async {
  ByteData bytes = new ByteData.view(await readEncodedBytes());
  MessageReader message = new BufferedMessageReader(bytes);
  CodeGeneratorRequest request = message.getRoot(new CodeGeneratorRequest());

  String filename = request.requestedFiles.first.filename.toString();
  int slashIndex = filename.lastIndexOf('/');
  if (slashIndex >= 0) filename = filename.substring(slashIndex + 1);

  print('// Generated code. Do not edit.');
  print('');
  print('library $filename;');
  print('');
  print("import 'internals.dart' as capnp;");
  print("import 'internals.dart' show Text, Data;");
  print("export 'internals.dart' show Text, Data;");
  print('');

  request.nodes.forEach((Node n) { nodes[n.id] = n; });

  request.nodes.where((e) => e.isEnum).forEach((Node n) {
    String name = dartName(n);
    print('enum $name {');
    for (Enumerant e in n.enumEnumerants) {
      print('  ${e.name},');
    }
    print('}');
    print('');
  });

  request.nodes.where((e) => e.isStruct).forEach((Node n) {
    if (n.structIsGroup) return;

    String name = dartName(n);
    print('class $name extends capnp.Struct {');
    print('  int get declaredWords => ${n.structDataWordCount};');
    print('  int get declaredPointers => ${n.structPointerCount};');

    printStructFields(n, const []);
    print('}');
    print('');

    int declaredSize = (n.structDataWordCount + n.structPointerCount) * 8;
    print('class ${name}Builder extends capnp.StructBuilder {');
    print('  int get declaredWords => ${n.structDataWordCount};');
    print('  int get declaredPointers => ${n.structPointerCount};');
    print('  int get declaredSize => $declaredSize;');

    printStructFields(n, const [], builder: true);
    print('}');
    print('');
  });

  print('');
  print('// ------------------------- Private list types -------------------------');
  print('');

  usedLists.forEach((Node n) {
    String name = dartName(n);

    print('class _${name}List extends capnp.StructList implements List<$name> {');
    print('  int get declaredElementWords => ${n.structDataWordCount};');
    print('  int get declaredElementPointers => ${n.structPointerCount};');
    print('  $name operator[](int index) => capnp.readStructListElement(new $name(), this, index);');
    print('}');
    print('');

    int declaredElementSize = (n.structDataWordCount + n.structPointerCount) * 8;
    print('class _${name}ListBuilder extends capnp.StructListBuilder implements List<${name}Builder> {');
    print('  final int length;');
    print('  _${name}ListBuilder(this.length);');
    print('');
    print('  int get declaredElementWords => ${n.structDataWordCount};');
    print('  int get declaredElementPointers => ${n.structPointerCount};');
    print('  int get declaredElementSize => $declaredElementSize;');
    print('');
    print('  ${name}Builder operator[](int index) => capnp.writeStructListElement(new ${name}Builder(), this, index);');
    print('}');
    print('');
  });

  return null;
}

String join(List<String> path, Text text, {String prefix: ''}) {
  StringBuffer buffer = new StringBuffer();
  void append(String value) {
    if (buffer.isEmpty) {
      buffer.write(value);
    } else if (value.isNotEmpty) {
      buffer.write(value[0].toUpperCase());
      buffer.write(value.substring(1));
    }
  }
  for (int i = 0; i < path.length; i++) append(path[i]);
  append(prefix);
  append(text.toString());
  return "$buffer";
}

String safeFieldName(List<String> path, Field f) {
  String name = join(path, f.name);
  // TODO(kasperl): Generalize this.
  if (name == 'bool') return r'$bool';
  if (name == 'enum') return r'$enum';
  return name;
}

void printStructFields(Node n, List<String> path, {bool builder: false}) {
  assert(n.isStruct);
  for (Field f in n.structFields) {
    if (!n.structIsGroup) print('');
    int disVal = f.discriminantValue;
    if (disVal != 0xffff) {
      assert(n.structDiscriminantCount > 1);
      int offset = n.structDiscriminantOffset * 2;
      String name = join(path, f.name, prefix: 'is');
      print('  bool get $name => capnp.readUInt16(this, $offset) == $disVal;');
      if (builder) {
        String setterName = join(path, f.name, prefix: 'set');
        print('  void $setterName() => capnp.writeUInt16(this, $offset, $disVal);');
      }
    }

    if (f.isSlot) {
      if (f.slotType.isVoid) continue;
      String type = dartTypeOf(f.slotType);
      String getter = dartGetPrimitive(f);
      String name = safeFieldName(path, f);
      if (!f.slotType.isText || !builder) print('  $type get $name => $getter;');
      if (builder) {
        if (f.slotType.isList) {
          int offset = f.slotOffset;
          String elementType = dartTypeOf(f.slotType.listElementType);
          String initName = join(path, f.name, prefix: 'init');
          print('  List<${elementType}Builder> $initName(int length) => '
                'capnp.writeStructList(new _${elementType}ListBuilder(length), this, $offset);');
        } else if (f.slotType.isText) {
          String setter = dartSetPrimitive(f);
          print('  String get $name => $getter.toString();');
          print('  void set $name(String value) => $setter;');
        } else {
          String setter = dartSetPrimitive(f);
          print('  void set $name($type value) => $setter;');
        }
      }
    } else if (f.isGroup) {
      Node group = nodes[f.groupTypeId];
      List subpath = path.toList()..add(dartName(group));
      printStructFields(group, subpath, builder: builder);
    }
  }
}

String dartName(Node n) {
  assert(n.isStruct || n.isEnum);
  int prefixLength = n.displayNamePrefixLength;
  String fullDisplayName = n.displayName.toString();
  String name = fullDisplayName.substring(prefixLength);
  return name;
}

String dartGetPrimitive(Field field) {
  Type type = field.slotType;
  int offset = field.slotOffset;
  bool hasDefault = field.slotHadExplicitDefault;

  if (type.isBool) {
    assert(!hasDefault);  // Not implemented yet.
    return 'capnp.readBool(this, ${offset ~/ 8}, ${1 << (offset & 7)})';
  } else if (type.isInt8) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.int8}" : "";
    return 'capnp.readInt8(this, $offset)$xor';
  } else if (type.isInt16) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.int16}" : "";
    return 'capnp.readInt16(this, ${offset * 2})$xor';
  } else if (type.isInt32) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.int32}" : "";
    return 'capnp.readInt32(this, ${offset * 4})$xor';
  } else if (type.isInt64) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.int64}" : "";
    return 'capnp.readInt64(this, ${offset * 8})$xor';
  } else if (type.isUint8) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.uint8}" : "";
    return 'capnp.readUInt8(this, $offset)$xor';
  } else if (type.isUint16) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.uint16}" : "";
    return 'capnp.readUInt16(this, ${offset * 2})$xor';
  } else if (type.isUint32) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.uint32}" : "";
    return 'capnp.readUInt32(this, ${offset * 4})$xor';
  } else if (type.isUint64) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.uint64}" : "";
    return 'capnp.readUInt64(this, ${offset * 8})$xor';
  } else if (type.isFloat32) {
    assert(!hasDefault);  // Not implemented yet.
    return 'capnp.readFloat32(this, ${offset * 4})';
  } else if (type.isFloat64) {
    assert(!hasDefault);  // Not implemented yet.
    return 'capnp.readFloat32(this, ${offset * 8})';
  }

  if (type.isText) {
    return 'capnp.readText(this, $offset)';
  } else if (type.isData) {
    return 'capnp.readData(this, $offset)';
  } else if (type.isList) {
    Type elementType = type.listElementType;
    if (elementType.isUint64) {
      return 'capnp.readUInt64List(this, $offset)';
    } else {
      String constructor = "_${dartTypeOf(elementType)}List";
      return 'capnp.readStructList(new $constructor(), this, $offset)';
    }
  } else if (type.isEnum) {
    String name = dartName(nodes[type.enumTypeId]);
    return '$name.values[capnp.readUInt16(this, $offset)]';
  } else if (type.isStruct) {
    String name = dartName(nodes[type.structTypeId]);
    return 'capnp.readStruct(new $name(), this, $offset)';
  } else if (type.isInterface) {
    return '/* UNHANDLED: AnyPointer */ null';
  } else if (type.isAnyPointer) {
    return '/* UNHANDLED: AnyPointer */ null';
  } else {
    throw "Cannot handle $type of field ${field.name}.";
  }
}

String dartSetPrimitive(Field field) {
  Type type = field.slotType;
  int offset = field.slotOffset;
  bool hasDefault = field.slotHadExplicitDefault;

  if (type.isBool) {
    assert(!hasDefault);  // Not implemented yet.
    return 'capnp.writeBool(this, ${offset ~/ 8}, ${1 << (offset & 7)}, value)';
  } else if (type.isInt8) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.int8}" : "";
    return 'capnp.writeInt8(this, $offset, value$xor)';
  } else if (type.isInt16) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.int16}" : "";
    return 'capnp.writeInt16(this, ${offset * 2}, value$xor)';
  } else if (type.isInt32) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.int32}" : "";
    return 'capnp.writeInt32(this, ${offset * 4}, value$xor)';
  } else if (type.isInt64) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.int64}" : "";
    return 'capnp.writeInt64(this, ${offset * 8}, value$xor)';
  } else if (type.isUint8) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.uint8}" : "";
    return 'capnp.writeUInt8(this, $offset, value$xor)';
  } else if (type.isUint16) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.uint16}" : "";
    return 'capnp.writeUInt16(this, ${offset * 2}, value$xor)';
  } else if (type.isUint32) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.uint32}" : "";
    return 'capnp.writeUInt32(this, ${offset * 4}, value$xor)';
  } else if (type.isUint64) {
    String xor = hasDefault ? " ^ ${field.slotDefaultValue.uint64}" : "";
    return 'capnp.writeUInt64(this, ${offset * 8}, value$xor)';
  } else if (type.isFloat32) {
    assert(!hasDefault);  // Not implemented yet.
    return 'capnp.writeFloat32(this, ${offset * 4}, value)';
  } else if (type.isFloat64) {
    assert(!hasDefault);  // Not implemented yet.
    return 'capnp.writeFloat32(this, ${offset * 8}, value)';
  }

  if (type.isText) {
    return 'capnp.writeText(this, $offset, value)';
  } else if (type.isEnum) {
    return 'capnp.writeUInt16(this, ${offset * 2}, value.index)';
  } else {
    return 'null';
    // throw "Cannot handle $type of field ${field.name}.";
  }
}

String dartTypeOf(Type type) {
  if (type.isBool) {
    return 'bool';
  } else if (type.isFloat32 || type.isFloat64) {
    return 'double';
  } else if (type.isText) {
    return 'Text';
  } else if (type.isData) {
    return 'Data';
  } else if (type.isList) {
    String elementType = dartElementTypeOf(type.listElementType);
    return 'List<$elementType>';
  } else if (type.isEnum) {
    return dartName(nodes[type.enumTypeId]);
  } else if (type.isStruct) {
    return dartName(nodes[type.structTypeId]);
  } else {
    return 'int';
  }
}

String dartElementTypeOf(Type type) {
  if (type.isStruct) {
    Node node = nodes[type.structTypeId];
    usedLists.add(node);
  }
  return dartTypeOf(type);
}

Future<ByteBuffer> readEncodedBytes() async {
  StreamIterator iterator = new StreamIterator(io.stdin);
  await iterator.moveNext();
  return iterator.current.buffer;
}

