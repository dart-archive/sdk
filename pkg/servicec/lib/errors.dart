// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.errors;

import 'node.dart' show
    FunctionNode,
    MemberNode,
    Node,
    ServiceNode,
    StructNode,
    TopLevelNode,
    NodeVisitor;

import 'package:compiler/src/scanner/scannerlib.dart' show
    Token;

enum CompilerError {
  badFunction,
  badTypeParameter,
  badListType,
  badMember,
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
  ServiceErrorNode(Token begin)
    : super(null, null) {
    this.begin = begin;
    tag = CompilerError.badServiceDefinition;
  }
}

class StructErrorNode extends StructNode with ErrorNode {
  StructErrorNode(Token begin)
    : super(null, null) {
    this.begin = begin;
    tag = CompilerError.badStructDefinition;
  }
}

class TopLevelErrorNode extends TopLevelNode
    with ErrorNode {
  TopLevelErrorNode(Token begin)
    : super(null) {
    this.begin = begin;
    tag = CompilerError.badTopLevel;
  }

  void accept(NodeVisitor visitor) {
    throw new InternalCompilerError("TopLevelErrorNode visited");
  }
}

class FunctionErrorNode extends FunctionNode
    with ErrorNode {
  FunctionErrorNode(Token begin)
    : super(null, null, null) {
    this.begin = begin;
    tag = CompilerError.badFunction;
  }
}

class MemberErrorNode extends MemberNode with ErrorNode {
  MemberErrorNode(Token begin)
    : super(null, null) {
    this.begin = begin;
    tag = CompilerError.badMember;
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
