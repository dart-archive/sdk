// Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library immic.grammar;

import 'package:petitparser/petitparser.dart';

class ImmiGrammarDefinition extends GrammarDefinition {
  Parser token(String input) {
    Parser parser = input.length == 1 ? char(input) : string(input);
    return parser.token().trim(ref(HIDDEN));
  }


  // -----------------------------------------------------------------
  // Keyword definitions.
  // -----------------------------------------------------------------
  LIST() => ref(token, 'List');

  STRUCT() => ref(token, 'node');

  UNION() => ref(token, 'union');

  IMPORT() => ref(token, 'import');

  // -----------------------------------------------------------------
  // Grammar productions.
  // -----------------------------------------------------------------
  start() => ref(unit).end();

  unit() => ref(import).star() & ref(struct).star();

  import() => ref(IMPORT)
      & ((ref(token, '"')
           & ref(token, '"').neg().star()
           & ref(token, '"'))
         |
         (ref(token, "'")
           & ref(token, "'").neg().star()
           & ref(token, "'")))
      & ref(token, ';');

  struct() => ref(STRUCT)
      & ref(identifier)
      & ref(token, '{')
      & (ref(slot) | ref(union) | ref(method)).star()
      & ref(token, '}');

  slot() => ref(formal)
      & ref(token, ';');

  union() => ref(UNION)
      & ref(token, '{')
      & ref(slot).star()
      & ref(token, '}');

  method() => ref(type)
      & ref(identifier)
      & ref(token, '(')
      & ref(formals).optional(const [])
      & ref(token, ')')
      & ref(token, ';');

  formals() => ref(formal)
      .separatedBy(ref(token, ','), includeSeparators: false);

  formal() => ref(type)
      & ref(identifier);

  type() => ref(listType)
      | ref(stringType)
      | ref(nodeType)
      | ref(simpleType);

  stringType() => ref(token, 'String');
  nodeType() => ref(token, 'Node');

  simpleType() => ref(identifier)
      & ref(token, '*').optional(null).map((e) => e != null);

  listType() => ref(LIST)
      & ref(token, '<')
      & ref(listMemberType)
      & ref(token, '>');

  listMemberType() => ref(nodeType)
      | ref(simpleType);

  identifier() => ref(IDENTIFIER).trim(ref(HIDDEN));


  // -----------------------------------------------------------------
  // Lexical tokens.
  // -----------------------------------------------------------------
  IDENTIFIER() => ref(IDENTIFIER_START)
      & ref(IDENTIFIER_PART).star();

  IDENTIFIER_START() => ref(IDENTIFIER_START_NO_DOLLAR)
      | char('\$');

  IDENTIFIER_START_NO_DOLLAR() => ref(LETTER)
      | char('_');

  IDENTIFIER_PART_NO_DOLLAR() => ref(IDENTIFIER_START_NO_DOLLAR)
      | ref(DIGIT);

  IDENTIFIER_PART() => ref(IDENTIFIER_START)
      | ref(DIGIT);

  LETTER() => letter();

  DIGIT() => digit();


  // -----------------------------------------------------------------
  // Whitespace and comments.
  // -----------------------------------------------------------------
  HIDDEN() => ref(WHITESPACE_OR_COMMENT).plus();

  WHITESPACE_OR_COMMENT() => ref(WHITESPACE)
     | ref(SINGLE_LINE_COMMENT)
     | ref(MULTI_LINE_COMMENT)
     ;

  WHITESPACE() => whitespace();
  NEWLINE() => pattern('\n\r');

  SINGLE_LINE_COMMENT() => string('//')
     & ref(NEWLINE).neg().star()
     & ref(NEWLINE).optional()
     ;

  MULTI_LINE_COMMENT() => string('/*')
     & (ref(MULTI_LINE_COMMENT) | string('*/').neg()).star() & string('*/')
     ;
}
