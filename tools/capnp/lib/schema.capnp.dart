// Generated code. Do not edit.

library schema.capnp;

import 'internals.dart' as capnp;
import 'internals.dart' show Text, Data;
export 'internals.dart' show Text, Data;

enum ElementSize {
  empty,
  bit,
  byte,
  twoBytes,
  fourBytes,
  eightBytes,
  pointer,
  inlineComposite,
}

class Import extends capnp.Struct {
  int get declaredWords => 1;
  int get declaredPointers => 1;

  int get id => capnp.readUInt64(this, 0);

  Text get name => capnp.readText(this, 0);
}

class ImportBuilder extends capnp.StructBuilder {
  int get declaredWords => 1;
  int get declaredPointers => 1;
  int get declaredSize => 16;

  int get id => capnp.readUInt64(this, 0);
  void set id(int value) => capnp.writeUInt64(this, 0, value);

  String get name => capnp.readText(this, 0).toString();
  void set name(String value) => capnp.writeText(this, 0, value);
}

class CodeGeneratorRequest extends capnp.Struct {
  int get declaredWords => 0;
  int get declaredPointers => 2;

  List<Node> get nodes => capnp.readStructList(new _NodeList(), this, 0);

  List<RequestedFile> get requestedFiles => capnp.readStructList(new _RequestedFileList(), this, 1);
}

class CodeGeneratorRequestBuilder extends capnp.StructBuilder {
  int get declaredWords => 0;
  int get declaredPointers => 2;
  int get declaredSize => 16;

  List<Node> get nodes => capnp.readStructList(new _NodeList(), this, 0);
  List<NodeBuilder> initNodes(int length) => capnp.writeStructList(new _NodeListBuilder(length), this, 0);

  List<RequestedFile> get requestedFiles => capnp.readStructList(new _RequestedFileList(), this, 1);
  List<RequestedFileBuilder> initRequestedFiles(int length) => capnp.writeStructList(new _RequestedFileListBuilder(length), this, 1);
}

class RequestedFile extends capnp.Struct {
  int get declaredWords => 1;
  int get declaredPointers => 2;

  int get id => capnp.readUInt64(this, 0);

  Text get filename => capnp.readText(this, 0);

  List<Import> get imports => capnp.readStructList(new _ImportList(), this, 1);
}

class RequestedFileBuilder extends capnp.StructBuilder {
  int get declaredWords => 1;
  int get declaredPointers => 2;
  int get declaredSize => 24;

  int get id => capnp.readUInt64(this, 0);
  void set id(int value) => capnp.writeUInt64(this, 0, value);

  String get filename => capnp.readText(this, 0).toString();
  void set filename(String value) => capnp.writeText(this, 0, value);

  List<Import> get imports => capnp.readStructList(new _ImportList(), this, 1);
  List<ImportBuilder> initImports(int length) => capnp.writeStructList(new _ImportListBuilder(length), this, 1);
}

class Method extends capnp.Struct {
  int get declaredWords => 3;
  int get declaredPointers => 5;

  Text get name => capnp.readText(this, 0);

  int get codeOrder => capnp.readUInt16(this, 0);

  int get paramStructType => capnp.readUInt64(this, 8);

  int get resultStructType => capnp.readUInt64(this, 16);

  List<Annotation> get annotations => capnp.readStructList(new _AnnotationList(), this, 1);

  Brand get paramBrand => capnp.readStruct(new Brand(), this, 2);

  Brand get resultBrand => capnp.readStruct(new Brand(), this, 3);

  List<Parameter> get implicitParameters => capnp.readStructList(new _ParameterList(), this, 4);
}

class MethodBuilder extends capnp.StructBuilder {
  int get declaredWords => 3;
  int get declaredPointers => 5;
  int get declaredSize => 64;

  String get name => capnp.readText(this, 0).toString();
  void set name(String value) => capnp.writeText(this, 0, value);

  int get codeOrder => capnp.readUInt16(this, 0);
  void set codeOrder(int value) => capnp.writeUInt16(this, 0, value);

  int get paramStructType => capnp.readUInt64(this, 8);
  void set paramStructType(int value) => capnp.writeUInt64(this, 8, value);

  int get resultStructType => capnp.readUInt64(this, 16);
  void set resultStructType(int value) => capnp.writeUInt64(this, 16, value);

  List<Annotation> get annotations => capnp.readStructList(new _AnnotationList(), this, 1);
  List<AnnotationBuilder> initAnnotations(int length) => capnp.writeStructList(new _AnnotationListBuilder(length), this, 1);

  Brand get paramBrand => capnp.readStruct(new Brand(), this, 2);
  void set paramBrand(Brand value) => null;

  Brand get resultBrand => capnp.readStruct(new Brand(), this, 3);
  void set resultBrand(Brand value) => null;

  List<Parameter> get implicitParameters => capnp.readStructList(new _ParameterList(), this, 4);
  List<ParameterBuilder> initImplicitParameters(int length) => capnp.writeStructList(new _ParameterListBuilder(length), this, 4);
}

class Enumerant extends capnp.Struct {
  int get declaredWords => 1;
  int get declaredPointers => 2;

  Text get name => capnp.readText(this, 0);

  int get codeOrder => capnp.readUInt16(this, 0);

  List<Annotation> get annotations => capnp.readStructList(new _AnnotationList(), this, 1);
}

class EnumerantBuilder extends capnp.StructBuilder {
  int get declaredWords => 1;
  int get declaredPointers => 2;
  int get declaredSize => 24;

  String get name => capnp.readText(this, 0).toString();
  void set name(String value) => capnp.writeText(this, 0, value);

  int get codeOrder => capnp.readUInt16(this, 0);
  void set codeOrder(int value) => capnp.writeUInt16(this, 0, value);

  List<Annotation> get annotations => capnp.readStructList(new _AnnotationList(), this, 1);
  List<AnnotationBuilder> initAnnotations(int length) => capnp.writeStructList(new _AnnotationListBuilder(length), this, 1);
}

class Type extends capnp.Struct {
  int get declaredWords => 3;
  int get declaredPointers => 1;

  bool get isVoid => capnp.readUInt16(this, 0) == 0;

  bool get isBool => capnp.readUInt16(this, 0) == 1;

  bool get isInt8 => capnp.readUInt16(this, 0) == 2;

  bool get isInt16 => capnp.readUInt16(this, 0) == 3;

  bool get isInt32 => capnp.readUInt16(this, 0) == 4;

  bool get isInt64 => capnp.readUInt16(this, 0) == 5;

  bool get isUint8 => capnp.readUInt16(this, 0) == 6;

  bool get isUint16 => capnp.readUInt16(this, 0) == 7;

  bool get isUint32 => capnp.readUInt16(this, 0) == 8;

  bool get isUint64 => capnp.readUInt16(this, 0) == 9;

  bool get isFloat32 => capnp.readUInt16(this, 0) == 10;

  bool get isFloat64 => capnp.readUInt16(this, 0) == 11;

  bool get isText => capnp.readUInt16(this, 0) == 12;

  bool get isData => capnp.readUInt16(this, 0) == 13;

  bool get isList => capnp.readUInt16(this, 0) == 14;
  Type get listElementType => capnp.readStruct(new Type(), this, 0);

  bool get isEnum => capnp.readUInt16(this, 0) == 15;
  int get enumTypeId => capnp.readUInt64(this, 8);
  Brand get enumBrand => capnp.readStruct(new Brand(), this, 0);

  bool get isStruct => capnp.readUInt16(this, 0) == 16;
  int get structTypeId => capnp.readUInt64(this, 8);
  Brand get structBrand => capnp.readStruct(new Brand(), this, 0);

  bool get isInterface => capnp.readUInt16(this, 0) == 17;
  int get interfaceTypeId => capnp.readUInt64(this, 8);
  Brand get interfaceBrand => capnp.readStruct(new Brand(), this, 0);

  bool get isAnyPointer => capnp.readUInt16(this, 0) == 18;
  bool get anyPointerIsUnconstrained => capnp.readUInt16(this, 8) == 0;
  bool get anyPointerIsParameter => capnp.readUInt16(this, 8) == 1;
  int get anyPointerParameterScopeId => capnp.readUInt64(this, 16);
  int get anyPointerParameterParameterIndex => capnp.readUInt16(this, 10);
  bool get anyPointerIsImplicitMethodParameter => capnp.readUInt16(this, 8) == 2;
  int get anyPointerImplicitMethodParameterParameterIndex => capnp.readUInt16(this, 10);
}

class TypeBuilder extends capnp.StructBuilder {
  int get declaredWords => 3;
  int get declaredPointers => 1;
  int get declaredSize => 32;

  bool get isVoid => capnp.readUInt16(this, 0) == 0;
  void setVoid() => capnp.writeUInt16(this, 0, 0);

  bool get isBool => capnp.readUInt16(this, 0) == 1;
  void setBool() => capnp.writeUInt16(this, 0, 1);

  bool get isInt8 => capnp.readUInt16(this, 0) == 2;
  void setInt8() => capnp.writeUInt16(this, 0, 2);

  bool get isInt16 => capnp.readUInt16(this, 0) == 3;
  void setInt16() => capnp.writeUInt16(this, 0, 3);

  bool get isInt32 => capnp.readUInt16(this, 0) == 4;
  void setInt32() => capnp.writeUInt16(this, 0, 4);

  bool get isInt64 => capnp.readUInt16(this, 0) == 5;
  void setInt64() => capnp.writeUInt16(this, 0, 5);

  bool get isUint8 => capnp.readUInt16(this, 0) == 6;
  void setUint8() => capnp.writeUInt16(this, 0, 6);

  bool get isUint16 => capnp.readUInt16(this, 0) == 7;
  void setUint16() => capnp.writeUInt16(this, 0, 7);

  bool get isUint32 => capnp.readUInt16(this, 0) == 8;
  void setUint32() => capnp.writeUInt16(this, 0, 8);

  bool get isUint64 => capnp.readUInt16(this, 0) == 9;
  void setUint64() => capnp.writeUInt16(this, 0, 9);

  bool get isFloat32 => capnp.readUInt16(this, 0) == 10;
  void setFloat32() => capnp.writeUInt16(this, 0, 10);

  bool get isFloat64 => capnp.readUInt16(this, 0) == 11;
  void setFloat64() => capnp.writeUInt16(this, 0, 11);

  bool get isText => capnp.readUInt16(this, 0) == 12;
  void setText() => capnp.writeUInt16(this, 0, 12);

  bool get isData => capnp.readUInt16(this, 0) == 13;
  void setData() => capnp.writeUInt16(this, 0, 13);

  bool get isList => capnp.readUInt16(this, 0) == 14;
  void setList() => capnp.writeUInt16(this, 0, 14);
  Type get listElementType => capnp.readStruct(new Type(), this, 0);
  void set listElementType(Type value) => null;

  bool get isEnum => capnp.readUInt16(this, 0) == 15;
  void setEnum() => capnp.writeUInt16(this, 0, 15);
  int get enumTypeId => capnp.readUInt64(this, 8);
  void set enumTypeId(int value) => capnp.writeUInt64(this, 8, value);
  Brand get enumBrand => capnp.readStruct(new Brand(), this, 0);
  void set enumBrand(Brand value) => null;

  bool get isStruct => capnp.readUInt16(this, 0) == 16;
  void setStruct() => capnp.writeUInt16(this, 0, 16);
  int get structTypeId => capnp.readUInt64(this, 8);
  void set structTypeId(int value) => capnp.writeUInt64(this, 8, value);
  Brand get structBrand => capnp.readStruct(new Brand(), this, 0);
  void set structBrand(Brand value) => null;

  bool get isInterface => capnp.readUInt16(this, 0) == 17;
  void setInterface() => capnp.writeUInt16(this, 0, 17);
  int get interfaceTypeId => capnp.readUInt64(this, 8);
  void set interfaceTypeId(int value) => capnp.writeUInt64(this, 8, value);
  Brand get interfaceBrand => capnp.readStruct(new Brand(), this, 0);
  void set interfaceBrand(Brand value) => null;

  bool get isAnyPointer => capnp.readUInt16(this, 0) == 18;
  void setAnyPointer() => capnp.writeUInt16(this, 0, 18);
  bool get anyPointerIsUnconstrained => capnp.readUInt16(this, 8) == 0;
  void anyPointerSetUnconstrained() => capnp.writeUInt16(this, 8, 0);
  bool get anyPointerIsParameter => capnp.readUInt16(this, 8) == 1;
  void anyPointerSetParameter() => capnp.writeUInt16(this, 8, 1);
  int get anyPointerParameterScopeId => capnp.readUInt64(this, 16);
  void set anyPointerParameterScopeId(int value) => capnp.writeUInt64(this, 16, value);
  int get anyPointerParameterParameterIndex => capnp.readUInt16(this, 10);
  void set anyPointerParameterParameterIndex(int value) => capnp.writeUInt16(this, 10, value);
  bool get anyPointerIsImplicitMethodParameter => capnp.readUInt16(this, 8) == 2;
  void anyPointerSetImplicitMethodParameter() => capnp.writeUInt16(this, 8, 2);
  int get anyPointerImplicitMethodParameterParameterIndex => capnp.readUInt16(this, 10);
  void set anyPointerImplicitMethodParameterParameterIndex(int value) => capnp.writeUInt16(this, 10, value);
}

class Field extends capnp.Struct {
  int get declaredWords => 3;
  int get declaredPointers => 4;

  Text get name => capnp.readText(this, 0);

  int get codeOrder => capnp.readUInt16(this, 0);

  List<Annotation> get annotations => capnp.readStructList(new _AnnotationList(), this, 1);

  int get discriminantValue => capnp.readUInt16(this, 2) ^ 65535;

  bool get isSlot => capnp.readUInt16(this, 8) == 0;
  int get slotOffset => capnp.readUInt32(this, 4);
  Type get slotType => capnp.readStruct(new Type(), this, 2);
  Value get slotDefaultValue => capnp.readStruct(new Value(), this, 3);
  bool get slotHadExplicitDefault => capnp.readBool(this, 16, 1);

  bool get isGroup => capnp.readUInt16(this, 8) == 1;
  int get groupTypeId => capnp.readUInt64(this, 16);

  bool get ordinalIsImplicit => capnp.readUInt16(this, 10) == 0;
  bool get ordinalIsExplicit => capnp.readUInt16(this, 10) == 1;
  int get ordinalExplicit => capnp.readUInt16(this, 12);
}

class FieldBuilder extends capnp.StructBuilder {
  int get declaredWords => 3;
  int get declaredPointers => 4;
  int get declaredSize => 56;

  String get name => capnp.readText(this, 0).toString();
  void set name(String value) => capnp.writeText(this, 0, value);

  int get codeOrder => capnp.readUInt16(this, 0);
  void set codeOrder(int value) => capnp.writeUInt16(this, 0, value);

  List<Annotation> get annotations => capnp.readStructList(new _AnnotationList(), this, 1);
  List<AnnotationBuilder> initAnnotations(int length) => capnp.writeStructList(new _AnnotationListBuilder(length), this, 1);

  int get discriminantValue => capnp.readUInt16(this, 2) ^ 65535;
  void set discriminantValue(int value) => capnp.writeUInt16(this, 2, value ^ 65535);

  bool get isSlot => capnp.readUInt16(this, 8) == 0;
  void setSlot() => capnp.writeUInt16(this, 8, 0);
  int get slotOffset => capnp.readUInt32(this, 4);
  void set slotOffset(int value) => capnp.writeUInt32(this, 4, value);
  Type get slotType => capnp.readStruct(new Type(), this, 2);
  void set slotType(Type value) => null;
  Value get slotDefaultValue => capnp.readStruct(new Value(), this, 3);
  void set slotDefaultValue(Value value) => null;
  bool get slotHadExplicitDefault => capnp.readBool(this, 16, 1);
  void set slotHadExplicitDefault(bool value) => capnp.writeBool(this, 16, 1, value);

  bool get isGroup => capnp.readUInt16(this, 8) == 1;
  void setGroup() => capnp.writeUInt16(this, 8, 1);
  int get groupTypeId => capnp.readUInt64(this, 16);
  void set groupTypeId(int value) => capnp.writeUInt64(this, 16, value);

  bool get ordinalIsImplicit => capnp.readUInt16(this, 10) == 0;
  void ordinalSetImplicit() => capnp.writeUInt16(this, 10, 0);
  bool get ordinalIsExplicit => capnp.readUInt16(this, 10) == 1;
  void ordinalSetExplicit() => capnp.writeUInt16(this, 10, 1);
  int get ordinalExplicit => capnp.readUInt16(this, 12);
  void set ordinalExplicit(int value) => capnp.writeUInt16(this, 12, value);
}

class Binding extends capnp.Struct {
  int get declaredWords => 1;
  int get declaredPointers => 1;

  bool get isUnbound => capnp.readUInt16(this, 0) == 0;

  bool get isType => capnp.readUInt16(this, 0) == 1;
  Type get type => capnp.readStruct(new Type(), this, 0);
}

class BindingBuilder extends capnp.StructBuilder {
  int get declaredWords => 1;
  int get declaredPointers => 1;
  int get declaredSize => 16;

  bool get isUnbound => capnp.readUInt16(this, 0) == 0;
  void setUnbound() => capnp.writeUInt16(this, 0, 0);

  bool get isType => capnp.readUInt16(this, 0) == 1;
  void setType() => capnp.writeUInt16(this, 0, 1);
  Type get type => capnp.readStruct(new Type(), this, 0);
  void set type(Type value) => null;
}

class Superclass extends capnp.Struct {
  int get declaredWords => 1;
  int get declaredPointers => 1;

  int get id => capnp.readUInt64(this, 0);

  Brand get brand => capnp.readStruct(new Brand(), this, 0);
}

class SuperclassBuilder extends capnp.StructBuilder {
  int get declaredWords => 1;
  int get declaredPointers => 1;
  int get declaredSize => 16;

  int get id => capnp.readUInt64(this, 0);
  void set id(int value) => capnp.writeUInt64(this, 0, value);

  Brand get brand => capnp.readStruct(new Brand(), this, 0);
  void set brand(Brand value) => null;
}

class Value extends capnp.Struct {
  int get declaredWords => 2;
  int get declaredPointers => 1;

  bool get isVoid => capnp.readUInt16(this, 0) == 0;

  bool get isBool => capnp.readUInt16(this, 0) == 1;
  bool get $bool => capnp.readBool(this, 2, 1);

  bool get isInt8 => capnp.readUInt16(this, 0) == 2;
  int get int8 => capnp.readInt8(this, 2);

  bool get isInt16 => capnp.readUInt16(this, 0) == 3;
  int get int16 => capnp.readInt16(this, 2);

  bool get isInt32 => capnp.readUInt16(this, 0) == 4;
  int get int32 => capnp.readInt32(this, 4);

  bool get isInt64 => capnp.readUInt16(this, 0) == 5;
  int get int64 => capnp.readInt64(this, 8);

  bool get isUint8 => capnp.readUInt16(this, 0) == 6;
  int get uint8 => capnp.readUInt8(this, 2);

  bool get isUint16 => capnp.readUInt16(this, 0) == 7;
  int get uint16 => capnp.readUInt16(this, 2);

  bool get isUint32 => capnp.readUInt16(this, 0) == 8;
  int get uint32 => capnp.readUInt32(this, 4);

  bool get isUint64 => capnp.readUInt16(this, 0) == 9;
  int get uint64 => capnp.readUInt64(this, 8);

  bool get isFloat32 => capnp.readUInt16(this, 0) == 10;
  double get float32 => capnp.readFloat32(this, 4);

  bool get isFloat64 => capnp.readUInt16(this, 0) == 11;
  double get float64 => capnp.readFloat32(this, 8);

  bool get isText => capnp.readUInt16(this, 0) == 12;
  Text get text => capnp.readText(this, 0);

  bool get isData => capnp.readUInt16(this, 0) == 13;
  Data get data => capnp.readData(this, 0);

  bool get isList => capnp.readUInt16(this, 0) == 14;
  int get list => /* UNHANDLED: AnyPointer */ null;

  bool get isEnum => capnp.readUInt16(this, 0) == 15;
  int get $enum => capnp.readUInt16(this, 2);

  bool get isStruct => capnp.readUInt16(this, 0) == 16;
  int get struct => /* UNHANDLED: AnyPointer */ null;

  bool get isInterface => capnp.readUInt16(this, 0) == 17;

  bool get isAnyPointer => capnp.readUInt16(this, 0) == 18;
  int get anyPointer => /* UNHANDLED: AnyPointer */ null;
}

class ValueBuilder extends capnp.StructBuilder {
  int get declaredWords => 2;
  int get declaredPointers => 1;
  int get declaredSize => 24;

  bool get isVoid => capnp.readUInt16(this, 0) == 0;
  void setVoid() => capnp.writeUInt16(this, 0, 0);

  bool get isBool => capnp.readUInt16(this, 0) == 1;
  void setBool() => capnp.writeUInt16(this, 0, 1);
  bool get $bool => capnp.readBool(this, 2, 1);
  void set $bool(bool value) => capnp.writeBool(this, 2, 1, value);

  bool get isInt8 => capnp.readUInt16(this, 0) == 2;
  void setInt8() => capnp.writeUInt16(this, 0, 2);
  int get int8 => capnp.readInt8(this, 2);
  void set int8(int value) => capnp.writeInt8(this, 2, value);

  bool get isInt16 => capnp.readUInt16(this, 0) == 3;
  void setInt16() => capnp.writeUInt16(this, 0, 3);
  int get int16 => capnp.readInt16(this, 2);
  void set int16(int value) => capnp.writeInt16(this, 2, value);

  bool get isInt32 => capnp.readUInt16(this, 0) == 4;
  void setInt32() => capnp.writeUInt16(this, 0, 4);
  int get int32 => capnp.readInt32(this, 4);
  void set int32(int value) => capnp.writeInt32(this, 4, value);

  bool get isInt64 => capnp.readUInt16(this, 0) == 5;
  void setInt64() => capnp.writeUInt16(this, 0, 5);
  int get int64 => capnp.readInt64(this, 8);
  void set int64(int value) => capnp.writeInt64(this, 8, value);

  bool get isUint8 => capnp.readUInt16(this, 0) == 6;
  void setUint8() => capnp.writeUInt16(this, 0, 6);
  int get uint8 => capnp.readUInt8(this, 2);
  void set uint8(int value) => capnp.writeUInt8(this, 2, value);

  bool get isUint16 => capnp.readUInt16(this, 0) == 7;
  void setUint16() => capnp.writeUInt16(this, 0, 7);
  int get uint16 => capnp.readUInt16(this, 2);
  void set uint16(int value) => capnp.writeUInt16(this, 2, value);

  bool get isUint32 => capnp.readUInt16(this, 0) == 8;
  void setUint32() => capnp.writeUInt16(this, 0, 8);
  int get uint32 => capnp.readUInt32(this, 4);
  void set uint32(int value) => capnp.writeUInt32(this, 4, value);

  bool get isUint64 => capnp.readUInt16(this, 0) == 9;
  void setUint64() => capnp.writeUInt16(this, 0, 9);
  int get uint64 => capnp.readUInt64(this, 8);
  void set uint64(int value) => capnp.writeUInt64(this, 8, value);

  bool get isFloat32 => capnp.readUInt16(this, 0) == 10;
  void setFloat32() => capnp.writeUInt16(this, 0, 10);
  double get float32 => capnp.readFloat32(this, 4);
  void set float32(double value) => capnp.writeFloat32(this, 4, value);

  bool get isFloat64 => capnp.readUInt16(this, 0) == 11;
  void setFloat64() => capnp.writeUInt16(this, 0, 11);
  double get float64 => capnp.readFloat32(this, 8);
  void set float64(double value) => capnp.writeFloat32(this, 8, value);

  bool get isText => capnp.readUInt16(this, 0) == 12;
  void setText() => capnp.writeUInt16(this, 0, 12);
  String get text => capnp.readText(this, 0).toString();
  void set text(String value) => capnp.writeText(this, 0, value);

  bool get isData => capnp.readUInt16(this, 0) == 13;
  void setData() => capnp.writeUInt16(this, 0, 13);
  Data get data => capnp.readData(this, 0);
  void set data(Data value) => null;

  bool get isList => capnp.readUInt16(this, 0) == 14;
  void setList() => capnp.writeUInt16(this, 0, 14);
  int get list => /* UNHANDLED: AnyPointer */ null;
  void set list(int value) => null;

  bool get isEnum => capnp.readUInt16(this, 0) == 15;
  void setEnum() => capnp.writeUInt16(this, 0, 15);
  int get $enum => capnp.readUInt16(this, 2);
  void set $enum(int value) => capnp.writeUInt16(this, 2, value);

  bool get isStruct => capnp.readUInt16(this, 0) == 16;
  void setStruct() => capnp.writeUInt16(this, 0, 16);
  int get struct => /* UNHANDLED: AnyPointer */ null;
  void set struct(int value) => null;

  bool get isInterface => capnp.readUInt16(this, 0) == 17;
  void setInterface() => capnp.writeUInt16(this, 0, 17);

  bool get isAnyPointer => capnp.readUInt16(this, 0) == 18;
  void setAnyPointer() => capnp.writeUInt16(this, 0, 18);
  int get anyPointer => /* UNHANDLED: AnyPointer */ null;
  void set anyPointer(int value) => null;
}

class Brand extends capnp.Struct {
  int get declaredWords => 0;
  int get declaredPointers => 1;

  List<Scope> get scopes => capnp.readStructList(new _ScopeList(), this, 0);
}

class BrandBuilder extends capnp.StructBuilder {
  int get declaredWords => 0;
  int get declaredPointers => 1;
  int get declaredSize => 8;

  List<Scope> get scopes => capnp.readStructList(new _ScopeList(), this, 0);
  List<ScopeBuilder> initScopes(int length) => capnp.writeStructList(new _ScopeListBuilder(length), this, 0);
}

class NestedNode extends capnp.Struct {
  int get declaredWords => 1;
  int get declaredPointers => 1;

  Text get name => capnp.readText(this, 0);

  int get id => capnp.readUInt64(this, 0);
}

class NestedNodeBuilder extends capnp.StructBuilder {
  int get declaredWords => 1;
  int get declaredPointers => 1;
  int get declaredSize => 16;

  String get name => capnp.readText(this, 0).toString();
  void set name(String value) => capnp.writeText(this, 0, value);

  int get id => capnp.readUInt64(this, 0);
  void set id(int value) => capnp.writeUInt64(this, 0, value);
}

class Annotation extends capnp.Struct {
  int get declaredWords => 1;
  int get declaredPointers => 2;

  int get id => capnp.readUInt64(this, 0);

  Value get value => capnp.readStruct(new Value(), this, 0);

  Brand get brand => capnp.readStruct(new Brand(), this, 1);
}

class AnnotationBuilder extends capnp.StructBuilder {
  int get declaredWords => 1;
  int get declaredPointers => 2;
  int get declaredSize => 24;

  int get id => capnp.readUInt64(this, 0);
  void set id(int value) => capnp.writeUInt64(this, 0, value);

  Value get value => capnp.readStruct(new Value(), this, 0);
  void set value(Value value) => null;

  Brand get brand => capnp.readStruct(new Brand(), this, 1);
  void set brand(Brand value) => null;
}

class Parameter extends capnp.Struct {
  int get declaredWords => 0;
  int get declaredPointers => 1;

  Text get name => capnp.readText(this, 0);
}

class ParameterBuilder extends capnp.StructBuilder {
  int get declaredWords => 0;
  int get declaredPointers => 1;
  int get declaredSize => 8;

  String get name => capnp.readText(this, 0).toString();
  void set name(String value) => capnp.writeText(this, 0, value);
}

class Node extends capnp.Struct {
  int get declaredWords => 5;
  int get declaredPointers => 6;

  int get id => capnp.readUInt64(this, 0);

  Text get displayName => capnp.readText(this, 0);

  int get displayNamePrefixLength => capnp.readUInt32(this, 8);

  int get scopeId => capnp.readUInt64(this, 16);

  List<NestedNode> get nestedNodes => capnp.readStructList(new _NestedNodeList(), this, 1);

  List<Annotation> get annotations => capnp.readStructList(new _AnnotationList(), this, 2);

  bool get isFile => capnp.readUInt16(this, 12) == 0;

  bool get isStruct => capnp.readUInt16(this, 12) == 1;
  int get structDataWordCount => capnp.readUInt16(this, 14);
  int get structPointerCount => capnp.readUInt16(this, 24);
  ElementSize get structPreferredListEncoding => ElementSize.values[capnp.readUInt16(this, 13)];
  bool get structIsGroup => capnp.readBool(this, 28, 1);
  int get structDiscriminantCount => capnp.readUInt16(this, 30);
  int get structDiscriminantOffset => capnp.readUInt32(this, 32);
  List<Field> get structFields => capnp.readStructList(new _FieldList(), this, 3);

  bool get isEnum => capnp.readUInt16(this, 12) == 2;
  List<Enumerant> get enumEnumerants => capnp.readStructList(new _EnumerantList(), this, 3);

  bool get isInterface => capnp.readUInt16(this, 12) == 3;
  List<Method> get interfaceMethods => capnp.readStructList(new _MethodList(), this, 3);
  List<Superclass> get interfaceSuperclasses => capnp.readStructList(new _SuperclassList(), this, 4);

  bool get isConst => capnp.readUInt16(this, 12) == 4;
  Type get constType => capnp.readStruct(new Type(), this, 3);
  Value get constValue => capnp.readStruct(new Value(), this, 4);

  bool get isAnnotation => capnp.readUInt16(this, 12) == 5;
  Type get annotationType => capnp.readStruct(new Type(), this, 3);
  bool get annotationTargetsFile => capnp.readBool(this, 14, 1);
  bool get annotationTargetsConst => capnp.readBool(this, 14, 2);
  bool get annotationTargetsEnum => capnp.readBool(this, 14, 4);
  bool get annotationTargetsEnumerant => capnp.readBool(this, 14, 8);
  bool get annotationTargetsStruct => capnp.readBool(this, 14, 16);
  bool get annotationTargetsField => capnp.readBool(this, 14, 32);
  bool get annotationTargetsUnion => capnp.readBool(this, 14, 64);
  bool get annotationTargetsGroup => capnp.readBool(this, 14, 128);
  bool get annotationTargetsInterface => capnp.readBool(this, 15, 1);
  bool get annotationTargetsMethod => capnp.readBool(this, 15, 2);
  bool get annotationTargetsParam => capnp.readBool(this, 15, 4);
  bool get annotationTargetsAnnotation => capnp.readBool(this, 15, 8);

  List<Parameter> get parameters => capnp.readStructList(new _ParameterList(), this, 5);

  bool get isGeneric => capnp.readBool(this, 36, 1);
}

class NodeBuilder extends capnp.StructBuilder {
  int get declaredWords => 5;
  int get declaredPointers => 6;
  int get declaredSize => 88;

  int get id => capnp.readUInt64(this, 0);
  void set id(int value) => capnp.writeUInt64(this, 0, value);

  String get displayName => capnp.readText(this, 0).toString();
  void set displayName(String value) => capnp.writeText(this, 0, value);

  int get displayNamePrefixLength => capnp.readUInt32(this, 8);
  void set displayNamePrefixLength(int value) => capnp.writeUInt32(this, 8, value);

  int get scopeId => capnp.readUInt64(this, 16);
  void set scopeId(int value) => capnp.writeUInt64(this, 16, value);

  List<NestedNode> get nestedNodes => capnp.readStructList(new _NestedNodeList(), this, 1);
  List<NestedNodeBuilder> initNestedNodes(int length) => capnp.writeStructList(new _NestedNodeListBuilder(length), this, 1);

  List<Annotation> get annotations => capnp.readStructList(new _AnnotationList(), this, 2);
  List<AnnotationBuilder> initAnnotations(int length) => capnp.writeStructList(new _AnnotationListBuilder(length), this, 2);

  bool get isFile => capnp.readUInt16(this, 12) == 0;
  void setFile() => capnp.writeUInt16(this, 12, 0);

  bool get isStruct => capnp.readUInt16(this, 12) == 1;
  void setStruct() => capnp.writeUInt16(this, 12, 1);
  int get structDataWordCount => capnp.readUInt16(this, 14);
  void set structDataWordCount(int value) => capnp.writeUInt16(this, 14, value);
  int get structPointerCount => capnp.readUInt16(this, 24);
  void set structPointerCount(int value) => capnp.writeUInt16(this, 24, value);
  ElementSize get structPreferredListEncoding => ElementSize.values[capnp.readUInt16(this, 13)];
  void set structPreferredListEncoding(ElementSize value) => capnp.writeUInt16(this, 26, value.index);
  bool get structIsGroup => capnp.readBool(this, 28, 1);
  void set structIsGroup(bool value) => capnp.writeBool(this, 28, 1, value);
  int get structDiscriminantCount => capnp.readUInt16(this, 30);
  void set structDiscriminantCount(int value) => capnp.writeUInt16(this, 30, value);
  int get structDiscriminantOffset => capnp.readUInt32(this, 32);
  void set structDiscriminantOffset(int value) => capnp.writeUInt32(this, 32, value);
  List<Field> get structFields => capnp.readStructList(new _FieldList(), this, 3);
  List<FieldBuilder> structInitFields(int length) => capnp.writeStructList(new _FieldListBuilder(length), this, 3);

  bool get isEnum => capnp.readUInt16(this, 12) == 2;
  void setEnum() => capnp.writeUInt16(this, 12, 2);
  List<Enumerant> get enumEnumerants => capnp.readStructList(new _EnumerantList(), this, 3);
  List<EnumerantBuilder> enumInitEnumerants(int length) => capnp.writeStructList(new _EnumerantListBuilder(length), this, 3);

  bool get isInterface => capnp.readUInt16(this, 12) == 3;
  void setInterface() => capnp.writeUInt16(this, 12, 3);
  List<Method> get interfaceMethods => capnp.readStructList(new _MethodList(), this, 3);
  List<MethodBuilder> interfaceInitMethods(int length) => capnp.writeStructList(new _MethodListBuilder(length), this, 3);
  List<Superclass> get interfaceSuperclasses => capnp.readStructList(new _SuperclassList(), this, 4);
  List<SuperclassBuilder> interfaceInitSuperclasses(int length) => capnp.writeStructList(new _SuperclassListBuilder(length), this, 4);

  bool get isConst => capnp.readUInt16(this, 12) == 4;
  void setConst() => capnp.writeUInt16(this, 12, 4);
  Type get constType => capnp.readStruct(new Type(), this, 3);
  void set constType(Type value) => null;
  Value get constValue => capnp.readStruct(new Value(), this, 4);
  void set constValue(Value value) => null;

  bool get isAnnotation => capnp.readUInt16(this, 12) == 5;
  void setAnnotation() => capnp.writeUInt16(this, 12, 5);
  Type get annotationType => capnp.readStruct(new Type(), this, 3);
  void set annotationType(Type value) => null;
  bool get annotationTargetsFile => capnp.readBool(this, 14, 1);
  void set annotationTargetsFile(bool value) => capnp.writeBool(this, 14, 1, value);
  bool get annotationTargetsConst => capnp.readBool(this, 14, 2);
  void set annotationTargetsConst(bool value) => capnp.writeBool(this, 14, 2, value);
  bool get annotationTargetsEnum => capnp.readBool(this, 14, 4);
  void set annotationTargetsEnum(bool value) => capnp.writeBool(this, 14, 4, value);
  bool get annotationTargetsEnumerant => capnp.readBool(this, 14, 8);
  void set annotationTargetsEnumerant(bool value) => capnp.writeBool(this, 14, 8, value);
  bool get annotationTargetsStruct => capnp.readBool(this, 14, 16);
  void set annotationTargetsStruct(bool value) => capnp.writeBool(this, 14, 16, value);
  bool get annotationTargetsField => capnp.readBool(this, 14, 32);
  void set annotationTargetsField(bool value) => capnp.writeBool(this, 14, 32, value);
  bool get annotationTargetsUnion => capnp.readBool(this, 14, 64);
  void set annotationTargetsUnion(bool value) => capnp.writeBool(this, 14, 64, value);
  bool get annotationTargetsGroup => capnp.readBool(this, 14, 128);
  void set annotationTargetsGroup(bool value) => capnp.writeBool(this, 14, 128, value);
  bool get annotationTargetsInterface => capnp.readBool(this, 15, 1);
  void set annotationTargetsInterface(bool value) => capnp.writeBool(this, 15, 1, value);
  bool get annotationTargetsMethod => capnp.readBool(this, 15, 2);
  void set annotationTargetsMethod(bool value) => capnp.writeBool(this, 15, 2, value);
  bool get annotationTargetsParam => capnp.readBool(this, 15, 4);
  void set annotationTargetsParam(bool value) => capnp.writeBool(this, 15, 4, value);
  bool get annotationTargetsAnnotation => capnp.readBool(this, 15, 8);
  void set annotationTargetsAnnotation(bool value) => capnp.writeBool(this, 15, 8, value);

  List<Parameter> get parameters => capnp.readStructList(new _ParameterList(), this, 5);
  List<ParameterBuilder> initParameters(int length) => capnp.writeStructList(new _ParameterListBuilder(length), this, 5);

  bool get isGeneric => capnp.readBool(this, 36, 1);
  void set isGeneric(bool value) => capnp.writeBool(this, 36, 1, value);
}

class Scope extends capnp.Struct {
  int get declaredWords => 2;
  int get declaredPointers => 1;

  int get scopeId => capnp.readUInt64(this, 0);

  bool get isBind => capnp.readUInt16(this, 8) == 0;
  List<Binding> get bind => capnp.readStructList(new _BindingList(), this, 0);

  bool get isInherit => capnp.readUInt16(this, 8) == 1;
}

class ScopeBuilder extends capnp.StructBuilder {
  int get declaredWords => 2;
  int get declaredPointers => 1;
  int get declaredSize => 24;

  int get scopeId => capnp.readUInt64(this, 0);
  void set scopeId(int value) => capnp.writeUInt64(this, 0, value);

  bool get isBind => capnp.readUInt16(this, 8) == 0;
  void setBind() => capnp.writeUInt16(this, 8, 0);
  List<Binding> get bind => capnp.readStructList(new _BindingList(), this, 0);
  List<BindingBuilder> initBind(int length) => capnp.writeStructList(new _BindingListBuilder(length), this, 0);

  bool get isInherit => capnp.readUInt16(this, 8) == 1;
  void setInherit() => capnp.writeUInt16(this, 8, 1);
}


// ------------------------- Private list types -------------------------

class _NodeList extends capnp.StructList implements List<Node> {
  int get declaredElementWords => 5;
  int get declaredElementPointers => 6;
  Node operator[](int index) => capnp.readStructListElement(new Node(), this, index);
}

class _NodeListBuilder extends capnp.StructListBuilder implements List<NodeBuilder> {
  final int length;
  _NodeListBuilder(this.length);

  int get declaredElementWords => 5;
  int get declaredElementPointers => 6;
  int get declaredElementSize => 88;

  NodeBuilder operator[](int index) => capnp.writeStructListElement(new NodeBuilder(), this, index);
}

class _RequestedFileList extends capnp.StructList implements List<RequestedFile> {
  int get declaredElementWords => 1;
  int get declaredElementPointers => 2;
  RequestedFile operator[](int index) => capnp.readStructListElement(new RequestedFile(), this, index);
}

class _RequestedFileListBuilder extends capnp.StructListBuilder implements List<RequestedFileBuilder> {
  final int length;
  _RequestedFileListBuilder(this.length);

  int get declaredElementWords => 1;
  int get declaredElementPointers => 2;
  int get declaredElementSize => 24;

  RequestedFileBuilder operator[](int index) => capnp.writeStructListElement(new RequestedFileBuilder(), this, index);
}

class _ImportList extends capnp.StructList implements List<Import> {
  int get declaredElementWords => 1;
  int get declaredElementPointers => 1;
  Import operator[](int index) => capnp.readStructListElement(new Import(), this, index);
}

class _ImportListBuilder extends capnp.StructListBuilder implements List<ImportBuilder> {
  final int length;
  _ImportListBuilder(this.length);

  int get declaredElementWords => 1;
  int get declaredElementPointers => 1;
  int get declaredElementSize => 16;

  ImportBuilder operator[](int index) => capnp.writeStructListElement(new ImportBuilder(), this, index);
}

class _AnnotationList extends capnp.StructList implements List<Annotation> {
  int get declaredElementWords => 1;
  int get declaredElementPointers => 2;
  Annotation operator[](int index) => capnp.readStructListElement(new Annotation(), this, index);
}

class _AnnotationListBuilder extends capnp.StructListBuilder implements List<AnnotationBuilder> {
  final int length;
  _AnnotationListBuilder(this.length);

  int get declaredElementWords => 1;
  int get declaredElementPointers => 2;
  int get declaredElementSize => 24;

  AnnotationBuilder operator[](int index) => capnp.writeStructListElement(new AnnotationBuilder(), this, index);
}

class _ParameterList extends capnp.StructList implements List<Parameter> {
  int get declaredElementWords => 0;
  int get declaredElementPointers => 1;
  Parameter operator[](int index) => capnp.readStructListElement(new Parameter(), this, index);
}

class _ParameterListBuilder extends capnp.StructListBuilder implements List<ParameterBuilder> {
  final int length;
  _ParameterListBuilder(this.length);

  int get declaredElementWords => 0;
  int get declaredElementPointers => 1;
  int get declaredElementSize => 8;

  ParameterBuilder operator[](int index) => capnp.writeStructListElement(new ParameterBuilder(), this, index);
}

class _ScopeList extends capnp.StructList implements List<Scope> {
  int get declaredElementWords => 2;
  int get declaredElementPointers => 1;
  Scope operator[](int index) => capnp.readStructListElement(new Scope(), this, index);
}

class _ScopeListBuilder extends capnp.StructListBuilder implements List<ScopeBuilder> {
  final int length;
  _ScopeListBuilder(this.length);

  int get declaredElementWords => 2;
  int get declaredElementPointers => 1;
  int get declaredElementSize => 24;

  ScopeBuilder operator[](int index) => capnp.writeStructListElement(new ScopeBuilder(), this, index);
}

class _NestedNodeList extends capnp.StructList implements List<NestedNode> {
  int get declaredElementWords => 1;
  int get declaredElementPointers => 1;
  NestedNode operator[](int index) => capnp.readStructListElement(new NestedNode(), this, index);
}

class _NestedNodeListBuilder extends capnp.StructListBuilder implements List<NestedNodeBuilder> {
  final int length;
  _NestedNodeListBuilder(this.length);

  int get declaredElementWords => 1;
  int get declaredElementPointers => 1;
  int get declaredElementSize => 16;

  NestedNodeBuilder operator[](int index) => capnp.writeStructListElement(new NestedNodeBuilder(), this, index);
}

class _FieldList extends capnp.StructList implements List<Field> {
  int get declaredElementWords => 3;
  int get declaredElementPointers => 4;
  Field operator[](int index) => capnp.readStructListElement(new Field(), this, index);
}

class _FieldListBuilder extends capnp.StructListBuilder implements List<FieldBuilder> {
  final int length;
  _FieldListBuilder(this.length);

  int get declaredElementWords => 3;
  int get declaredElementPointers => 4;
  int get declaredElementSize => 56;

  FieldBuilder operator[](int index) => capnp.writeStructListElement(new FieldBuilder(), this, index);
}

class _EnumerantList extends capnp.StructList implements List<Enumerant> {
  int get declaredElementWords => 1;
  int get declaredElementPointers => 2;
  Enumerant operator[](int index) => capnp.readStructListElement(new Enumerant(), this, index);
}

class _EnumerantListBuilder extends capnp.StructListBuilder implements List<EnumerantBuilder> {
  final int length;
  _EnumerantListBuilder(this.length);

  int get declaredElementWords => 1;
  int get declaredElementPointers => 2;
  int get declaredElementSize => 24;

  EnumerantBuilder operator[](int index) => capnp.writeStructListElement(new EnumerantBuilder(), this, index);
}

class _MethodList extends capnp.StructList implements List<Method> {
  int get declaredElementWords => 3;
  int get declaredElementPointers => 5;
  Method operator[](int index) => capnp.readStructListElement(new Method(), this, index);
}

class _MethodListBuilder extends capnp.StructListBuilder implements List<MethodBuilder> {
  final int length;
  _MethodListBuilder(this.length);

  int get declaredElementWords => 3;
  int get declaredElementPointers => 5;
  int get declaredElementSize => 64;

  MethodBuilder operator[](int index) => capnp.writeStructListElement(new MethodBuilder(), this, index);
}

class _SuperclassList extends capnp.StructList implements List<Superclass> {
  int get declaredElementWords => 1;
  int get declaredElementPointers => 1;
  Superclass operator[](int index) => capnp.readStructListElement(new Superclass(), this, index);
}

class _SuperclassListBuilder extends capnp.StructListBuilder implements List<SuperclassBuilder> {
  final int length;
  _SuperclassListBuilder(this.length);

  int get declaredElementWords => 1;
  int get declaredElementPointers => 1;
  int get declaredElementSize => 16;

  SuperclassBuilder operator[](int index) => capnp.writeStructListElement(new SuperclassBuilder(), this, index);
}

class _BindingList extends capnp.StructList implements List<Binding> {
  int get declaredElementWords => 1;
  int get declaredElementPointers => 1;
  Binding operator[](int index) => capnp.readStructListElement(new Binding(), this, index);
}

class _BindingListBuilder extends capnp.StructListBuilder implements List<BindingBuilder> {
  final int length;
  _BindingListBuilder(this.length);

  int get declaredElementWords => 1;
  int get declaredElementPointers => 1;
  int get declaredElementSize => 16;

  BindingBuilder operator[](int index) => capnp.writeStructListElement(new BindingBuilder(), this, index);
}

