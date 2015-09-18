// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.errors;

import 'node.dart' show
    IdentifierNode,
    FunctionNode,
    FormalNode,
    ListType,
    MemberNode,
    Node,
    ServiceNode,
    StructNode,
    TopLevelNode,
    TypeNode,
    NodeVisitor;

import 'package:compiler/src/scanner/scannerlib.dart' show
    Token;

enum CompilerError {
  badFunction,
  badTypeParameter,
  badListType,
  badMember,
  badFormal,
  badPointerType,
  badServiceDefinition,
  badSimpleType,
  badStructDefinition,
  badTopLevel,
  expectedPointerOrPrimitive,
  expectedPrimitiveFormal,
  multipleDefinition,
  undefinedService
}

// Error nodes.
class ServiceErrorNode extends ServiceNode with ErrorNode {
  ServiceErrorNode(IdentifierNode identifier,
                   List<FunctionNode> functions,
                   Token begin)
    : super(identifier, functions) {
    this.begin = begin;
    tag = CompilerError.badServiceDefinition;
  }
}

class StructErrorNode extends StructNode with ErrorNode {
  StructErrorNode(IdentifierNode identifier,
                  List<MemberNode> members,
                  Token begin)
    : super(identifier, members) {
    this.begin = begin;
    tag = CompilerError.badStructDefinition;
  }
}

class TopLevelErrorNode extends TopLevelNode with ErrorNode {
  TopLevelErrorNode(Token begin)
    : super(null) {
    this.begin = begin;
    tag = CompilerError.badTopLevel;
  }

  void accept(NodeVisitor visitor) {
    visitor.visitError(this);
  }
}

class FunctionErrorNode extends FunctionNode
    with ErrorNode {
  FunctionErrorNode(TypeNode type,
                    IdentifierNode identifier,
                    List<FormalNode> formals,
                    Token begin)
    : super(type, identifier, formals) {
    this.begin = begin;
    tag = CompilerError.badFunction;
  }
}

class MemberErrorNode extends MemberNode with ErrorNode {
  MemberErrorNode(TypeNode type, IdentifierNode identifier, Token begin)
    : super(type, identifier) {
    this.begin = begin;
    tag = CompilerError.badMember;
  }
}

class FormalErrorNode extends FormalNode with ErrorNode {
  FormalErrorNode(TypeNode type, IdentifierNode identifier, Token begin)
    : super(type, identifier) {
    this.begin = begin;
    tag = CompilerError.badFormal;
  }
}

class ListTypeError extends ListType with ErrorNode {
  ListTypeError(IdentifierNode identifier, TypeNode typeParameter, Token begin)
    : super(identifier, typeParameter) {
    this.begin = begin;
    tag = CompilerError.badListType;
  }
}

class ErrorNode {
  Token begin;
  CompilerError tag;
}

class InternalCompilerError extends Error {
  String message;
  InternalCompilerError(this.message);

  String toString() => "InternalCompilerError: $message";
}
