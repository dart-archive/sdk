// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.errors;

import 'node.dart' show
    FunctionDeclarationNode,
    MemberDeclarationNode,
    Node,
    ServiceNode,
    StructNode,
    TopLevelDeclarationNode;

import 'package:compiler/src/scanner/scannerlib.dart' show
    Token;

enum CompilerError {
  badFunctionDeclaration,
  badMemberDeclaration,
  badServiceDefinition,
  badStructDefinition,
  badTopLevelDeclaration,
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

class TopLevelDeclarationErrorNode extends TopLevelDeclarationNode
    with ErrorNode {
  TopLevelDeclarationErrorNode(Token begin)
    : super(null) {
    this.begin = begin;
    tag = CompilerError.badTopLevelDeclaration;
  }
}

class FunctionDeclarationErrorNode extends FunctionDeclarationNode
    with ErrorNode {
  FunctionDeclarationErrorNode(Token begin)
    : super(null, null, null) {
    this.begin = begin;
    tag = CompilerError.badFunctionDeclaration;
  }
}

class MemberDeclarationErrorNode extends MemberDeclarationNode with ErrorNode {
  MemberDeclarationErrorNode(Token begin)
    : super(null, null) {
    this.begin = begin;
    tag = CompilerError.badMemberDeclaration;
  }
}

class ErrorNode {
  Token begin;
  CompilerError tag;
}
