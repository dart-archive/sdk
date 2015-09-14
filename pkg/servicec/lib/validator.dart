// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.validator;

import 'node.dart' show
    CompilationUnitNode,
    FormalNode,
    FunctionNode,
    IdentifierNode,
    MemberNode,
    NamedNode,
    Node,
    RecursiveVisitor,
    ServiceNode,
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
    isPrimitiveType;

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
    super.visitFunction(function);
    leaveFunctionScope(function);
  }

  void visitMember(MemberNode member) {
    checkIsNotError(member);
    super.visitMember(member);
  }

  void visitType(TypeNode type) {
    checkTypeResolves(type);
  }

  // Checks.
  void checkIsNotError(Node node) {
    // Using var as a work-around for compiler warnings about ErrorNode not
    // being in the node hierarchy.
    var dummy = node;
    if (dummy is ErrorNode) {
      ErrorNode error = dummy;
      errors.add(error.tag);
    }
  }

  void checkTypeResolves(TypeNode type) {
    if (!isPrimitiveType(type) && !lookupStructSymbol(type.identifier)) {
      errors.add(CompilerError.unresolvedType);
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

  // Scope management.
  void enterCompilationUnitScope(CompilationUnitNode compilationUnit) {
    compilationUnit.topLevels.forEach(addTopLevelSymbol);
  }

  void enterServiceScope(ServiceNode service) {
    service.functions.forEach(addPropertySymbol);
  }

  void enterStructScope(StructNode struct) {
    struct.members.forEach(addPropertySymbol);
  }

  void enterFunctionScope(FunctionNode function) {
    function.formals.forEach(addFormalSymbol);
  }


  void leaveCompilationUnitScope(CompilationUnitNode compilationUnit) {
    compilationUnit.topLevels.forEach(removeTopLevelSymbol);
  }

  void leaveServiceScope(ServiceNode service) {
    service.functions.forEach(removePropertySymbol);
  }

  void leaveStructScope(StructNode struct) {
    struct.members.forEach(removePropertySymbol);
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
      addSymbol(environment.services, node);
    } else if (node is StructNode) {
      addSymbol(environment.structs, node);
    }
  }

  void addPropertySymbol(NamedNode node) {
    addSymbol(environment.properties, node);
  }

  void addFormalSymbol(FormalNode node) {
    addSymbol(environment.formals, node);
  }

  void removeTopLevelSymbol(TopLevelNode node) {
    if (node is ServiceNode) {
      removeSymbol(environment.services, node);
    } else if (node is StructNode) {
      removeSymbol(environment.structs, node);
    }
  }

  void removePropertySymbol(NamedNode node) {
    removeSymbol(environment.properties, node);
  }

  void removeFormalSymbol(FormalNode node) {
    removeSymbol(environment.formals, node);
  }

  void addSymbol(Set<IdentifierNode> symbols, NamedNode node) {
    if (symbols.contains(node.identifier)) {
      errors.add(CompilerError.multipleDefinition);
    } else {
      symbols.add(node.identifier);
    }
  }

  void removeSymbol(Set<IdentifierNode> symbols, NamedNode node) {
    symbols.remove(node.identifier);
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

