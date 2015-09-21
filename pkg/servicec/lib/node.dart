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
abstract class TopLevelNode extends Node {
  IdentifierNode identifier;

  TopLevelNode(this.identifier);
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
class FunctionNode extends Node {
  TypeNode returnType;
  IdentifierNode identifier;
  List<FormalNode> formals;

  FunctionNode(this.returnType, this.identifier, this.formals);

  void accept(NodeVisitor visitor) {
    visitor.visitFunction(this);
  }
}

class FormalNode extends Node {
  TypeNode type;
  IdentifierNode identifier;

  FormalNode(this.type, this.identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitFormal(this);
  }
}

class MemberNode extends Node {
  TypeNode type;
  IdentifierNode identifier;

  MemberNode(this.type, this.identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitMember(this);
  }
}

abstract class TypeNode extends Node {
  IdentifierNode identifier;

  TypeNode(this.identifier);
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
  void visitFormal(FormalNode formal);

  // Functional/semantic classification of types.
  void visitTypeParameter(TypeNode type);
  void visitReturnType(TypeNode type);
  void visitSingleFormal(FormalNode formal);
  void visitPrimitiveFormal(FormalNode formal);

  void visitIdentifier(IdentifierNode identifier);

  void visitError(ErrorNode error);
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
    visitReturnType(function.returnType);
    if (function.identifier != null) function.identifier.accept(this);
    for (FormalNode formal in function.formals) {
      formal.accept(this);
    }
  }

  void visitFormal(FormalNode formal) {
    if (formal.type != null) formal.type.accept(this);
    if (formal.identifier != null) formal.identifier.accept(this);
  }

  void visitMember(MemberNode member) {
    if (member.type != null) member.type.accept(this);
    if (member.identifier != null) member.identifier.accept(this);
  }

  void visitReturnType(TypeNode type) {
    if (type != null) type.accept(this);
  }

  void visitSingleFormal(FormalNode formal) {
    // No op.
  }

  void visitPrimitiveFormal(FormalNode formal) {
    // No op.
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

  void visitError(ErrorNode error) {
    // No op.
  }
}
