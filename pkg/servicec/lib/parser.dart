// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.parser;

import 'package:compiler/src/scanner/scannerlib.dart' show
    EOF_TOKEN,
    IDENTIFIER_TOKEN,
    Token;

import 'listener.dart' show
    Listener;

/// Parser for the Dart service IDL, reusing the dart2js tokens.
class Parser {
  Listener listener;
  Parser(this.listener);

  /// Entry point for the parser. The linked list [tokens] should be produced by
  /// the dart2js [Scanner].
  ///
  /// <unit> ::= <top-level-declaration>*
  Token parseUnit(Token tokens) {
    listener.beginCompilationUnit(tokens);
    int count = 0;
    while (!identical(tokens.kind, EOF_TOKEN)) {
      tokens = parseTopLevelDeclaration(tokens);
      ++count;
    }
    listener.endCompilationUnit(tokens, count);
    return tokens;
  }

  /// A top-level declaration is a service or a struct.
  /// 
  /// <top-level-declaration> ::= <service> | <struct>
  Token parseTopLevelDeclaration(Token tokens) {
    listener.beginTopLevelDeclaration(tokens);
    final String value = tokens.stringValue;
    if (identical(value, 'service')) {
      tokens = parseService(tokens);
    } else if (identical(value, 'struct')) {
      tokens = parseStruct(tokens);
    } else {
      listener.expectedTopLevelDeclaration(tokens);
      tokens = tokens.next;
    }
    listener.endTopLevelDeclaration(tokens);
    return tokens;
  }

  /// A service contains the keyword, an identifier, and a body. The body is
  /// enclosed in {} and contains zero or more function declarations.
  ///
  /// <service> ::= 'service' <identifier> '{' <func-decl>* '}'
  Token parseService(Token tokens) {
    listener.beginService(tokens);
    tokens = parseIdentifier(tokens.next);
    tokens = expect('{', tokens);
    int count = 0;
    while (!optional('}', tokens)) {
      tokens = parseFunctionDeclaration(tokens);
      ++count;
    }
    tokens = expect('}', tokens);
    listener.endService(tokens, count);
    return tokens;
  }

  /// A struct contains the keyword, an identifier, and a body. The body is
  /// enclosed in {} and contains zero or more member declarations.
  ///
  /// <struct> ::= 'struct' <identifier> '{' <member-decl>* '}'
  Token parseStruct(Token tokens) {
    listener.beginStruct(tokens);
    tokens = parseIdentifier(tokens.next);
    tokens = expect('{', tokens);
    int count = 0;
    while (!optional('}', tokens)) {
      tokens = parseMemberDeclaration(tokens);
      ++count;
    }
    tokens = expect('}', tokens);
    listener.endStruct(tokens, count);
    print("end struct");
    return tokens;
  }

  Token parseIdentifier(Token tokens) {
    if (!tokens.isIdentifier()) {
      listener.expectedIdentifier(tokens);
    }
    listener.handleIdentifier(tokens);
    return tokens.next;
  }

  /// A function declaration contains a type, an identifier, formal parameters,
  /// and a semicolon.
  ///
  /// <func-decl> ::= <type> <identifier> <formal-params> ';'
  Token parseFunctionDeclaration(Token tokens) {
    listener.beginFunctionDeclaration(tokens);

    tokens = parseType(tokens);

    listener.beginFunctionName(tokens);
    tokens = parseIdentifier(tokens);
    listener.endFunctionName(tokens);

    tokens = parseFormalParameters(tokens);

    tokens = expect(';', tokens);

    listener.endFunctionDeclaration(tokens);
    return tokens;
  }

  /// A member contains a type, an identifier, and a semicolon.
  ///
  /// <member-decl> ::= <type> <identifier> ';'
  Token parseMemberDeclaration(Token tokens) {
    listener.beginMember(tokens);

    tokens = parseType(tokens);

    listener.beginMemberName(tokens);
    tokens = parseIdentifier(tokens);
    listener.endMemberName(tokens);

    tokens = expect(';', tokens);

    listener.endMember(tokens);
    return tokens;
  }

  Token parseType(Token tokens) {
    listener.beginType(tokens);
    if (isValidTypeReference(tokens)) {
      tokens = parseIdentifier(tokens);
    } else {
      listener.expectedType(tokens);
    }
    listener.endType(tokens);
    return tokens;
  }

  /// Formal parameters contain an open parenthesis, zero or more parameter
  /// declarations separated by commas, and a closing parenthesis.
  ///
  /// <formal-params> ::= '(' (<formal-param> (',' <formal-param>)*)? ')'
  Token parseFormalParameters(Token tokens) {
    listener.beginFormalParameters(tokens);

    tokens = expect('(', tokens);

    int count = 0;
    if (!optional(')', tokens)) {
      tokens = parseFormalParameter(tokens);
      while (optional(',', tokens)) {
        tokens = tokens.next;
        tokens = parseFormalParameter(tokens);
      }
    }

    tokens = expect(')', tokens);

    listener.endFormalParameters(tokens);
    return tokens;
  }

  /// A parameter contains a type and an identifier.
  ///
  /// <param> ::= <type> <identifier>
  Token parseFormalParameter(Token tokens) {
    listener.beginFormalParameter(tokens);

    tokens = parseType(tokens);

    tokens = parseIdentifier(tokens);

    listener.endFormalParameter(tokens);
  }

  bool isValidTypeReference(Token tokens) {
    return identical(tokens.kind, IDENTIFIER_TOKEN);
  }

  /// Returns true if the [tokens] is a SymbolToken or a KeywordToken with
  /// stringValue [value].
  bool optional(String string, Token tokens) {
    return identical(string, tokens.stringValue);
  }

  /// Checks that the [tokens] is a SymbolToken or a KeywordToken with
  /// stringValue [value].
  Token expect(String string, Token tokens) {
    if (!identical(string, tokens.stringValue)) {
      listener.expected(string, tokens);
    }
    return tokens.next;
  }
}
