// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.validator;

import 'package:compiler/src/scanner/scannerlib.dart' show
    Token;

import 'node.dart' show
    CompilationUnitNode,
    FormalNode,
    FunctionNode,
    IdentifierNode,
    ListType,
    MemberNode,
    FieldNode,
    Node,
    PointerType,
    RecursiveVisitor,
    ServiceNode,
    StructNode,
    TopLevelNode,
    TypeNode,
    UnionNode;

import 'errors.dart' show
    BadFieldTypeError,
    BadListTypeError,
    BadPointerTypeError,
    BadReturnTypeError,
    BadSingleFormalError,
    BadTypeParameterError,
    CompilationError,
    CyclicStructError,
    ErrorNode,
    ErrorTag,
    MultipleDefinitionsError,
    MultipleUnionsError,
    NotPrimitiveFormalError,
    SyntaxError,
    ServiceStructNameClashError,
    UndefinedServiceError;

import 'dart:collection' show
    Queue;

import 'cycle_detection.dart' show
    StructGraph;

// Validation functions.
List<CompilationError> validate(CompilationUnitNode compilationUnit) {
  Validator validator = new Validator();
  validator.process(compilationUnit);
  return validator.errors;
}

class Validator extends RecursiveVisitor {
  List<CompilationError> errors;
  Environment environment;
  StructGraph structGraph;

  Validator()
    : errors = <CompilationError>[],
      environment = new Environment(),
      structGraph = new StructGraph(),
      super();

  void process(CompilationUnitNode compilationUnit) {
    visitCompilationUnit(compilationUnit);
    errors.addAll(structGraph.findCycles());
  }

  // Visit methods.
  void visitCompilationUnit(CompilationUnitNode compilationUnit) {
    enterCompilationUnitScope(compilationUnit);
    checkHasAtLeastOneService(compilationUnit);
    super.visitCompilationUnit(compilationUnit);
    leaveCompilationUnitScope(compilationUnit);
  }

  void visitService(ServiceNode service) {
    enterServiceScope(service);
    checkIsNotError(service);
    super.visitService(service);
    leaveServiceScope(service);
  }

  void visitStruct(StructNode struct) {
    enterStructScope(struct);
    checkIsNotError(struct);
    checkHasAtMostOneUnion(struct);
    super.visitStruct(struct);
    structGraph.add(struct);
    leaveStructScope(struct);
  }

  void visitFunction(FunctionNode function) {
    enterFunctionScope(function);
    checkIsNotError(function);

    visitReturnType(function.returnType);
    // Ensure formal parameters are either a single pointer to a user-defined
    // type, or a list of primitives.
    int length = function.formals.length;
    if (length == 1) {
      visitSingleFormal(function.formals[0]);
    } else if (length > 1) {
      for (FormalNode formal in function.formals) {
        visitPrimitiveFormal(formal);
      }
    }

    leaveFunctionScope(function);
  }

  void visitSingleFormal(FormalNode formal) {
    checkIsNotError(formal);
    visitType(formal.type);
    checkSingleFormal(formal.type);
  }

  void visitPrimitiveFormal(FormalNode formal) {
    checkIsNotError(formal);
    visitType(formal.type);
    checkIsPrimitiveFormal(formal);
  }

  void visitUnion(UnionNode union) {
    // TODO(stanm): checkIsNotError(union);
    super.visitUnion(union);
  }

  void visitField(FieldNode field) {
    checkIsNotError(field);
    visitType(field.type);  // resolve
    if (field.type.isPointer()) {
      checkPointeeTypeResolves(field.type);
    } else if (field.type.isList()) {
      ListType list = field.type;
      visitListType(list);
    } else {
      checkFieldSimpleType(field.type);
    }
  }

  void visitReturnType(TypeNode type) {
    visitType(type);
    checkReturnType(type);
  }

  void visitTypeParameter(TypeNode type) {
    visitType(type);
    checkTypeParameter(type);
  }

  void visitPointerType(PointerType type) {
    visitType(type);
    checkPointeeTypeResolves(type);
  }

  void visitListType(ListType type) {
    visitType(type);
    checkIsNotError(type);
    checkIsListType(type);
    super.visitListType(type);
  }

  void visitType(TypeNode type) {
    type.resolve(environment.structs);
  }

  void visitError(ErrorNode error) {
    errors.add(new SyntaxError(error));
  }

  // Checks.
  void checkIsNotError(Node node) {
    // Using var as a work-around for compiler warnings about ErrorNode not
    // being in the node hierarchy.
    var dummy = node;
    if (dummy is ErrorNode) {
      ErrorNode error = dummy;
      visitError(error);
    }
  }

  void checkHasAtLeastOneService(CompilationUnitNode compilationUnit) {
    for (Node node in compilationUnit.topLevels) {
      if (node is ServiceNode) return;
    }
    errors.add(new UndefinedServiceError());
  }

  void checkHasAtMostOneUnion(StructNode struct) {
    int count = 0;
    for (MemberNode member in struct.members) {
      if (member is UnionNode && ++count > 1) {
        errors.add(new MultipleUnionsError(struct));
        return;
      }
    }
  }

  void checkIsPointerOrPrimitive(TypeNode type, CompilationError error) {
    if (type.isPrimitive()) return;
    if (type.isPointer()) {
      checkPointeeTypeResolves(type);
    } else {
      errors.add(error);
    }
  }

  void checkSingleFormal(TypeNode type) {
    checkIsPointerOrPrimitive(type, new BadSingleFormalError(type));
  }

  void checkIsPrimitiveFormal(FormalNode formal) {
    if (!formal.type.isPrimitive()) {
      errors.add(new NotPrimitiveFormalError(formal));
    }
  }

  void checkPointeeTypeResolves(PointerType type) {
    if (!type.pointeeResolves()) {
      errors.add(new BadPointerTypeError(type));
    }
  }

  void checkIsListType(ListType type) {
    if (!type.isList()) {
      errors.add(new BadListTypeError(type));
    }
  }

  void checkReturnType(TypeNode type) {
    checkIsPointerOrPrimitive(type, new BadReturnTypeError(type));
  }

  void checkTypeParameter(TypeNode type) {
    if (!(type.isPrimitive() || type.isStruct())) {
      errors.add(new BadTypeParameterError(type));
    }
  }

  void checkFieldSimpleType(TypeNode type) {
    if (!(type.isPrimitive() || type.isString() || type.isStruct())) {
      errors.add(new BadFieldTypeError(type));
    }
  }

  // Scope management.
  void enterCompilationUnitScope(CompilationUnitNode compilationUnit) {
    compilationUnit.topLevels.forEach(addTopLevelSymbol);
  }

  void enterServiceScope(ServiceNode service) {
    service.functions.forEach(addFunctionSymbol);
  }

  void enterStructScope(StructNode struct) {
    struct.members.forEach(addMemberSymbol);
  }

  void enterFunctionScope(FunctionNode function) {
    function.formals.forEach(addFormalSymbol);
  }


  void leaveCompilationUnitScope(CompilationUnitNode compilationUnit) {
    compilationUnit.topLevels.forEach(removeTopLevelSymbol);
  }

  void leaveServiceScope(ServiceNode service) {
    service.functions.forEach(removeFunctionSymbol);
  }

  void leaveStructScope(StructNode struct) {
    struct.members.forEach(removeMemberSymbol);
  }

  void leaveFunctionScope(FunctionNode function) {
    function.formals.forEach(removeFormalSymbol);
  }

  void addTopLevelSymbol(TopLevelNode node) {
    if (node is ServiceNode) {
      addServiceSymbol(node);
    } else if (node is StructNode) {
      addStructSymbol(node);
    }
  }

  void addServiceSymbol(ServiceNode service) {
    checkIsNotNameClash(environment.structs.keys.toSet(), service.identifier);
    addSymbol(environment.services, service.identifier);
  }

  void addStructSymbol(StructNode struct) {
    checkIsNotNameClash(environment.services, struct.identifier);
    if (environment.structs.containsKey(struct.identifier)) {
      IdentifierNode original =
        environment.structs.keys.toSet().lookup(struct.identifier);
      errors.add(new MultipleDefinitionsError(original, struct.identifier));
    } else {
      environment.structs[struct.identifier] = struct;
    }
  }

  void addFunctionSymbol(FunctionNode function) {
    addSymbol(environment.properties, function.identifier);
  }

  void addMemberSymbol(MemberNode member) {
    if (member is UnionNode) {
      UnionNode union = member;
      union.fields.forEach(addFieldSymbol);
    } else {
      addFieldSymbol(member);
    }
  }

  void addFieldSymbol(FieldNode field) {
    addSymbol(environment.properties, field.identifier);
  }

  void addFormalSymbol(FormalNode formal) {
    addSymbol(environment.formals, formal.identifier);
  }

  void removeTopLevelSymbol(TopLevelNode node) {
    if (node is ServiceNode) {
      removeServiceSymbol(node);
    } else if (node is StructNode) {
      removeStructSymbol(node);
    }
  }

  void removeServiceSymbol(ServiceNode service) {
    removeSymbol(environment.services, service.identifier);
  }

  void removeStructSymbol(StructNode struct) {
    environment.structs.remove(struct.identifier);
  }

  void removeFunctionSymbol(FunctionNode function) {
    removeSymbol(environment.properties, function.identifier);
  }

  void removeMemberSymbol(MemberNode member) {
    if (member is UnionNode) {
      UnionNode union = member;
      union.fields.forEach(removeFieldSymbol);
    } else {
      removeFieldSymbol(member);
    }
  }

  void removeFieldSymbol(FieldNode field) {
    removeSymbol(environment.properties, field.identifier);
  }

  void removeFormalSymbol(FormalNode formal) {
    removeSymbol(environment.formals, formal.identifier);
  }

  void checkIsNotNameClash(Set<IdentifierNode> symbols,
                           IdentifierNode identifier) {
    IdentifierNode original = symbols.lookup(identifier);
    if (null != original) {
      errors.add(new ServiceStructNameClashError(original, identifier));
    }
  }

  void addSymbol(Set<IdentifierNode> symbols, IdentifierNode identifier) {
    IdentifierNode original = symbols.lookup(identifier);
    if (null != original) {
      errors.add(new MultipleDefinitionsError(original, identifier));
    } else {
      symbols.add(identifier);
    }
  }

  void removeSymbol(Set<IdentifierNode> symbols, IdentifierNode identifier) {
    symbols.remove(identifier);
  }
}

class Environment {
  Set<IdentifierNode> services;
  Map<IdentifierNode, StructNode> structs;
  Set<IdentifierNode> properties;
  Set<IdentifierNode> formals;

  Environment()
    : services = new Set<IdentifierNode>(),
      structs = new Map<IdentifierNode, StructNode>(),
      properties = new Set<IdentifierNode>(),
      formals = new Set<IdentifierNode>();
}


