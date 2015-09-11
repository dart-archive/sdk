// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.validator;

import 'node.dart' show
    CompilationUnitNode,
    FormalParameterNode,
    FunctionDeclarationNode,
    IdentifierNode,
    MemberDeclarationNode,
    NamedNode,
    Node,
    RecursiveVisitor,
    ServiceNode,
    StructNode,
    TopLevelDeclarationNode,
    TypeNode;

import 'errors.dart' show
    CompilerError,
    ErrorNode,
    FunctionDeclarationErrorNode,
    StructErrorNode,
    ServiceErrorNode,
    TopLevelDeclarationErrorNode;

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

  void visitFunctionDeclaration(FunctionDeclarationNode functionDeclaration) {
    enterFunctionDeclarationScope(functionDeclaration);
    checkIsNotError(functionDeclaration);
    super.visitFunctionDeclaration(functionDeclaration);
    leaveFunctionDeclarationScope(functionDeclaration);
  }

  void visitMemberDeclaration(MemberDeclarationNode memberDeclaration) {
    checkIsNotError(memberDeclaration);
    super.visitMemberDeclaration(memberDeclaration);
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
    for (Node node in compilationUnit.topLevelDeclarations) {
      if (node is ServiceNode) {
        return;
      }
    }
    errors.add(CompilerError.undefinedService);
  }

  // Scope management.
  void enterCompilationUnitScope(CompilationUnitNode compilationUnit) {
    compilationUnit.topLevelDeclarations.forEach(addTopLevelDeclarationSymbol);
  }

  void enterServiceScope(ServiceNode service) {
    service.functionDeclarations.forEach(addPropertyDeclarationSymbol);
  }

  void enterStructScope(StructNode struct) {
    struct.memberDeclarations.forEach(addPropertyDeclarationSymbol);
  }

  void enterFunctionDeclarationScope(
      FunctionDeclarationNode functionDeclaration) {
    functionDeclaration.formalParameters.forEach(addFormalParameterSymbol);
  }


  void leaveCompilationUnitScope(CompilationUnitNode compilationUnit) {
    compilationUnit.topLevelDeclarations.forEach(
        removeTopLevelDeclarationSymbol);
  }

  void leaveServiceScope(ServiceNode service) {
    service.functionDeclarations.forEach(removePropertyDeclarationSymbol);
  }

  void leaveStructScope(StructNode struct) {
    struct.memberDeclarations.forEach(removePropertyDeclarationSymbol);
  }

  void leaveFunctionDeclarationScope(
      FunctionDeclarationNode functionDeclaration) {
    functionDeclaration.formalParameters.forEach(removeFormalParameterSymbol);
  }

  // Symbol table management.
  bool lookupStructSymbol(IdentifierNode identifier) {
    return environment.structs.contains(identifier);
  }

  void addTopLevelDeclarationSymbol(TopLevelDeclarationNode node) {
    if (node is ServiceNode) {
      addSymbol(environment.services, node);
    } else if (node is StructNode) {
      addSymbol(environment.structs, node);
    }
  }

  void addPropertyDeclarationSymbol(NamedNode node) {
    addSymbol(environment.properties, node);
  }

  void addFormalParameterSymbol(FormalParameterNode node) {
    addSymbol(environment.parameters, node);
  }

  void removeTopLevelDeclarationSymbol(TopLevelDeclarationNode node) {
    if (node is ServiceNode) {
      removeSymbol(environment.services, node);
    } else if (node is StructNode) {
      removeSymbol(environment.structs, node);
    }
  }

  void removePropertyDeclarationSymbol(NamedNode node) {
    removeSymbol(environment.properties, node);
  }

  void removeFormalParameterSymbol(FormalParameterNode node) {
    removeSymbol(environment.parameters, node);
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
  Set<IdentifierNode> parameters;

  Environment()
    : services = new Set<IdentifierNode>(),
      structs = new Set<IdentifierNode>(),
      properties = new Set<IdentifierNode>(),
      parameters = new Set<IdentifierNode>();
}

