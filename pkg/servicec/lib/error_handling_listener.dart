// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.error_handling_listener;

import 'package:compiler/src/scanner/scannerlib.dart' show
    CLOSE_CURLY_BRACKET_INFO,
    EOF_INFO,
    ErrorToken,
    KeywordToken,
    SEMICOLON_INFO,
    Token,
    UnmatchedToken,
    closeBraceInfoFor;

import 'errors.dart' show
    CompilerError,
    ErrorNode,
    FunctionDeclarationErrorNode,
    MemberDeclarationErrorNode,
    ServiceErrorNode,
    StructErrorNode,
    TopLevelDeclarationErrorNode;

import 'keyword.dart' show
    Keyword;

import 'listener.dart' show
    Listener;

import 'node.dart' show
    CompilationUnitNode,
    FormalParameterNode,
    FunctionDeclarationNode,
    IdentifierNode,
    MemberDeclarationNode,
    NamedNode,
    Node,
    NodeStack,
    ServiceNode,
    StructNode,
    TopLevelDeclarationNode,
    TypeNode,
    TypedNamedNode;

/// Signifies that the parser reached a point of error recovery. Use this token
/// if resetting the state to a normal one requires multiple steps.
class RecoverToken extends ErrorToken {
  RecoverToken(Token token)
      : super(token.charOffset);

  String get assertionMessage => 'Recovering from an error.';
}

class UnknownKeywordErrorToken extends ErrorToken {
  final String keyword;

  UnknownKeywordErrorToken(Token token)
      : keyword = token.value,
        super(token.charOffset);

  String toString() => "UnknownKeywordErrorToken($keyword)";

  String get assertionMessage => '"$keyword" is not a keyword';
}

class UnexpectedToken extends ErrorToken {
  UnexpectedToken(Token token)
      : super(token.charOffset) {
    next = token;
  }

  String get assertionMessage => 'Unexpected token $next.';
}

class UnexpectedEOFToken extends UnexpectedToken {
  UnexpectedEOFToken(Token token)
      : super(token);

  String get assertionMessage => 'Unexpected end of file.';
}

class ErrorHandlingListener extends Listener {
  Token topLevelScopeStart;
  List<Node> nodeStack;
  List<ErrorNode> _errors;

  ErrorHandlingListener()
    : _errors = <ErrorNode>[],
      nodeStack = <Node>[],
      super();

  Iterable<CompilerError> get errors => _errors.map((e) => e.tag);

  /// The [Node] representing the parsed IDL file.
  Node get parsedUnitNode {
    assert(nodeStack.length == 1);
    assert(topNode() is CompilationUnitNode);
    return popNode();
  }

  // Stack interface.
  void pushNode(Node node) {
    nodeStack.add(node);
  }

  Node popNode() {
    return nodeStack.removeLast();
  }

  /// Returns the top of the stack or [null] if the stack is empty.
  Node topNode() {
    return nodeStack.isNotEmpty ? nodeStack.last : null;
  }

  /// Pops an element of the stack if the top passes the [test].
  Node popNodeIf(bool test(Node node)) {
    return test(topNode()) ? popNode() : null;
  }

  /// Pops the top [count] elements from the stack. Maintains the order in which
  /// the nodes were pushed, rather than returning them in a FILO fashion.
  List<Node> popNodes(int count) {
    int newLength = nodeStack.length - count;
    List<Node> nodes = nodeStack.sublist(newLength);
    nodeStack.length = newLength;
    return nodes;
  }

  /// Pops elements from the stack until they stop passing the [test]. Nodes are
  /// returned in reverse order than the one in which they were pushed: FILO
  /// fashion.
  List<Node> popNodesWhile(bool test(Node node)) {
    List<Node> nodes = <Node>[];
    while (test(topNode())) {
      nodes.add(popNode());
    }
    return nodes;
  }

  // Top-level nodes.
  Token beginService(Token tokens) {
    topLevelScopeStart = tokens.next.next;
    return tokens;
  }

  Token beginStruct(Token tokens) {
    topLevelScopeStart = tokens.next.next;
    return tokens;
  }

  // Simplest concrete nodes.
  Token beginIdentifier(Token tokens) {
    pushNode(new IdentifierNode(tokens.stringValue));
    return tokens;
  }

  Token endType(Token tokens) {
    if (tokens is ErrorToken) return recoverType(tokens);

    IdentifierNode identifier = popNode();
    pushNode(new TypeNode(identifier));
    return tokens;
  }

  // Definition level nodes.
  Token endFormalParameter(Token tokens) {
    if (tokens is ErrorToken) return recoverFormalParameter(tokens);

    IdentifierNode identifier = popNode();
    TypeNode type = popNode();
    pushNode(new FormalParameterNode(type, identifier));
    return tokens;
  }

  Token endFunctionDeclaration(Token tokens, count) {
    if (tokens is ErrorToken) return recoverFunctionDeclaration(tokens);

    List<Node> formalParameters = popNodes(count);
    IdentifierNode identifier = popNode();
    TypeNode type = popNode();
    pushNode(new FunctionDeclarationNode(type, identifier, formalParameters));
    return tokens;
  }

  Token endMemberDeclaration(Token tokens) {
    if (tokens is ErrorToken) return recoverMemberDeclaration(tokens);

    IdentifierNode identifier = popNode();
    TypeNode type = popNode();
    pushNode(new MemberDeclarationNode(type, identifier));
    return tokens;
  }

  // Top-level nodes.
  Token endService(Token tokens, int count) {
    if (tokens is ErrorToken) return recoverService(tokens);

    List<Node> functionDeclarations = popNodes(count);
    IdentifierNode identifier = popNode();
    pushNode(new ServiceNode(identifier, functionDeclarations));
    return tokens;
  }

  Token endStruct(Token tokens, int count) {
    if (tokens is ErrorToken) return recoverStruct(tokens);

    List<Node> memberDeclarations = popNodes(count);
    IdentifierNode identifier = popNode();
    pushNode(new StructNode(identifier, memberDeclarations));
    return tokens;
  }

  Token endTopLevelDeclaration(Token tokens) {
    topLevelScopeStart = null;
    return (tokens is ErrorToken) ? recoverTopLevelDeclaration(tokens) : tokens;
  }

  // Highest-level node.
  Token endCompilationUnit(Token tokens, int count) {
    if (tokens is ErrorToken) return recoverCompilationUnit(tokens);

    List<Node> topLevelDeclarations = popNodes(count);
    pushNode(new CompilationUnitNode(topLevelDeclarations));
    return tokens;
  }

  // Error handling.
  Token expectedTopLevelDeclaration(Token tokens) {
    return injectErrorIfNecessary(tokens);
  }

  Token expectedIdentifier(Token tokens) {
    return injectErrorIfNecessary(tokens);
  }

  Token expectedType(Token tokens) {
    return injectErrorIfNecessary(tokens);
  }

  Token expected(String string, Token tokens) {
    return injectUnexpectedTokenIfNecessary(tokens);
  }

  // Recovery methods.
  Token recoverType(Token tokens) {
    popNodeIf((node) => node is IdentifierNode);
    return tokens;
  }

  Token recoverFormalParameter(Token tokens) {
    popNodeIf((node) => node is IdentifierNode);
    popNodeIf((node) => node is TypeNode);
    return tokens;
  }

  Token recoverFunctionDeclaration(Token tokens) {
    List<Node> formalParameters =
      popNodesWhile((node) => node is FormalParameterNode);
    Node identifier = popNodeIf((node) => node is IdentifierNode);
    Node type = popNodeIf((node) => node is TypeNode);
    if (formalParameters.isNotEmpty || identifier != null || type != null) {
      FunctionDeclarationErrorNode error =
        new FunctionDeclarationErrorNode(tokens);
      pushNode(error);
      _errors.add(error);
      return consumeDeclarationLine(tokens);
    } else {
      // Declaration was never started, so don't end it.
      return tokens;
    }
  }

  Token recoverMemberDeclaration(Token tokens) {
    Node identifier = popNodeIf((node) => node is IdentifierNode);
    Node type = popNodeIf((node) => node is TypeNode);
    if (identifier != null || type != null) {
      MemberDeclarationErrorNode error = new MemberDeclarationErrorNode(tokens);
      pushNode(error);
      _errors.add(error);
      return consumeDeclarationLine(tokens);
    } else {
      // Declaration was never started, so don't end it.
      return tokens;
    }
  }

  Token recoverService(Token tokens) {
    popNodesWhile((node) => node is FunctionDeclarationNode);
    popNodeIf((node) => node is IdentifierNode);
    ServiceErrorNode error = new ServiceErrorNode(tokens);
    pushNode(error);
    _errors.add(error);
    return consumeTopLevelDeclaration(tokens);
  }

  Token recoverStruct(Token tokens) {
    popNodesWhile((node) => node is MemberDeclarationNode);
    popNodeIf((node) => node is IdentifierNode);
    StructErrorNode error = new StructErrorNode(tokens);
    pushNode(error);
    _errors.add(error);
    return consumeTopLevelDeclaration(tokens);
  }

  Token recoverTopLevelDeclaration(Token tokens) {
    TopLevelDeclarationErrorNode error =
      new TopLevelDeclarationErrorNode(tokens);
    pushNode(error);
    _errors.add(error);
    return consumeTopLevelDeclaration(tokens);
  }

  Token recoverCompilationUnit(Token tokens) {
    popNodesWhile((node) => node is TopLevelDeclarationNode);
    return tokens;
  }

  Token consumeDeclarationLine(Token tokens) {
    do {
      tokens = tokens.next;
    } while (!isEndOfDeclarationLine(tokens) &&
             !isEndOfTopLevelDeclaration(tokens));
    return isEndOfDeclarationLine(tokens) ? tokens.next : tokens;
  }

  Token consumeTopLevelDeclaration(Token tokens) {
    do {
      tokens = tokens.next;
    } while (!isEndOfTopLevelDeclaration(tokens));
    return (tokens.info == CLOSE_CURLY_BRACKET_INFO) ? tokens.next : tokens;
  }

  bool isEndOfDeclarationLine(Token tokens) {
    // TODO(stanm): Newline?
    return tokens.info == SEMICOLON_INFO;
  }

  bool isEndOfTopLevelDeclaration(Token tokens) {
    return (tokens.info == CLOSE_CURLY_BRACKET_INFO ||
            tokens.info == EOF_INFO ||
            isTopLevelKeyword(tokens));
  }

  Token injectErrorIfNecessary(Token tokens) {
    return injectUnexpectedTokenIfNecessary(tokens);
  }

  Token injectUnexpectedTokenIfNecessary(Token tokens) {
    return (tokens is ErrorToken) ? tokens : new UnexpectedToken(tokens);
  }
}

bool braceMatches(String string, UnmatchedToken token) {
  return closeBraceInfoFor(token.begin).value == string;
}

bool isTopLevelKeyword(Token tokens) {
  if (tokens is! KeywordToken) return false;
  KeywordToken keywordToken = tokens;
  return keywordToken.keyword == Keyword.service ||
         keywordToken.keyword == Keyword.struct;
}
