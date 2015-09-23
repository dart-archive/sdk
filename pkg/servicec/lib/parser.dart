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
      tokens = parseTopLevel(tokens);
      ++count;
    }
    tokens = listener.endCompilationUnit(tokens, count);
    return tokens;
  }

  /// A top-level declaration is a service or a struct.
  ///
  /// <top-level-declaration> ::= <service> | <struct>
  Token parseTopLevel(Token tokens) {
    tokens = listener.beginTopLevel(tokens);
    final String value = tokens.stringValue;
    if (identical(value, 'service')) {
      tokens = parseService(tokens);
    } else if (identical(value, 'struct')) {
      tokens = parseStruct(tokens);
    } else {
      tokens = listener.expectedTopLevel(tokens);
    }
    tokens = listener.endTopLevel(tokens);
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
        tokens = parseFunction(tokens);
        if (!valid(tokens)) break;  // Don't count unsuccessful declarations
        ++count;
      }
    }
    tokens = expect('}', tokens);
    tokens = listener.endService(tokens, count);
    return tokens;
  }

  /// A struct contains the keyword, an identifier, and a body. The body is
  /// enclosed in {} and contains zero or more field declarations.
  ///
  /// <struct> ::= 'struct' <identifier> '{' <field-decl>* '}'
  Token parseStruct(Token tokens) {
    tokens = listener.beginStruct(tokens);
    tokens = parseIdentifier(tokens.next);
    tokens = expect('{', tokens);
    int count = 0;
    if (valid(tokens)) {
      while (!optional('}', tokens)) {
        tokens = parseMember(tokens);
        if (!valid(tokens)) break;  // Don't count unsuccessful declarations
        ++count;
      }
    }
    tokens = expect('}', tokens);
    tokens = listener.endStruct(tokens, count);
    return tokens;
  }

  Token parseIdentifier(Token tokens) {
    if (isValidIdentifier(tokens)) {
      tokens = listener.handleIdentifier(tokens);
    } else {
      tokens = listener.expectedIdentifier(tokens);
    }
    return tokens;
  }

  /// A function declaration contains a type, an identifier, formal parameters,
  /// and a semicolon.
  ///
  /// <func-decl> ::= <type> <identifier> <formal-params> ';'
  Token parseFunction(Token tokens) {
    tokens = listener.beginFunction(tokens);
    tokens = parseType(tokens);
    tokens = parseIdentifier(tokens);
    tokens = expect('(', tokens);
    int count = 0;
    if (!optional(')', tokens)) {
      tokens = parseFormal(tokens);
      ++count;
      while (optional(',', tokens)) {
        tokens = tokens.next;
        tokens = parseFormal(tokens);
        ++count;
      }
    }
    tokens = expect(')', tokens);
    tokens = expect(';', tokens);
    tokens = listener.endFunction(tokens, count);
    return tokens;
  }

  // Parse a struct member that can be either a field or a union.
  Token parseMember(Token tokens) {
    final String value = tokens.stringValue;
    if (identical(value, 'union')) {
      tokens = parseUnion(tokens);
    } else {
      tokens = parseField(tokens);
    }
    return tokens;
  }

  /// A union contains the 'union' keyword and a list of fields, enclosed in
  /// curly braces.
  ///
  /// <union> ::= 'union' '{' <field>* '}'
  Token parseUnion(Token tokens) {
    tokens = listener.beginUnion(tokens);
    tokens = expect('{', tokens.next);
    int count = 0;
    if (valid(tokens)) {
      while (!optional('}', tokens)) {
        tokens = parseField(tokens);
        if (!valid(tokens)) break;  // Don't count unsuccessful declarations
        ++count;
      }
    }
    tokens = expect('}', tokens);
    tokens = listener.endUnion(tokens, count);
    return tokens;
  }

  /// A field contains a type, an identifier, and a semicolon.
  ///
  /// <field-decl> ::= <type> <identifier> ';'
  Token parseField(Token tokens) {
    tokens = listener.beginField(tokens);
    tokens = parseType(tokens);
    tokens = parseIdentifier(tokens);
    tokens = expect(';', tokens);
    tokens = listener.endField(tokens);
    return tokens;
  }

  Token parseType(Token tokens) {
    tokens = listener.beginType(tokens);
    tokens = parseIdentifier(tokens);
    if (optional('*', tokens)) {
      // Push a simple type on the stack.
      tokens = listener.handleSimpleType(tokens);
      tokens = tokens.next;
      // Pop the simple type and push a pointer type.
      tokens = listener.handlePointerType(tokens);
    } else if (optional('<', tokens)) {
      tokens = tokens.next;
      tokens = parseType(tokens);
      tokens = expect('>', tokens);
      tokens = listener.handleListType(tokens);
    } else {
      tokens = listener.handleSimpleType(tokens);
    }
    tokens = listener.endType(tokens);
    return tokens;
  }

  /// A formal contains a type and an identifier.
  ///
  /// <param> ::= <type> <identifier>
  Token parseFormal(Token tokens) {
    tokens = listener.beginFormal(tokens);
    tokens = parseType(tokens);
    tokens = parseIdentifier(tokens);
    tokens = listener.endFormal(tokens);
    return tokens;
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
