// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.error_handling_listener;

import 'package:compiler/src/scanner/scannerlib.dart' show
    EOF_TOKEN,
    ErrorToken,
    KeywordToken,
    Token,
    UnmatchedToken,
    closeBraceInfoFor;

import 'errors.dart' show
    CompilerError;

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
    TopLevelDefinitionNode,
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
  Token token;

  UnexpectedToken(Token token)
      : this.token = token,
        super(token.charOffset);

  String get assertionMessage => 'Unexpected token $token.';
}

class UnexpectedEOFToken extends UnexpectedToken {
  UnexpectedEOFToken(Token token)
      : super(token);

  String get assertionMessage => 'Unexpected end of file.';
}

class ErrorHandlingListener extends Listener {
  Token topLevelScopeStart;
  List<Node> nodeStack;

  ErrorHandlingListener()
    : nodeStack = <Node>[],
      super();

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
    if (tokens is ErrorToken) {
      // Clean the stack.
      popNodeIf((node) => node is IdentifierNode);
      tokens = endRecovery(tokens);
    } else {
      IdentifierNode identifier = popNode();
      pushNode(new TypeNode(identifier));
    }
    return tokens;
  }

  // Definition level nodes.
  Token endFormalParameter(Token tokens) {
    if (tokens is ErrorToken) {
      // Clean the stack.
      popNodeIf((node) => node is IdentifierNode);
      popNodeIf((node) => node is TypeNode);
      tokens = endRecovery(tokens);
    } else {
      IdentifierNode identifier = popNode();
      TypeNode type = popNode();
      pushNode(new FormalParameterNode(type, identifier));
    }
    return tokens;
  }

  Token endFunctionDeclaration(Token tokens, count) {
    if (tokens is ErrorToken) {
      // Clean the stack.
      popNodesWhile((node) => node is FormalParameterNode);
      popNodeIf((node) => node is IdentifierNode);
      popNodeIf((node) => node is TypeNode);
      tokens = endRecovery(tokens);
    } else {
      List<Node> formalParameters = popNodes(count);
      IdentifierNode identifier = popNode();
      TypeNode type = popNode();
      pushNode(
          new FunctionDeclarationNode(type, identifier, formalParameters));
    }
    return tokens;
  }

  Token endMemberDeclaration(Token tokens) {
    if (tokens is ErrorToken) {
      // Clean the stack.
      popNodeIf((node) => node is IdentifierNode);
      popNodeIf((node) => node is TypeNode);
      tokens = endRecovery(tokens);
    } else {
      IdentifierNode identifier = popNode();
      TypeNode type = popNode();
      pushNode(new MemberDeclarationNode(type, identifier));
    }
    return tokens;
  }

  // Top-level nodes.
  Token endService(Token tokens, int count) {
    if (tokens is ErrorToken) {
      // Clean the stack.
      popNodesWhile((node) => node is FunctionDeclarationNode);
      popNodeIf((node) => node is IdentifierNode);
      tokens = endRecovery(tokens);
    } else {
      List<Node> functionDeclarations = popNodes(count);
      IdentifierNode identifier = popNode();
      pushNode(new ServiceNode(identifier, functionDeclarations));
    }
    topLevelScopeStart = null;
    return tokens;
  }

  Token endStruct(Token tokens, int count) {
    if (tokens is ErrorToken) {
      // Clean the stack.
      popNodesWhile((node) => node is MemberDeclarationNode);
      popNodeIf((node) => node is IdentifierNode);
      tokens = endRecovery(tokens);
    } else {
      List<Node> memberDeclarations = popNodes(count);
      IdentifierNode identifier = popNode();
      pushNode(new StructNode(identifier, memberDeclarations));
    }
    topLevelScopeStart = null;
    return tokens;
  }

  // Highest-level node.
  Token endCompilationUnit(Token tokens, int count) {
    if (tokens is ErrorToken) {
      popNodesWhile((node) => node is TopLevelDefinitionNode);
      tokens = endRecovery(tokens);
    } else {
      List<Node> topLevelDefinitions = popNodes(count);
      pushNode(new CompilationUnitNode(topLevelDefinitions));
    }
    return tokens;
  }

  // Error handling.
  Token expectedTopLevelDeclaration(Token tokens) {
    errors.add(CompilerError.syntax);
    return injectToken(new UnknownKeywordErrorToken(tokens), tokens);
  }

  Token expectedIdentifier(Token tokens) {
    return injectErrorIfNecessary(tokens);
  }

  Token expectedType(Token tokens) {
    return injectErrorIfNecessary(tokens);
  }

  Token expected(String string, Token tokens) {
    if (tokens is UnmatchedToken && braceMatches(string, tokens)) {
      // The match of the unmatched token is found
      tokens = tokens.next;
      tokens = injectToken(new RecoverToken(tokens), tokens);
    } else if (tokens is UnexpectedToken && string == tokens.token.value) {
      // The previously unexpected token is expected now
      tokens = tokens.next.next;
      tokens = injectToken(new RecoverToken(tokens), tokens);
    } else {
      tokens = injectErrorIfNecessary(tokens);
    }
    return tokens;
  }

  /// Ends the recovery process, if one is in place.
  Token endRecovery(Token tokens) {
    if (tokens is RecoverToken) {
      tokens = tokens.next;
    }
    return tokens;
  }

  /// It is necessary when the token is not an ErrorToken.
  Token injectErrorIfNecessary(Token tokens) {
    if (tokens is ErrorToken) return tokens;
    tokens = injectUnmatchedTokenIfNecessary(tokens);
    tokens = injectUnexpectedEOFTokenIfNecessary(tokens);
    tokens = injectUnexpectedTokenIfNecessary(tokens);
    return tokens;
  }

  // It is necessary when the token is either 'service' or 'struct' but it is
  // unexpected.
  Token injectUnmatchedTokenIfNecessary(Token tokens) {
    if (isTopLevelKeyword(tokens)) {
      errors.add(CompilerError.syntax);
      tokens = injectToken(new UnmatchedToken(topLevelScopeStart), tokens);
    }
    return tokens;
  }

  Token injectUnexpectedEOFTokenIfNecessary(Token tokens) {
    if (tokens.kind == EOF_TOKEN) {
      errors.add(CompilerError.syntax);
      tokens = injectToken(new UnexpectedEOFToken(tokens), tokens);
    }
    return tokens;
  }

  Token injectUnexpectedTokenIfNecessary(Token tokens) {
    if (tokens is! ErrorToken) {
      errors.add(CompilerError.syntax);
      // This solves the problem if there is a missing token; however, we should
      // also solve the problem if there is an extra token, and the problem if
      // the token is just the wrong token. Maybe return a 3-tuple of options?:
      // (UnnecessaryToken, MistypedToken, MissingToken)
      tokens = injectToken(new UnexpectedToken(tokens), tokens);
    }
    return tokens;
  }

  Token injectToken(Token next, Token tokens) {
    next.next = tokens;
    return next;
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
