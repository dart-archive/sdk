// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.listener;

import 'package:compiler/src/scanner/scannerlib.dart' show
    EOF_TOKEN,
    ErrorToken,
    KEYWORD_TOKEN,
    KeywordToken,
    Token,
    UnmatchedToken,
    closeBraceInfoFor;

import 'errors.dart' show
    CompilerError;

import 'keyword.dart' show
    Keyword;

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

/// Identity listener: methods just propagate the argument.
class Listener {
  List<CompilerError> errors;

  Listener()
    : errors = <CompilerError>[];

  Token beginCompilationUnit(Token tokens) {
    return tokens;
  }

  Token endCompilationUnit(Token tokens, int count) {
    return tokens;
  }

  Token beginTopLevelDeclaration(Token tokens) {
    return tokens;
  }

  Token endTopLevelDeclaration(Token tokens) {
    return tokens;
  }

  Token beginService(Token tokens) {
    return tokens;
  }

  Token endService(Token tokens, int count) {
    return tokens;
  }

  Token beginStruct(Token tokens) {
    return tokens;
  }

  Token endStruct(Token tokens, int count) {
    return tokens;
  }

  Token beginIdentifier(Token tokens) {
    return tokens;
  }

  Token endIdentifier(Token tokens) {
    return tokens;
  }

  Token beginFunctionDeclaration(Token tokens) {
    return tokens;
  }

  Token endFunctionDeclaration(Token tokens) {
    return tokens;
  }

  Token beginMemberDeclaration(Token tokens) {
    return tokens;
  }

  Token endMemberDeclaration(Token tokens) {
    return tokens;
  }

  Token beginType(Token tokens) {
    return tokens;
  }

  Token endType(Token tokens) {
    return tokens;
  }

  Token beginFormalParameters(Token tokens) {
    return tokens;
  }

  Token endFormalParameters(Token tokens, int count) {
    return tokens;
  }

  Token beginFormalParameter(Token tokens) {
    return tokens;
  }

  Token endFormalParameter(Token tokens) {
    return tokens;
  }

  Token expectedTopLevelDeclaration(Token tokens) {
    errors.add(CompilerError.syntax);
    return tokens.next;
  }

  Token expectedIdentifier(Token tokens) {
    errors.add(CompilerError.syntax);
    return tokens.next;
  }

  Token expectedType(Token tokens) {
    errors.add(CompilerError.syntax);
    return tokens.next;
  }

  Token expected(String string, Token tokens) {
    errors.add(CompilerError.syntax);
    return tokens.next;
  }
}

class ErrorHandlingListener extends Listener {
  Token topLevelScopeStart;

  ErrorHandlingListener()
    : super();

  Token beginService(Token tokens) {
    topLevelScopeStart = tokens.next.next;
    return super.beginService(tokens);
  }

  Token endService(Token tokens) {
    topLevelScopeStart = null;
    return super.endService(tokens);
  }

  Token beginStruct(Token tokens) {
    topLevelScopeStart = tokens.next.next;
    return super.beginStruct(tokens);
  }

  Token endStruct(Token tokens) {
    topLevelScopeStart = null;
    return super.endStruct(tokens);
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
        errors.add(CompilerError.syntax);
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

/// Used for debugging other listeners.
class DebugListener implements Listener {
  Listener debugSubject;
  List<CompilerError> errors = null;
  DebugListener(this.debugSubject);

  Token beginCompilationUnit(Token tokens) {
    print("begin unit");
    return debugSubject.beginCompilationUnit(tokens);
  }

  Token endCompilationUnit(Token tokens, int count) {
    print("end unit; count = $count");
    return debugSubject.endCompilationUnit(tokens, count);
  }

  Token beginTopLevelDeclaration(Token tokens) {
    print("begin top-level declaration");
    return debugSubject.beginTopLevelDeclaration(tokens);
  }

  Token endTopLevelDeclaration(Token tokens) {
    print("end top-level declaration");
    return debugSubject.endTopLevelDeclaration(tokens);
  }

  Token beginService(Token tokens) {
    print("begin service");
    return debugSubject.beginService(tokens);
  }

  Token endService(Token tokens, int count) {
    print("end service; count = $count");
    return debugSubject.endService(tokens, count);
  }

  Token beginStruct(Token tokens) {
    print("begin struct");
    return debugSubject.beginStruct(tokens);
  }

  Token endStruct(Token tokens, int count) {
    print("end struct; count = $count");
    return debugSubject.endStruct(tokens, count);
  }

  Token beginIdentifier(Token tokens) {
    print("begin identifier");
    return debugSubject.beginIdentifier(tokens);
  }

  Token endIdentifier(Token tokens) {
    print("end identifier");
    return debugSubject.endIdentifier(tokens);
  }

  Token beginFunctionDeclaration(Token tokens) {
    print("begin function declaration");
    return debugSubject.beginFunctionDeclaration(tokens);
  }

  Token endFunctionDeclaration(Token tokens) {
    print("end function declaration");
    return debugSubject.endFunctionDeclaration(tokens);
  }

  Token beginMemberDeclaration(Token tokens) {
    print("begin member declaration");
    return debugSubject.beginMemberDeclaration(tokens);
  }

  Token endMemberDeclaration(Token tokens) {
    print("end member declaration");
    return debugSubject.endMemberDeclaration(tokens);
  }

  Token beginType(Token tokens) {
    print("begin type");
    return debugSubject.beginType(tokens);
  }

  Token endType(Token tokens) {
    print("end type");
    return debugSubject.endType(tokens);
  }

  Token beginFormalParameters(Token tokens) {
    print("begin formal parameters");
    return debugSubject.beginFormalParameters(tokens);
  }

  Token endFormalParameters(Token tokens, int count) {
    print("end formal parameters");
    return debugSubject.endFormalParameters(tokens, count);
  }

  Token beginFormalParameter(Token tokens) {
    print("begin formal parameter");
    return debugSubject.beginFormalParameter(tokens);
  }

  Token endFormalParameter(Token tokens) {
    print("end formal parameter");
    return debugSubject.endFormalParameter(tokens);
  }

  Token expectedTopLevelDeclaration(Token tokens) {
    print("error: $tokens is not a top-level declaration");
    return debugSubject.expectedTopLevelDeclaration(tokens);
  }

  Token expectedIdentifier(Token tokens) {
    print("error: $tokens is not an identifier");
    return debugSubject.expectedIdentifier(tokens);
  }

  Token expectedType(Token tokens) {
    print("error: $tokens is not a type");
    return debugSubject.expectedType(tokens);
  }

  Token expected(String string, Token tokens) {
    print("error: $tokens is not the symbol $string");
    return debugSubject.expected(string, tokens);
  }
}
