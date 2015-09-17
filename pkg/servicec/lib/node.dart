// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.node;

import 'errors.dart' show
    ErrorNode,
    InternalCompilerError;

// Highest-level node.
class CompilationUnitNode extends Node {
  List<TopLevelNode> topLevels;

  CompilationUnitNode(this.topLevels);

  void accept(NodeVisitor visitor) {
    visitor.visitCompilationUnit(this);
  }
}

// Top-level nodes.
abstract class TopLevelNode extends NamedNode {
  TopLevelNode(IdentifierNode identifier)
    : super(identifier);
}

class ServiceNode extends TopLevelNode {
  List<FunctionNode> functions;

  ServiceNode(IdentifierNode identifier, this.functions)
    : super(identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitService(this);
  }
}

class StructNode extends TopLevelNode {
  List<MemberNode> members;

  StructNode(IdentifierNode identifier, this.members)
    : super(identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitStruct(this);
  }
}

// Definition level nodes.
class FunctionNode extends TypedNamedNode {
  List<FormalNode> formals;

  FunctionNode(TypeNode type, IdentifierNode identifier, this.formals)
    : super(type, identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitFunction(this);
  }
}

class FormalNode extends TypedNamedNode {
  FormalNode(TypeNode type, IdentifierNode identifier)
    : super(type, identifier);

  void accept(NodeVisitor visitor) {
    // TODO(stanm): add visitFormal in NodeVisitor
  }
}

class MemberNode extends TypedNamedNode {
  MemberNode(TypeNode type, IdentifierNode identifier)
  : super(type, identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitMember(this);
  }
}

// Simplest concrete nodes.
abstract class TypeNode extends NamedNode {
  TypeNode(IdentifierNode identifier)
    : super(identifier);
}

class SimpleType extends TypeNode {
  SimpleType(IdentifierNode identifier)
    : super(identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitSimpleType(this);
  }
}

class PointerType extends TypeNode {
  PointerType(IdentifierNode identifier)
    : super(identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitPointerType(this);
  }
}

class ListType extends TypeNode {
  TypeNode typeParameter;

  ListType(IdentifierNode identifier, this.typeParameter)
    : super(identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitListType(this);
    visitor.visitTypeParameter(typeParameter);
  }
}

class IdentifierNode extends Node {
  String value;

  IdentifierNode(this.value);

  int get hashCode => value.hashCode;
  bool operator ==(IdentifierNode other) => value == other.value;

  String toString() => "Identifier[$value]";

  void accept(NodeVisitor visitor) {
    visitor.visitIdentifier(this);
  }
}

// Marker nodes.
abstract class MarkerNode extends Node {
  void accept(NodeVisitor visitor) {
    throw new InternalCompilerError("MarkerNode visited");
  }
}

/// Marks a point on the stack where type parsing was started.
class BeginTypeMarker extends MarkerNode {
}

// Abstract nodes.
abstract class TypedNamedNode extends NamedNode {
  TypeNode type;

  TypedNamedNode(this.type, IdentifierNode identifier)
    : super(identifier);
}

abstract class NamedNode extends Node {
  IdentifierNode identifier;

  NamedNode(this.identifier);
}

abstract class Node {
  void accept(NodeVisitor visitor);
}

// Visitor class
abstract class NodeVisitor {
  void visitCompilationUnit(CompilationUnitNode compilationUnit);
  void visitService(ServiceNode service);
  void visitStruct(StructNode struct);
  void visitFunction(FunctionNode function);
  void visitMember(MemberNode member);

  // Structural/syntactic classification of types.
  void visitSimpleType(SimpleType type);
  void visitPointerType(PointerType type);
  void visitListType(ListType type);

  // Functional/semantic classification of types.
  void visitTypeParameter(TypeNode type);
  void visitReturnType(TypeNode type);
  void visitSingleFormal(FormalNode formal);
  void visitPrimitiveFormal(FormalNode formal);

  void visitIdentifier(IdentifierNode identifier);
}

abstract class RecursiveVisitor extends NodeVisitor {
  void visitCompilationUnit(CompilationUnitNode compilationUnit) {
    for (TopLevelNode topLevel in compilationUnit.topLevels) {
      topLevel.accept(this);
    }
  }

  void visitService(ServiceNode service) {
    service.identifier.accept(this);
    for (FunctionNode function in service.functions) {
      function.accept(this);
    }
  }

  void visitStruct(StructNode struct) {
    struct.identifier.accept(this);
    for (MemberNode member in struct.members) {
      member.accept(this);
    }
  }

  void visitFunction(FunctionNode function) {
    visitReturnType(function.type);

    // Ensure formal parameters are either a single pointer to a user-defined
    // type, or a list of primitives.
    int length = function.formals.length;
    function.identifier.accept(this);
    if (length == 1) {
      visitSingleFormal(function.formals[0]);
    } else if (length > 1) {
      for (FormalNode formal in function.formals) {
        visitPrimitiveFormal(formal);
      }
    }
  }

  void visitMember(MemberNode member) {
    member.type.accept(this);
    member.identifier.accept(this);
  }

  void visitReturnType(TypeNode type) {
    type.accept(this);
  }

  void visitSimpleType(SimpleType type) {
    // No op.
  }

  void visitPointerType(PointerType pointer) {
    // No op.
  }

  void visitListType(ListType list) {
    // No op.
  }

  void visitIdentifier(IdentifierNode identifier) {
    // No op.
  }
}
