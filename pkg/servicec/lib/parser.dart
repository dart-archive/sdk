// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.parser;

import 'package:compiler/src/scanner/scannerlib.dart' show
    EOF_TOKEN,
    ErrorToken,
    IDENTIFIER_TOKEN,
    KEYWORD_TOKEN,
    Keyword,
    KeywordToken,
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
    tokens = listener.beginCompilationUnit(tokens);
    int count = 0;
    while (valid(tokens)) {
      tokens = parseTopLevelDeclaration(tokens);
      ++count;
    }
    tokens = listener.endCompilationUnit(tokens, count);
    return tokens;
  }

  /// A top-level declaration is a service or a struct.
  ///
  /// <top-level-declaration> ::= <service> | <struct>
  Token parseTopLevelDeclaration(Token tokens) {
    tokens = listener.beginTopLevelDeclaration(tokens);
    final String value = tokens.stringValue;
    if (identical(value, 'service')) {
      tokens = parseService(tokens);
    } else if (identical(value, 'struct')) {
      tokens = parseStruct(tokens);
    } else {
      tokens = listener.expectedTopLevelDeclaration(tokens);
    }
    tokens = listener.endTopLevelDeclaration(tokens);
    return tokens;
  }

  /// A service contains the keyword, an identifier, and a body. The body is
  /// enclosed in {} and contains zero or more function declarations.
  ///
  /// <service> ::= 'service' <identifier> '{' <func-decl>* '}'
  Token parseService(Token tokens) {
    tokens = listener.beginService(tokens);
    tokens = parseIdentifier(tokens.next);
    tokens = expect('{', tokens);
    int count = 0;
    if (valid(tokens)) {
      while (!optional('}', tokens)) {
        tokens = parseFunctionDeclaration(tokens);
        if (!valid(tokens)) break;  // Don't count unsuccessful declarations
        ++count;
      }
    }
    tokens = expect('}', tokens);
    tokens = listener.endService(tokens, count);
    return tokens;
  }

  /// A struct contains the keyword, an identifier, and a body. The body is
  /// enclosed in {} and contains zero or more member declarations.
  ///
  /// <struct> ::= 'struct' <identifier> '{' <member-decl>* '}'
  Token parseStruct(Token tokens) {
    tokens = listener.beginStruct(tokens);
    tokens = parseIdentifier(tokens.next);
    tokens = expect('{', tokens);
    int count = 0;
    if (valid(tokens)) {
      while (!optional('}', tokens)) {
        tokens = parseMemberDeclaration(tokens);
        if (!valid(tokens)) break;  // Don't count unsuccessful declarations
        ++count;
      }
    }
    tokens = expect('}', tokens);
    tokens = listener.endStruct(tokens, count);
    return tokens;
  }

  Token parseIdentifier(Token tokens) {
    tokens = listener.beginIdentifier(tokens);
    if (isValidIdentifier(tokens)) {
      tokens = tokens.next;
    } else {
      tokens = listener.expectedIdentifier(tokens);
    }
    tokens = listener.endIdentifier(tokens);
    return tokens;
  }

  /// A function declaration contains a type, an identifier, formal parameters,
  /// and a semicolon.
  ///
  /// <func-decl> ::= <type> <identifier> <formal-params> ';'
  Token parseFunctionDeclaration(Token tokens) {
    tokens = listener.beginFunctionDeclaration(tokens);
    tokens = parseType(tokens);
    tokens = parseIdentifier(tokens);
    tokens = parseFormalParameters(tokens);
    tokens = expect(';', tokens);
    tokens = listener.endFunctionDeclaration(tokens);
    return tokens;
  }

  /// A member contains a type, an identifier, and a semicolon.
  ///
  /// <member-decl> ::= <type> <identifier> ';'
  Token parseMemberDeclaration(Token tokens) {
    tokens = listener.beginMemberDeclaration(tokens);
    tokens = parseType(tokens);
    tokens = parseIdentifier(tokens);
    tokens = expect(';', tokens);
    tokens = listener.endMemberDeclaration(tokens);
    return tokens;
  }

  Token parseType(Token tokens) {
    tokens = listener.beginType(tokens);
    if (isValidTypeReference(tokens)) {
      tokens = parseIdentifier(tokens);
    } else {
      tokens = listener.expectedType(tokens);
    }
    tokens = listener.endType(tokens);
    return tokens;
  }

  /// Formal parameters contain an open parenthesis, zero or more parameter
  /// declarations separated by commas, and a closing parenthesis.
  ///
  /// <formal-params> ::= '(' (<formal-param> (',' <formal-param>)*)? ')'
  Token parseFormalParameters(Token tokens) {
    tokens = listener.beginFormalParameters(tokens);
    tokens = expect('(', tokens);
    int count = 0;
    if (!optional(')', tokens)) {
      tokens = parseFormalParameter(tokens);
      while (optional(',', tokens)) {
        tokens = tokens.next;
        tokens = parseFormalParameter(tokens);
        ++count;
      }
    }
    tokens = expect(')', tokens);
    tokens = listener.endFormalParameters(tokens, count);
    return tokens;
  }

  /// A parameter contains a type and an identifier.
  ///
  /// <param> ::= <type> <identifier>
  Token parseFormalParameter(Token tokens) {
    tokens = listener.beginFormalParameter(tokens);
    tokens = parseType(tokens);
    tokens = parseIdentifier(tokens);
    tokens = listener.endFormalParameter(tokens);
    return tokens;
  }

  bool isValidTypeReference(Token tokens) {
    final kind = tokens.kind;
    return kind == IDENTIFIER_TOKEN;
  }

  bool isValidIdentifier(Token tokens) {
    return tokens.kind == IDENTIFIER_TOKEN;
  }

  /// Returns true if the [tokens] is a SymbolToken or a KeywordToken with
  /// stringValue [string].
  bool optional(String string, Token tokens) {
    return string == tokens.stringValue;
  }

  /// Checks that the [tokens] is a SymbolToken or a KeywordToken with
  /// stringValue [value].
  Token expect(String string, Token tokens) {
    if (string != tokens.stringValue) {
      tokens = listener.expected(string, tokens);
    } else {
      tokens = tokens.next;
    }
    return tokens;
  }

  bool valid(Token token) {
    return token.kind != EOF_TOKEN && token is! ErrorToken;
  }
}
