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

class UnknownKeywordErrorToken extends ErrorToken {
  final String keyword;

  UnknownKeywordErrorToken(Token token)
      : keyword = token.value,
        super(token.charOffset);

  String toString() => "UnknownKeywordErrorToken($keyword)";

  String get assertionMessage => '"$keyword" is not a keyword';
}

class UnexpectedEOFToken extends ErrorToken {
  UnexpectedEOFToken(Token token)
      : super(token.charOffset);

  String get assertionMessage => 'Unexpected end of file.';
}

class ErrorHandlingListener extends Listener {
  Token topLevelScopeStart;

  ErrorHandlingListener()
    : super();

  Token beginService(Token tokens) {
    topLevelScopeStart = tokens.next.next;
    return super.beginService(tokens);
  }

  Token endService(Token tokens, int count) {
    topLevelScopeStart = null;
    return super.endService(tokens, count);
  }

  Token beginStruct(Token tokens) {
    topLevelScopeStart = tokens.next.next;
    return super.beginStruct(tokens);
  }

  Token endStruct(Token tokens, int count) {
    topLevelScopeStart = null;
    return super.endStruct(tokens, count);
  }

  Token beginFunctionDeclaration(Token tokens) {
    return super.beginFunctionDeclaration(tokens);
  }

  Token beginMemberDeclaration(Token tokens) {
    return super.beginMemberDeclaration(tokens);
  }

  Token beginType(Token tokens) {
    return super.beginType(tokens);
  }

  Token beginFormalParameters(Token tokens) {
    return super.beginFormalParameters(tokens);
  }

  Token beginFormalParameter(Token tokens) {
    return super.beginFormalParameter(tokens);
  }

  Token expectedTopLevelDeclaration(Token tokens) {
    var token = new UnknownKeywordErrorToken(tokens);
    return injectToken(token, tokens);
  }

  Token expectedIdentifier(Token tokens) {
    return injectErrorIfNecessary(tokens);
  }

  Token expectedType(Token tokens) {
    return injectErrorIfNecessary(tokens);
  }

  /// It is necessary when the token is not an ErrorToken.
  Token injectErrorIfNecessary(Token tokens) {
    if (tokens is! ErrorToken) {
      tokens = injectUnmatchedTokenIfNecessary(tokens);
      tokens = injectUnexpectedEOFTokenIfNecessary(tokens);
      if (tokens is ErrorToken) {
        return tokens;
      }
      // Note: we can simplify this function plenty when we are sure we handle
      // all errors. TODO(stanm): make sure this is not reached and remove.
      print("Warning: an error token was not injected where it was necessary");
      return tokens.next;
    }
    return tokens;
  }

  Token expected(String string, Token tokens) {
    if (tokens is UnmatchedToken && matches(string, tokens)) {
      // Recover from an unmatched token when its match is expected.
      return tokens.next;
    } else {
      return injectErrorIfNecessary(tokens);
    }
  }

  Token injectUnexpectedEOFTokenIfNecessary(Token tokens) {
    if (tokens.kind == EOF_TOKEN) {
      tokens = injectToken(new UnexpectedEOFToken(tokens), tokens);
    }
    return tokens;
  }

  // It is necessary when the token is either 'service' or 'struct' but it is
  // unexpected.
  Token injectUnmatchedTokenIfNecessary(Token tokens) {
    if (isTopLevelKeyword(tokens)) {
      tokens = injectToken(new UnmatchedToken(topLevelScopeStart), tokens);
    }
    return tokens;
  }

  Token injectToken(Token next, Token tokens) {
    errors.add(CompilerError.syntax);
    next.next = tokens;
    return next;
  }
}

bool matches(String string, UnmatchedToken token) {
  return closeBraceInfoFor(token.begin).value == string;
}

bool isTopLevelKeyword(Token tokens) {
  if (tokens is! KeywordToken) return false;
  KeywordToken keywordToken = tokens;
  return keywordToken.keyword == Keyword.service ||
         keywordToken.keyword == Keyword.struct;
}
