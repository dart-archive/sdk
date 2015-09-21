// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.validator;

import 'node.dart' show
    CompilationUnitNode,
    FormalNode,
    FunctionNode,
    IdentifierNode,
    ListType,
    MemberNode,
    Node,
    PointerType,
    RecursiveVisitor,
    ServiceNode,
    SimpleType,
    StructNode,
    TopLevelNode,
    TypeNode;

import 'errors.dart' show
    CompilerError,
    ErrorNode,
    FunctionErrorNode,
    StructErrorNode,
    ServiceErrorNode,
    TopLevelErrorNode;

import 'types.dart' show
    isPrimitiveType,
    isStringType,
    isListType;

// Validation functions.
List<CompilerError> validate(CompilationUnitNode compilationUnit) {
  Validator validator = new Validator();
  validator.process(compilationUnit);
  return validator.errors;
}

/// Encapsulate the state variables. Use [visitCompilationUnit] as an entry
/// point.
class Validator extends RecursiveVisitor {
  List<CompilerError> errors;
  Environment environment;

  Validator()
    : errors = <CompilerError>[],
      environment = new Environment(),
      super();

  void process(CompilationUnitNode compilationUnit) {
    visitCompilationUnit(compilationUnit);
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
    super.visitStruct(struct);
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

  void visitReturnType(TypeNode type) {
    checkIsPointerOrPrimitive(type);
  }

  void visitSingleFormal(FormalNode formal) {
    checkIsNotError(formal);
    checkIsPointerOrPrimitive(formal.type);
  }

  void visitPrimitiveFormal(FormalNode formal) {
    checkIsNotError(formal);
    checkIsPrimitiveFormal(formal);
  }

  void visitMember(MemberNode member) {
    checkIsNotError(member);
    super.visitMember(member);
  }

  void visitSimpleType(SimpleType type) {
    checkIsSimpleType(type);
  }

  void visitPointerType(PointerType type) {
    checkIsPointerType(type);
  }

  void visitListType(ListType type) {
    checkIsNotError(type);
    checkIsListType(type);
  }

  void visitTypeParameter(TypeNode type) {
    if (!isInnerListType(type)) {
      errors.add(CompilerError.badTypeParameter);
    }
  }

  void visitError(ErrorNode error) {
    errors.add(error.tag);
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
      if (node is ServiceNode) {
        return;
      }
    }
    errors.add(CompilerError.undefinedService);
  }

  bool typeResolvesToStruct(TypeNode type) {
    return environment.structs.contains(type.identifier);
  }

  void checkIsPointerOrPrimitive(TypeNode type) {
    if (!isPointerOrPrimitive(type)) {
      errors.add(CompilerError.expectedPointerOrPrimitive);
    }
  }

  bool isPointerOrPrimitive(TypeNode type) {
    return
      type is PointerType && typeResolvesToStruct(type) ||
      isPrimitiveType(type);
  }

  void checkIsPrimitiveFormal(FormalNode formal) {
    if (!isPrimitiveType(formal.type)) {
      errors.add(CompilerError.expectedPrimitiveFormal);
    }
  }

  void checkIsSimpleType(SimpleType type) {
    if (!isSimpleType(type)) {
      errors.add(CompilerError.badSimpleType);
    }
  }

  bool isSimpleType(SimpleType type) {
    return (typeResolvesToStruct(type) ||
            isPrimitiveType(type) ||
            isStringType(type));
  }

  void checkIsPointerType(PointerType type) {
    if (!isPointerType(type)) {
      errors.add(CompilerError.badPointerType);
    }
  }

  bool isPointerType(PointerType type) {
    return typeResolvesToStruct(type);
  }

  void checkIsListType(ListType type) {
    if (!isListType(type)) {
      errors.add(CompilerError.badListType);
    }
  }

  bool isInnerListType(TypeNode type) {
    return isStructType(type) || isPrimitiveType(type) || isStringType(type);
  }

  bool isStructType(TypeNode type) {
    return type is SimpleType && typeResolvesToStruct(type);
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

  // Symbol table management.
  bool lookupStructSymbol(IdentifierNode identifier) {
    return environment.structs.contains(identifier);
  }

  void addTopLevelSymbol(TopLevelNode node) {
    if (node is ServiceNode) {
      addServiceSymbol(node);
    } else if (node is StructNode) {
      addStructSymbol(node);
    }
  }

  void addServiceSymbol(ServiceNode service) {
    addSymbol(environment.services, service.identifier);
  }

  void addStructSymbol(StructNode struct) {
    addSymbol(environment.structs, struct.identifier);
  }

  void addFunctionSymbol(FunctionNode function) {
    addSymbol(environment.properties, function.identifier);
  }

  void addMemberSymbol(MemberNode member) {
    addSymbol(environment.properties, member.identifier);
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
    removeSymbol(environment.structs, struct.identifier);
  }

  void removeFunctionSymbol(FunctionNode function) {
    removeSymbol(environment.properties, function.identifier);
  }

  void removeMemberSymbol(MemberNode member) {
    removeSymbol(environment.properties, member.identifier);
  }

  void removeFormalSymbol(FormalNode formal) {
    removeSymbol(environment.formals, formal.identifier);
  }

  void addSymbol(Set<IdentifierNode> symbols, IdentifierNode identifier) {
    if (symbols.contains(identifier)) {
      errors.add(CompilerError.multipleDefinition);
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
  Set<IdentifierNode> structs;
  Set<IdentifierNode> properties;
  Set<IdentifierNode> formals;

  Environment()
    : services = new Set<IdentifierNode>(),
      structs = new Set<IdentifierNode>(),
      properties = new Set<IdentifierNode>(),
      formals = new Set<IdentifierNode>();
}

