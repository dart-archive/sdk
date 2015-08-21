// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.listener;

import 'package:compiler/src/scanner/scannerlib.dart' show
    Token;

class Listener {
  beginCompilationUnit(Token token) {
    print("begin unit");
  }

  endCompilationUnit(Token token, int count) {
    print("end unit; count = $count");
  }

  beginTopLevelDeclaration(Token token) {
    print("begin top-level declaration");
  }

  endTopLevelDeclaration(Token token) {
    print("end top-level declaration");
  }

  beginService(Token token) {
    print("begin service");
  }

  endService(Token token, int count) {
    print("end service; count = $count");
  }

  beginStruct(Token token) {
    print("begin struct");
  }

  endStruct(Token token, int count) {
    print("end struct; count = $count");
  }

  handleIdentifier(Token token) {
    print("handle identifier");
  }

  beginFunctionDeclaration(Token token) {
    print("begin function declaration");
  }

  beginFunctionName(Token token) {
    print("begin function name");
  }

  endFunctionName(Token token) {
    print("end function name");
  }

  endFunctionDeclaration(Token token) {
    print("end function declaration");
  }

  beginMember(Token token) {
    print("begin member");
  }

  beginMemberName(Token token) {
    print("begin member name");
  }

  endMemberName(Token token) {
    print("end member name");
  }

  endMember(Token token) {
    print("end member");
  }

  beginType(Token token) {
    print("begin type");
  }

  endType(Token token) {
    print("end type");
  }

  beginFormalParameters(Token token) {
    print("begin formal parameters");
  }

  endFormalParameters(Token token) {
    print("end formal parameters");
  }

  beginFormalParameter(Token token) {
    print("begin formal parameter");
  }

  endFormalParameter(Token token) {
    print("end formal parameter");
  }

  expectedTopLevelDeclaration(Token token) {
      print("error: $token is not a top-level declaration");
  }

  expectedIdentifier(Token token) {
      print("error: $token is not an identifier");
  }

  expectedType(Token token) {
      print("error: $token is not a type");
  }

  expected(String string, Token token) {
      print("error: $token is not the symbol $string");
  }
}

