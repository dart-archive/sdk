// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.node;

// Highest-level node.
class CompilationUnitNode extends Node {
  List<Node> topLevelDefinitions;

  CompilationUnitNode(this.topLevelDefinitions);
}

// Top-level nodes.
abstract class TopLevelDefinitionNode extends NamedNode {
  TopLevelDefinitionNode(IdentifierNode identifier)
    : super(identifier);
}

class ServiceNode extends TopLevelDefinitionNode {
  List<Node> functionDeclarations;

  ServiceNode(IdentifierNode identifier, this.functionDeclarations)
    : super(identifier);
}

class StructNode extends TopLevelDefinitionNode {
  List<Node> memberDeclarations;

  StructNode(IdentifierNode identifier, this.memberDeclarations)
    : super(identifier);
}

// Definition level nodes.
class FunctionDeclarationNode extends TypedNamedNode {
  List<Node> formalParameters;

  FunctionDeclarationNode(TypeNode type,
                          IdentifierNode identifier,
                          this.formalParameters)
    : super(type, identifier);
}

class FormalParameterNode extends TypedNamedNode {
  FormalParameterNode(TypeNode type, IdentifierNode identifier)
    : super(type, identifier);
}

class MemberDeclarationNode extends TypedNamedNode {
  MemberDeclarationNode(TypeNode type, IdentifierNode identifier)
  : super(type, identifier);
}

// Simplest concrete nodes.
class TypeNode extends NamedNode {
  TypeNode(IdentifierNode identifier)
    : super(identifier);
}

class IdentifierNode extends Node {
  String value;

  IdentifierNode(this.value);
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
}
