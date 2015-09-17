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
    FunctionErrorNode,
    InternalCompilerError,
    MemberErrorNode,
    ServiceErrorNode,
    StructErrorNode,
    TopLevelErrorNode;

import 'keyword.dart' show
    Keyword;

import 'listener.dart' show
    Listener;

import 'node.dart' show
    BeginTypeMarker,
    CompilationUnitNode,
    FormalNode,
    FunctionNode,
    IdentifierNode,
    ListType,
    MemberNode,
    NamedNode,
    Node,
    NodeStack,
    PointerType,
    ServiceNode,
    SimpleType,
    StructNode,
    TopLevelNode,
    TypeNode,
    TypedNamedNode;

import 'stack.dart' show
    NodeStack,
    Popper;

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
  NodeStack stack;
  List<ErrorNode> _errors;

  Popper<TopLevelNode> topLevelPopper;
  Popper<FunctionNode> functionPopper;
  Popper<FormalNode> formalPopper;
  Popper<MemberNode> memberPopper;
  Popper<TypeNode> typePopper;
  Popper<IdentifierNode> identifierPopper;

  ErrorHandlingListener()
    : _errors = <ErrorNode>[],
      stack = new NodeStack(),
      super() {
    topLevelPopper = new Popper<TopLevelNode>(stack);
    functionPopper = new Popper<FunctionNode>(stack);
    formalPopper = new Popper<FormalNode>(stack);
    memberPopper = new Popper<MemberNode>(stack);
    typePopper = new Popper<TypeNode>(stack);
    identifierPopper = new Popper<IdentifierNode>(stack);
  }

  Iterable<CompilerError> get errors => _errors.map((e) => e.tag);

  /// The [Node] representing the parsed IDL file.
  Node get parsedUnitNode {
    assert(stack.size == 1);
    assert(stack.topNode() is CompilationUnitNode);
    return stack.popNode();
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
    if (tokens is ErrorToken) return tokens;

    stack.pushNode(new IdentifierNode(tokens.value));
    return tokens;
  }

  Token handleSimpleType(Token tokens) {
    if (tokens is ErrorToken) return tokens;

    IdentifierNode identifier = stack.popNode();
    stack.pushNode(new SimpleType(identifier));
    return tokens;
  }

  Token handlePointerType(Token tokens) {
    if (tokens is ErrorToken) return tokens;

    IdentifierNode identifier = stack.popNode();
    stack.pushNode(new PointerType(identifier));
    return tokens;
  }

  Token handleListType(Token tokens) {
    if (tokens is ErrorToken) return tokens;

    TypeNode typeParameter = stack.popNode();
    IdentifierNode identifier = stack.popNode();
    stack.pushNode(new ListType(identifier, typeParameter));
    return tokens;
  }

  Token beginType(Token tokens) {
    stack.pushNode(new BeginTypeMarker());
    return tokens;
  }

  Token endType(Token tokens) {
    if (tokens is ErrorToken) return recoverType(tokens);

    TypeNode type = stack.popNode();
    if (stack.popNode() is! BeginTypeMarker) {
      throw new InternalCompilerError("Missing BeginTypeMarker");
    }
    stack.pushNode(type);
    return tokens;
  }

  // Definition level nodes.
  Token endFormal(Token tokens) {
    if (tokens is ErrorToken) return recoverFormal(tokens);

    IdentifierNode identifier = stack.popNode();
    TypeNode type = stack.popNode();
    stack.pushNode(new FormalNode(type, identifier));
    return tokens;
  }

  Token endFunction(Token tokens, count) {
    if (tokens is ErrorToken) return recoverFunction(tokens);

    List<FormalNode> formals = formalPopper.popNodes(count);
    IdentifierNode identifier = stack.popNode();
    TypeNode type = stack.popNode();
    stack.pushNode(new FunctionNode(type, identifier, formals));
    return tokens;
  }

  Token endMember(Token tokens) {
    if (tokens is ErrorToken) return recoverMember(tokens);

    IdentifierNode identifier = stack.popNode();
    TypeNode type = stack.popNode();
    stack.pushNode(new MemberNode(type, identifier));
    return tokens;
  }

  // Top-level nodes.
  Token endService(Token tokens, int count) {
    if (tokens is ErrorToken) return recoverService(tokens);

    List<FunctionNode> functions = functionPopper.popNodes(count);
    IdentifierNode identifier = stack.popNode();
    stack.pushNode(new ServiceNode(identifier, functions));
    return tokens;
  }

  Token endStruct(Token tokens, int count) {
    if (tokens is ErrorToken) return recoverStruct(tokens);

    List<MemberNode> members = memberPopper.popNodes(count);
    IdentifierNode identifier = stack.popNode();
    stack.pushNode(new StructNode(identifier, members));
    return tokens;
  }

  Token endTopLevel(Token tokens) {
    topLevelScopeStart = null;
    return (tokens is ErrorToken) ? recoverTopLevel(tokens) : tokens;
  }

  // Highest-level node.
  Token endCompilationUnit(Token tokens, int count) {
    if (tokens is ErrorToken) return recoverCompilationUnit(tokens);

    List<TopLevelNode> topLevels = topLevelPopper.popNodes(count);
    stack.pushNode(new CompilationUnitNode(topLevels));
    return tokens;
  }

  // Error handling.
  Token expectedTopLevel(Token tokens) {
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
    // TODO(stanm): remove the clueless popping of nodes. In the next CL we have
    // a more controlled tear-down of a type and we will not need to call this.
    // It will simplify the implementation of popNodesWhile.
    stack.popNodesWhile((node) => node is! BeginTypeMarker, null);
    stack.popNode();  // Pop the marker too.
    return tokens;
  }

  Token recoverFormal(Token tokens) {
    identifierPopper.popNodeIfMatching();
    typePopper.popNodeIfMatching();
    return tokens;
  }

  Token recoverFunction(Token tokens) {
    List<FormalNode> formals = formalPopper.popNodesWhileMatching();
    IdentifierNode identifier = identifierPopper.popNodeIfMatching();
    TypeNode type = typePopper.popNodeIfMatching();
    if (formals.isNotEmpty || identifier != null || type != null) {
      FunctionErrorNode error = new FunctionErrorNode(tokens);
      stack.pushNode(error);
      _errors.add(error);
      return consumeDeclarationLine(tokens);
    } else {
      // Declaration was never started, so don't end it.
      return tokens;
    }
  }

  Token recoverMember(Token tokens) {
    IdentifierNode identifier = identifierPopper.popNodeIfMatching();
    TypeNode type = typePopper.popNodeIfMatching();
    if (identifier != null || type != null) {
      MemberErrorNode error = new MemberErrorNode(tokens);
      stack.pushNode(error);
      _errors.add(error);
      return consumeDeclarationLine(tokens);
    } else {
      // Declaration was never started, so don't end it.
      return tokens;
    }
  }

  Token recoverService(Token tokens) {
    functionPopper.popNodesWhileMatching();
    identifierPopper.popNodeIfMatching();
    ServiceErrorNode error = new ServiceErrorNode(tokens);
    stack.pushNode(error);
    _errors.add(error);
    return consumeTopLevel(tokens);
  }

  Token recoverStruct(Token tokens) {
    memberPopper.popNodesWhileMatching();
    identifierPopper.popNodeIfMatching();
    StructErrorNode error = new StructErrorNode(tokens);
    stack.pushNode(error);
    _errors.add(error);
    return consumeTopLevel(tokens);
  }

  Token recoverTopLevel(Token tokens) {
    TopLevelErrorNode error = new TopLevelErrorNode(tokens);
    stack.pushNode(error);
    _errors.add(error);
    return consumeTopLevel(tokens);
  }

  Token recoverCompilationUnit(Token tokens) {
    topLevelPopper.popNodesWhileMatching();
    return tokens;
  }

  Token consumeDeclarationLine(Token tokens) {
    do {
      tokens = tokens.next;
    } while (!isEndOfDeclarationLine(tokens) && !isEndOfTopLevel(tokens));
    return isEndOfDeclarationLine(tokens) ? tokens.next : tokens;
  }

  Token consumeTopLevel(Token tokens) {
    do {
      tokens = tokens.next;
    } while (!isEndOfTopLevel(tokens));
    return (tokens.info == CLOSE_CURLY_BRACKET_INFO) ? tokens.next : tokens;
  }

  bool isEndOfDeclarationLine(Token tokens) {
    // TODO(stanm): Newline?
    return tokens.info == SEMICOLON_INFO;
  }

  bool isEndOfTopLevel(Token tokens) {
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
