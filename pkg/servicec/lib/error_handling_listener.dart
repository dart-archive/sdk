// Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.error_handling_listener;

import 'package:compiler/src/tokens/precedence_constants.dart' show
    CLOSE_CURLY_BRACKET_INFO,
    SEMICOLON_INFO,
    EOF_INFO;

import 'package:compiler/src/tokens/token.dart' show
    ErrorToken,
    UnmatchedToken,
    KeywordToken,
    Token;

import 'package:compiler/src/scanner/scanner.dart' show
    closeBraceInfoFor;

import 'errors.dart' show
    ErrorTag,
    ErrorNode,
    FormalErrorNode,
    FunctionErrorNode,
    InternalCompilerError,
    ListTypeError,
    FieldErrorNode,
    ServiceErrorNode,
    StructErrorNode,
    TopLevelErrorNode,
    UnionErrorNode;

import 'scanner.dart' show
    LF_INFO;

import 'keyword.dart' show
    Keyword;

import 'listener.dart' show
    Listener;

import 'marker.dart' show
    BeginFormalMarker,
    BeginFunctionMarker,
    BeginFieldMarker,
    BeginServiceMarker,
    BeginStructMarker,
    BeginTypeMarker,
    BeginUnionMarker,
    MarkerNode;

import 'node.dart' show
    CompilationUnitNode,
    FormalNode,
    FunctionNode,
    IdentifierNode,
    ListType,
    FieldNode,
    MemberNode,
    Node,
    PointerType,
    ServiceNode,
    SimpleType,
    StructNode,
    TopLevelNode,
    TypeNode,
    UnionNode;

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
  NodeStack stack;

  Popper<TopLevelNode> topLevelPopper;
  Popper<FunctionNode> functionPopper;
  Popper<FormalNode> formalPopper;
  Popper<FieldNode> fieldPopper;
  Popper<MemberNode> memberPopper;
  Popper<TypeNode> typePopper;
  Popper<IdentifierNode> identifierPopper;

  ErrorHandlingListener()
    : stack = new NodeStack(),
      super() {
    topLevelPopper = new Popper<TopLevelNode>(stack);
    functionPopper = new Popper<FunctionNode>(stack);
    formalPopper = new Popper<FormalNode>(stack);
    fieldPopper = new Popper<FieldNode>(stack);
    memberPopper = new Popper<MemberNode>(stack);
    typePopper = new Popper<TypeNode>(stack);
    identifierPopper = new Popper<IdentifierNode>(stack);
  }

  /// The [Node] representing the parsed IDL file.
  Node get parsedUnitNode {
    assert(stack.size == 1);
    assert(stack.topNode() is CompilationUnitNode);
    return stack.topNode();
  }

  // Top-level nodes.
  Token beginService(Token tokens) {
    stack.pushNode(new BeginServiceMarker(tokens));
    return tokens;
  }

  Token beginStruct(Token tokens) {
    stack.pushNode(new BeginStructMarker(tokens));
    return tokens;
  }

  Token beginFunction(Token tokens) {
    stack.pushNode(new BeginFunctionMarker(tokens));
    return tokens;
  }

  Token beginUnion(Token tokens) {
    stack.pushNode(new BeginUnionMarker(tokens));
    return tokens;
  }

  Token beginField(Token tokens) {
    stack.pushNode(new BeginFieldMarker(tokens));
    return tokens;
  }

  Token beginFormal(Token tokens) {
    stack.pushNode(new BeginFormalMarker(tokens));
    return tokens;
  }

  // Simplest concrete nodes.
  Token handleIdentifier(Token tokens) {
    if (tokens is ErrorToken) return tokens;

    stack.pushNode(new IdentifierNode(tokens));
    return tokens.next;
  }

  Token handleSimpleType(Token tokens) {
    if (tokens is ErrorToken) return tokens;

    IdentifierNode identifier = stack.popNode();
    stack.pushNode(new SimpleType(identifier));
    return tokens;
  }

  Token handlePointerType(Token tokens) {
    if (tokens is ErrorToken) return tokens;

    TypeNode pointee = stack.popNode();
    stack.pushNode(new PointerType(pointee));
    return tokens;
  }

  Token handleListType(Token tokens) {
    if (tokens is ErrorToken) return recoverListType(tokens);

    TypeNode typeParameter = stack.popNode();
    IdentifierNode identifier = stack.popNode();
    stack.pushNode(new ListType(identifier, typeParameter));
    return tokens;
  }

  Token beginType(Token tokens) {
    stack.pushNode(new BeginTypeMarker(tokens));
    return tokens;
  }

  Token endType(Token tokens) {
    if (tokens is ErrorToken) return recoverType(tokens);

    TypeNode type = stack.popNode();
    Node marker = stack.popNode();
    assert(marker is BeginTypeMarker);
    stack.pushNode(type);
    return tokens;
  }

  // Definition level nodes.
  Token endFormal(Token tokens) {
    if (tokens is ErrorToken) return recoverFormal(tokens);

    IdentifierNode identifier = stack.popNode();
    TypeNode type = stack.popNode();
    Node marker = stack.popNode();
    assert(marker is BeginFormalMarker);
    stack.pushNode(new FormalNode(type, identifier));
    return tokens;
  }

  Token endFunction(Token tokens, count) {
    if (tokens is ErrorToken) return recoverFunction(tokens);

    List<FormalNode> formals = formalPopper.popNodes(count);
    IdentifierNode identifier = stack.popNode();
    TypeNode type = stack.popNode();
    Node marker = stack.popNode();
    assert(marker is BeginFunctionMarker);
    stack.pushNode(new FunctionNode(type, identifier, formals));
    return tokens;
  }

  Token endField(Token tokens) {
    if (tokens is ErrorToken) return recoverField(tokens);

    IdentifierNode identifier = stack.popNode();
    TypeNode type = stack.popNode();
    Node marker = stack.popNode();
    assert(marker is BeginFieldMarker);
    stack.pushNode(new FieldNode(type, identifier));
    return tokens;
  }

  Token endUnion(Token tokens, int count) {
    if (tokens is ErrorToken) return recoverUnion(tokens);

    List<FieldNode> fields = fieldPopper.popNodes(count);
    Node marker = stack.popNode();
    assert(marker is BeginUnionMarker);
    stack.pushNode(new UnionNode(fields));
    return tokens;
  }

  // Top-level nodes.
  Token endService(Token tokens, int count) {
    if (tokens is ErrorToken) return recoverService(tokens);

    List<FunctionNode> functions = functionPopper.popNodes(count);
    IdentifierNode identifier = stack.popNode();
    MarkerNode marker = stack.popNode();
    assert(marker is BeginServiceMarker);
    stack.pushNode(new ServiceNode(identifier, functions));
    return tokens;
  }

  Token endStruct(Token tokens, int count) {
    if (tokens is ErrorToken) return recoverStruct(tokens);

    List<MemberNode> members = memberPopper.popNodes(count);
    IdentifierNode identifier = stack.popNode();
    MarkerNode marker = stack.popNode();
    assert(marker is BeginStructMarker);
    stack.pushNode(new StructNode(identifier, members));
    return tokens;
  }

  Token endTopLevel(Token tokens) {
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
  Token recoverListType(Token tokens) {
    TypeNode type = typePopper.popNodeIfMatching();
    IdentifierNode identifier = identifierPopper.popNodeIfMatching();
    if (identifier != null || type != null) {
      stack.pushNode(new ListTypeError(identifier, type, tokens));
    }
    return tokens;
  }

  Token recoverType(Token tokens) {
    // A ListType might have put a ListTypeError on the stack.
    TypeNode type = typePopper.popNodeIfMatching();
    MarkerNode marker = stack.popNode();
    assert(marker is BeginTypeMarker);
    if (type != null) stack.pushNode(type);

    return tokens;
  }

  Token recoverFormal(Token tokens) {
    IdentifierNode identifier = identifierPopper.popNodeIfMatching();
    TypeNode type = typePopper.popNodeIfMatching();
    MarkerNode marker = stack.popNode();
    assert(marker is BeginFormalMarker);
    if (identifier != null || type != null) {
      stack.pushNode(new FormalErrorNode(type, identifier, marker.token));
    }
    return tokens;
  }

  Token recoverFunction(Token tokens) {
    List<FormalNode> formals = formalPopper.popNodesWhileMatching();
    IdentifierNode identifier = identifierPopper.popNodeIfMatching();
    TypeNode type = typePopper.popNodeIfMatching();
    MarkerNode marker = stack.popNode();
    assert(marker is BeginFunctionMarker);
    if (formals.isNotEmpty || identifier != null || type != null) {
      stack.pushNode(
          new FunctionErrorNode(type, identifier, formals, marker.token));
      return consumeDeclarationLine(marker.token);
    } else {
      // Declaration was never started, so don't end it.
      return tokens;
    }
  }

  Token recoverField(Token tokens) {
    IdentifierNode identifier = identifierPopper.popNodeIfMatching();
    TypeNode type = typePopper.popNodeIfMatching();
    MarkerNode marker = stack.popNode();
    assert(marker is BeginFieldMarker);
    if (identifier != null || type != null) {
      stack.pushNode(new FieldErrorNode(type, identifier, marker.token));
      return consumeDeclarationLine(marker.token);
    } else {
      // Declaration was never started, so don't end it.
      return tokens;
    }
  }

  Token recoverUnion(Token tokens) {
    List<FieldNode> fields = fieldPopper.popNodesWhileMatching();
    MarkerNode marker = stack.popNode();
    assert(marker is BeginUnionMarker);
    stack.pushNode(new UnionErrorNode(fields, marker.token));
    return tokens;
  }

  Token recoverService(Token tokens) {
    List<FunctionNode> functions = functionPopper.popNodesWhileMatching();
    IdentifierNode identifier = identifierPopper.popNodeIfMatching();
    MarkerNode marker = stack.popNode();
    assert(marker is BeginServiceMarker);
    stack.pushNode(new ServiceErrorNode(identifier, functions, marker.token));
    return consumeTopLevel(tokens);
  }

  Token recoverStruct(Token tokens) {
    List<MemberNode> members = memberPopper.popNodesWhileMatching();
    IdentifierNode identifier = identifierPopper.popNodeIfMatching();
    MarkerNode marker = stack.popNode();
    assert(marker is BeginStructMarker);
    stack.pushNode(new StructErrorNode(identifier, members, marker.token));
    return consumeTopLevel(tokens);
  }

  Token recoverTopLevel(Token tokens) {
    stack.pushNode(new TopLevelErrorNode(tokens));
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
    return tokens.info == SEMICOLON_INFO || tokens.info == LF_INFO;
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
