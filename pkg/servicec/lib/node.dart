// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.node;

// Highest-level node.
class CompilationUnitNode extends Node {
  List<Node> topLevelDeclarations;

  CompilationUnitNode(this.topLevelDeclarations);

  void accept(NodeVisitor visitor) {
    visitor.visitCompilationUnit(this);
  }
}

// Top-level nodes.
abstract class TopLevelDeclarationNode extends NamedNode {
  TopLevelDeclarationNode(IdentifierNode identifier)
    : super(identifier);
}

class ServiceNode extends TopLevelDeclarationNode {
  List<Node> functionDeclarations;

  ServiceNode(IdentifierNode identifier, this.functionDeclarations)
    : super(identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitService(this);
  }
}

class StructNode extends TopLevelDeclarationNode {
  List<Node> memberDeclarations;

  StructNode(IdentifierNode identifier, this.memberDeclarations)
    : super(identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitStruct(this);
  }
}

// Definition level nodes.
class FunctionDeclarationNode extends TypedNamedNode {
  List<Node> formalParameters;

  FunctionDeclarationNode(TypeNode type,
                          IdentifierNode identifier,
                          this.formalParameters)
    : super(type, identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitFunctionDeclaration(this);
  }
}

class FormalParameterNode extends TypedNamedNode {
  FormalParameterNode(TypeNode type, IdentifierNode identifier)
    : super(type, identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitFormalParameter(this);
  }
}

class MemberDeclarationNode extends TypedNamedNode {
  MemberDeclarationNode(TypeNode type, IdentifierNode identifier)
  : super(type, identifier);

  void accept(NodeVisitor visitor) {
    visitor.visitMemberDeclaration(this);
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
  void visitFunctionDeclaration(FunctionDeclarationNode functionDeclaration);
  void visitFormalParameter(FormalParameterNode formalParameter);
  void visitMemberDeclaration(MemberDeclarationNode memberDeclaration);
  void visitType(TypeNode type);
  void visitIdentifier(IdentifierNode identifier);
}

abstract class RecursiveVisitor extends NodeVisitor {
  void visitCompilationUnit(CompilationUnitNode compilationUnit) {
    for (TopLevelDeclarationNode topLevelDeclaration in
        compilationUnit.topLevelDeclarations) {
      topLevelDeclaration.accept(this);
    }
  }

  void visitService(ServiceNode service) {
    service.identifier.accept(this);
    for (FunctionDeclarationNode functionDeclaration in
        service.functionDeclarations) {
      functionDeclaration.accept(this);
    }
  }

  void visitStruct(StructNode struct) {
    struct.identifier.accept(this);
    for (MemberDeclarationNode memberDeclaration in
        struct.memberDeclarations) {
      memberDeclaration.accept(this);
    }
  }

  void visitFunctionDeclaration(FunctionDeclarationNode functionDeclaration) {
    functionDeclaration.type.accept(this);
    functionDeclaration.identifier.accept(this);
    for (FormalParameterNode formalParameter in
        functionDeclaration.formalParameters) {
      formalParameter.accept(this);
    }
  }

  void visitMemberDeclaration(MemberDeclarationNode memberDeclaration) {
    memberDeclaration.type.accept(this);
    memberDeclaration.identifier.accept(this);
  }

  void visitFormalParameter(FormalParameterNode formalParameter) {
    formalParameter.type.accept(this);
    formalParameter.identifier.accept(this);
  }

  void visitType(TypeNode type) {
    type.identifier.accept(this);
  }

  void visitIdentifier(IdentifierNode identifier) {
    // No-op.
  }
}
