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
    FieldNode,
    Node,
    PointerType,
    RecursiveVisitor,
    ServiceNode,
    SimpleType,
    StructNode,
    TopLevelNode,
    TypeNode,
    UnionNode;

import 'errors.dart' show
    CompilerError,
    ErrorNode,
    FunctionErrorNode,
    StructErrorNode,
    ServiceErrorNode,
    TopLevelErrorNode;

import 'dart:collection' show
    Queue;

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
  StructGraph structGraph;

  Validator()
    : errors = <CompilerError>[],
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
    checkIsPointerOrPrimitive(formal.type);
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
    super.visitField(field);
  }

  void visitReturnType(TypeNode type) {
    visitType(type);
    checkIsPointerOrPrimitive(type);
  }

  void visitTypeParameter(TypeNode type) {
    visitType(type);
    checkTypeParameter(type);
  }

  void visitSimpleType(SimpleType type) {
    visitType(type);
    checkIsSimpleType(type);
  }

  void visitPointerType(PointerType type) {
    visitType(type);
    checkIsPointerType(type);
  }

  void visitListType(ListType type) {
    visitType(type);
    checkIsNotError(type);
    checkIsListType(type);
  }

  void visitType(TypeNode type) {
    type.resolve(environment.structs);
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

  void checkHasAtMostOneUnion(StructNode struct) {
    int count = 0;
    for (MemberNode member in struct.members) {
      if (member is UnionNode && ++count > 1) {
        errors.add(CompilerError.multipleUnions);
        return;
      }
    }
  }

  void checkIsPointerOrPrimitive(TypeNode type) {
    if (!(type.isPointer() || type.isPrimitive())) {
      errors.add(CompilerError.expectedPointerOrPrimitive);
    }
  }

  void checkIsPrimitiveFormal(FormalNode formal) {
    if (!formal.type.isPrimitive()) {
      errors.add(CompilerError.expectedPrimitiveFormal);
    }
  }

  void checkIsSimpleType(SimpleType type) {
    if (!(type.isPrimitive() || type.isString() || type.isStruct())) {
      errors.add(CompilerError.badSimpleType);
    }
  }

  void checkIsPointerType(PointerType type) {
    if (!type.isPointer()) {
      errors.add(CompilerError.badPointerType);
    }
  }

  void checkIsListType(ListType type) {
    if (!type.isList()) {
      errors.add(CompilerError.badListType);
    }
  }

  void checkTypeParameter(TypeNode type) {
    if (!(type.isPrimitive() || type.isString() || type.isStruct())) {
      errors.add(CompilerError.badTypeParameter);
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
    environment.structs[struct.identifier] = struct;
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

  void addSymbol(Set<IdentifierNode> symbols, IdentifierNode identifier) {
    if (symbols.contains(identifier)) {
      errors.add(CompilerError.multipleDefinitions);
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

class _GraphNode {
  _GraphNodeState state = _GraphNodeState.UNVISITED;
  StructNode struct;

  _GraphNode(this.struct);

  bool get isNotVisited => _GraphNodeState.UNVISITED == state;

  bool operator ==(_GraphNode other) {
    return struct == other.struct;
  }
  int get hashCode => struct.hashCode;

  String toString() => "Node[${struct.identifier.value}, ${state.toString()}]";
}

enum _GraphNodeState {
  VISITED,
  VISITING,
  UNVISITED
}

class StructGraph {
  Set<_GraphNode> nodes;
  Map<_GraphNode, Set<_GraphNode>> neighbours;

  StructGraph()
    : nodes = new Set<_GraphNode>(),
      neighbours = new Map<_GraphNode, Set<_GraphNode>>();

  void add(StructNode struct) {
    for (MemberNode member in struct.members) {
      if (member is FieldNode) {
        addStructField(struct, member);
      } else {
        UnionNode union = member;
        union.fields.forEach((field) => addStructField(struct, field));
      }
    }
  }

  // Helper function.
  void addStructField(StructNode struct, FieldNode field) {
    TypeNode type = field.type;
    if (type != null && type.isStruct()) {
      SimpleType simpleType = type;
      addLink(struct, simpleType.resolved);
    }
  }

  void addLink(StructNode from, StructNode to) {
    _GraphNode fromNode = addNodeIfNew(from);
    _GraphNode toNode = addNodeIfNew(to);
    neighbours[fromNode].add(toNode);
  }

  _GraphNode addNodeIfNew(StructNode node) {
    _GraphNode result = nodes.firstWhere(
        (graphNode) => graphNode.struct == node,
        orElse: () => null);
    if (null == result) {
      result = new _GraphNode(node);
      nodes.add(result);
      neighbours[result] = new Set<_GraphNode>();
    }
    return result;
  }

  // 1) 0 -> 0 is a trivial cycle
  // 2) 0 -> 1 -> 0 is (probably) the most common cycle in real code
  // 3) 0 -> 1 -> 2 -> 1 is a cycle reachable from 0, but not containing 0
  // 4) 0 -> 1 -> 0 + 1 -> 2 -> 1 are two cycles reachable from 0
  // 5) 0 -> 1 -> 0 + 1 -> 2 -> 0 are two cycles reachable from 0
  // 6) 0 -> 1 -> 2 + 0 -> 2 is a DAG and not a cycle
  List<CompilerError> findCycles() {
    List<CompilerError> errors = <CompilerError>[];
    List<_GraphNode> stack = new List<_GraphNode>();
    stack.addAll(nodes);
    while (stack.isNotEmpty) {
      _GraphNode node = stack.last;
      switch (node.state) {
        case _GraphNodeState.UNVISITED:
          node.state = _GraphNodeState.VISITING;
          for (_GraphNode neighbour in neighbours[node]) {
            switch (neighbour.state) {
              case _GraphNodeState.UNVISITED:
                // The `neighbour` hasn't been seen yet - add to stack.
                stack.add(neighbour);
                break;
              case _GraphNodeState.VISITING:
                // The `neighbour` is in the current route from the root to the
                // `node` - there is a cycle.
                errors.add(CompilerError.cyclicStruct);
                break;
              case _GraphNodeState.VISITED:
                // The `neighbour` has already been searched - ignore.
                break;
            }
          }
          break;
        case _GraphNodeState.VISITING:
          node.state = _GraphNodeState.VISITED;
          stack.removeLast();
          break;
        case _GraphNodeState.VISITED:
          // In this case the graph is a DAG.
          stack.removeLast();
          break;
      }
    }
    return errors;
  }
}

