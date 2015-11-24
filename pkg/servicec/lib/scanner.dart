// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.scanner;

import 'package:compiler/src/tokens/token.dart' show
    StringToken,
    ErrorToken,
    KeywordToken,
    SymbolToken,
    Token,
    UnmatchedToken;

import 'package:compiler/src/tokens/precedence_constants.dart' show
    GT_INFO,
    EOF_INFO,
    IDENTIFIER_INFO,
    STRING_INFO;

import 'package:compiler/src/tokens/precedence.dart' show
    PrecedenceInfo;

import "package:compiler/src/tokens/keyword.dart" show
    Keyword;

import "package:compiler/src/scanner/string_scanner.dart" show
    StringScanner;

import "package:compiler/src/util/characters.dart" show
    $LF;

import "keyword.dart" as own;

const int LF_TOKEN = $LF;
const PrecedenceInfo LF_INFO = const PrecedenceInfo('<new-line>', 0, LF_TOKEN);

class Scanner extends StringScanner {
  Scanner(String input)
    : super.fromString(input);

  void appendKeywordToken(Keyword keyword) {
    if (isServicecKeyword(keyword.syntax)) {
      super.appendKeywordToken(own.Keyword.keywords[keyword.syntax]);
    } else {
      super.appendSubstringToken(IDENTIFIER_INFO,
                                 scanOffset - keyword.syntax.length,
                                 true);
    }
  }

  void appendSubstringToken(PrecedenceInfo info, int start,
                            bool asciiOnly, [int extraOffset = 0]) {
    String syntax = string.substring(start, scanOffset + extraOffset);
    if (isServicecKeyword(syntax)) {
      Keyword keyword = own.Keyword.keywords[syntax];
      super.appendKeywordToken(keyword);
    } else {
      super.appendSubstringToken(info, start, asciiOnly, extraOffset);
    }
  }

  void appendErrorToken(ErrorToken token) {
    // Ignore unmatched tokens, since we handle them in a different way.
    if (token is! UnmatchedToken) {
      super.appendErrorToken(token);
    }
  }

  void appendGtGt(PrecedenceInfo info) {
    // There is no shift operator in the IDL, so treat >> as > >.
    appendGt(GT_INFO);
    appendGt(GT_INFO);
  }

  void appendWhiteSpace(int next) {
    super.appendWhiteSpace(next);
    if (next == $LF) {
      tail.next = new SymbolToken(LF_INFO, stringOffset);
      tail = tail.next;
    }
  }
}

bool isServicecKeyword(String string) {
  return own.Keyword.keywords.containsKey(string);
}
