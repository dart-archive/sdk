// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.listener;

import 'package:compiler/src/scanner/scannerlib.dart' show
    Token;

import 'errors.dart' show
    CompilerError;

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
