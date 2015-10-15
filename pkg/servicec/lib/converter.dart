// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.converter;

import 'node.dart' show
    CompilationUnitNode,
    FieldNode,
    FormalNode,
    FunctionNode,
    ListType,
    PointerType,
    RecursiveVisitor,
    ServiceNode,
    SimpleType,
    StructNode,
    TypeNode,
    UnionNode;

import 'package:old_servicec/src/parser.dart' as old;

// Validation functions.
old.Unit convert(CompilationUnitNode compilationUnit) {
  Converter converter = new Converter();
  converter.visitCompilationUnit(compilationUnit);
  return converter.nodeStack.removeLast();
}

class Converter extends RecursiveVisitor {
  List<old.Node> nodeStack = <old.Node>[];

  void visitCompilationUnit(CompilationUnitNode compilationUnit) {
    super.visitCompilationUnit(compilationUnit);
    List<old.Service> services = <old.Service>[];
    List<old.Struct> structs = <old.Struct>[];
    while (nodeStack.isNotEmpty) {
      old.Node top = nodeStack.removeLast();
      if (top is old.Service) {
        services.add(top);
      }
      if (top is old.Struct) {
        structs.add(top);
      }
    }
    nodeStack.add(new old.Unit(services, structs));
  }

  void visitService(ServiceNode service) {
    super.visitService(service);
    List<old.Method> methods = <old.Method>[];
    while (nodeStack.isNotEmpty && nodeStack.last is old.Method) {
      methods.add(nodeStack.removeLast());
    }
    nodeStack.add(new old.Service(service.identifier.value, methods));
  }

  void visitStruct(StructNode struct) {
    super.visitStruct(struct);
    List<old.Formal> slots = <old.Formal>[];
    List<old.Union> unions = <old.Union>[];
    while (nodeStack.isNotEmpty) {
      old.Node top = nodeStack.last;
      if (top is old.Formal) {
        slots.add(top);
      }
      if (top is old.Union) {
        unions.add(top);
      } else {
        break;
      }
      nodeStack.removeLast();
    }
    nodeStack.add(new old.Struct(struct.identifier.value, slots, unions));
  }

  void visitFunction(FunctionNode function) {
    super.visitFunction(function);
    List<old.Formal> arguments = <old.Formal>[];
    while (nodeStack.isNotEmpty && nodeStack.last is old.Formal) {
      arguments.add(nodeStack.removeLast());
    }
    old.Type type = convertType(function.returnType);
    nodeStack.add(new old.Method(function.identifier.value, arguments, type));
  }

  void visitFormal(FormalNode formal) {
    old.Type type = convertType(formal.type);
    nodeStack.add(new old.Formal(type, formal.identifier.value));
  }

  void visitUnion(UnionNode union) {
    super.visitUnion(union);
    List<old.Formal> slots = <old.Formal>[];
    while (nodeStack.isNotEmpty && nodeStack.last is old.Formal) {
      slots.add(nodeStack.removeLast());
    }
    nodeStack.add(new old.Union(slots));
  }

  void visitField(FieldNode field) {
    old.Type type = convertType(field.type);
    nodeStack.add(new old.Formal(type, field.identifier.value));
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
}
