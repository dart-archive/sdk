// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.node;

// Highest-level node.
class CompilationUnitNode extends Node {
  List<Node> topLevels;

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
  List<Node> functions;

  ServiceNode(IdentifierNode identifier, this.functions)
    : super(identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitService(this);
  }
}

class StructNode extends TopLevelNode {
  List<Node> members;

  StructNode(IdentifierNode identifier, this.members)
    : super(identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitStruct(this);
  }
}

// Definition level nodes.
class FunctionNode extends TypedNamedNode {
  List<Node> formals;

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
    visitor.visitFormal(this);
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
class TypeNode extends NamedNode {
  TypeNode(IdentifierNode identifier)
    : super(identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitType(this);
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
  void visitFormal(FormalNode formal);
  void visitMember(MemberNode member);
  void visitType(TypeNode type);
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
    function.type.accept(this);
    function.identifier.accept(this);
    for (FormalNode formal in function.formals) {
      formal.accept(this);
    }
  }

  void visitMember(MemberNode member) {
    member.type.accept(this);
    member.identifier.accept(this);
  }

  void visitFormal(FormalNode formal) {
    formal.type.accept(this);
    formal.identifier.accept(this);
  }

  void visitType(TypeNode type) {
    type.identifier.accept(this);
  }

  void visitIdentifier(IdentifierNode identifier) {
    // No-op.
  }
}
