// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.grammar;

import 'package:petitparser/petitparser.dart';

class ServiceGrammarDefinition extends GrammarDefinition {
  Parser token(String input) {
    Parser parser = input.length == 1 ? char(input) : string(input);
    return parser.token().trim(ref(HIDDEN));
  }


  // -----------------------------------------------------------------
  // Keyword definitions.
  // -----------------------------------------------------------------
  SERVICE() => ref(token, 'service');


  // -----------------------------------------------------------------
  // Grammar productions.
  // -----------------------------------------------------------------
  start() => ref(unit).end();

  unit() => ref(service).star();

  service() => ref(SERVICE)
      & ref(identifier)
      & ref(token, '{')
      & ref(method).star()
      & ref(token, '}');

  method() => ref(identifier)
      & ref(token, '(')
      & ref(type)  // TODO(kasperl): Allow zero or many argument.
      & ref(token, ')')
      & ref(token, ':')
      & ref(type)
      & ref(token, ';');

  type() => ref(identifier);

  identifier() => ref(IDENTIFIER);


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