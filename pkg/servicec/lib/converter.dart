// Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.converter;

import 'node.dart' show
    CompilationUnitNode,
    FieldNode,
    FormalNode,
    FunctionNode,
    ListType,
    MemberNode,
    PointerType,
    RecursiveVisitor,
    ServiceNode,
    SimpleType,
    StructNode,
    TopLevelNode,
    TypeNode,
    UnionNode;

import 'package:old_servicec/src/parser.dart' as old;

import 'dart:collection' show
    Queue;

// Validation functions.
old.Unit convert(CompilationUnitNode compilationUnit) {
  Iterable<TopLevelNode> services =
    compilationUnit.topLevels.where((topLevel) => topLevel is ServiceNode);
  Iterable<TopLevelNode> structs =
    compilationUnit.topLevels.where((topLevel) => topLevel is StructNode);
  return new old.Unit(
      services.map(convertService).toList(),
      structs.map(convertStruct).toList());
}

old.Service convertService(ServiceNode service) {
  return new old.Service(
      service.identifier.value,
      service.functions.map(convertFunction).toList());
}

old.Struct convertStruct(StructNode struct) {
  Iterable<MemberNode> fields =
    struct.members.where((member) => member is FieldNode);
  Iterable<MemberNode> unions =
    struct.members.where((member) => member is UnionNode);
  return new old.Struct(
      struct.identifier.value,
      fields.map(convertField).toList(),
      unions.map(convertUnion).toList());
}

old.Method convertFunction(FunctionNode function) {
  return new old.Method(
      function.identifier.value,
      function.formals.map(convertFormal).toList(),
      convertType(function.returnType));
}

old.Formal convertFormal(FormalNode formal) {
  return new old.Formal(
      convertType(formal.type),
      formal.identifier.value);
}

old.Formal convertField(FieldNode field) {
  return new old.Formal(
      convertType(field.type),
      field.identifier.value);
}

old.Union convertUnion(UnionNode union) {
  return new old.Union(
      union.fields.map(convertField).toList());
}

old.Type convertType(TypeNode type) {
  if (type.isString()) {
    return new old.StringType();
  } else if (type.isPointer()) {
    return new old.SimpleType(type.identifier.value, true);
  } else if (type.isList()) {
    ListType listType = type;
    return new old.ListType(convertType(listType.typeParameter));
  } else {
    return new old.SimpleType(type.identifier.value, false);
  }
}
