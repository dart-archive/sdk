// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.parser;

import 'package:compiler/src/scanner/scannerlib.dart' show
    EOF_TOKEN,
    IDENTIFIER_TOKEN,
    Token;

/// Parser for the Dart service IDL, reusing the dart2js tokens.
class Parser {
  /// Entry point for the parser. The linked list [tokens] should be produced by
  /// the dart2js [Scanner].
  ///
  /// <unit> ::= <top-level-declaration>*
  Token parseUnit(Token tokens) {
    print("begin unit");
    while (!identical(tokens.kind, EOF_TOKEN)) {
      tokens = parseTopLevelDeclaration(tokens);
    }
    print("end unit");
    return tokens;
  }

  /// A top-level declaration is a service or a struct.
  /// 
  /// <top-level-declaration> ::= <service> | <struct>
  Token parseTopLevelDeclaration(Token tokens) {
    print("begin top-level declaration");
    final String value = tokens.stringValue;
    if (identical(value, 'service')) {
      tokens = parseService(tokens);
    } else if (identical(value, 'struct')) {
      tokens = parseStruct(tokens);
    } else {
      print("error: $tokens is not a top-level declaration");
      tokens = tokens.next;
    }
    print("end top-level declaration");
    return tokens;
  }

  /// A service contains the keyword, an identifier, and a body. The body is
  /// enclosed in {} and contains zero or more function declarations.
  ///
  /// <service> ::= 'service' <identifier> '{' <func-decl>* '}'
  Token parseService(Token tokens) {
    print("begin service");
    tokens = parseIdentifier(tokens.next);
    tokens = expect('{', tokens);
    while (!optional('}', tokens)) {
      tokens = parseFunctionDeclaration(tokens);
    }
    tokens = expect('}', tokens);
    print("end service");
    return tokens;
  }

  /// A struct contains the keyword, an identifier, and a body. The body is
  /// enclosed in {} and contains zero or more member declarations.
  ///
  /// <struct> ::= 'struct' <identifier> '{' <member-decl>* '}'
  Token parseStruct(Token tokens) {
    print("begin struct");
    tokens = parseIdentifier(tokens.next);
    tokens = expect('{', tokens);
    while (!optional('}', tokens)) {
      tokens = parseMemberDeclaration(tokens);
    }
    tokens = expect('}', tokens);
    print("end struct");
    return tokens;
  }

  Token parseIdentifier(Token tokens) {
    if (!tokens.isIdentifier()) {
      print("error: $tokens is not an identifier");
    }
    print("handle identifier");
    return tokens.next;
  }

  /// A function declaration contains a type, an identifier, formal parameters,
  /// and a semicolon.
  ///
  /// <func-decl> ::= <type> <identifier> <formal-params> ';'
  Token parseFunctionDeclaration(Token tokens) {
    print("begin function declaration");
    tokens = parseType(tokens);
    print("begin function name");
    tokens = parseIdentifier(tokens);
    print("end function name");
    tokens = parseFormalParameters(tokens);
    tokens = expect(';', tokens);
    print("end function declaration");
    return tokens;
  }

  /// A member contains a type, an identifier, and a semicolon.
  ///
  /// <member-decl> ::= <type> <identifier> ';'
  Token parseMemberDeclaration(Token tokens) {
    print("begin member");
    tokens = parseType(tokens);
    print("begin member name");
    tokens = parseIdentifier(tokens);
    print("end member name");
    tokens = expect(';', tokens);
    print("end member");
    return tokens;
  }

  Token parseType(Token tokens) {
    print("begin type");
    if (isValidTypeReference(tokens)) {
      tokens = parseIdentifier(tokens);
    } else {
      print("error: $tokens is not a type");
    }
    print("end type");
    return tokens;
  }

  /// Formal parameters contain an open parenthesis, zero or more parameter
  /// declarations separated by commas, and a closing parenthesis.
  ///
  /// <formal-params> ::= '(' (<formal-param> (',' <formal-param>)*)? ')'
  Token parseFormalParameters(Token tokens) {
    print("begin formal parameters");
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
    print("end formal parameters");
    return tokens;
  }

  /// A parameter contains a type and an identifier.
  ///
  /// <param> ::= <type> <identifier>
  Token parseFormalParameter(Token tokens) {
    print("begin formal parameter");
    tokens = parseType(tokens);
    tokens = parseIdentifier(tokens);
    print("end formal parameter");
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
      print("error: $tokens is not the symbol $string");
    }
    return tokens.next;
  }
}
