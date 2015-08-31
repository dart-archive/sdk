// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.scanner;

import "package:compiler/src/scanner/scannerlib.dart" show
    EOF_INFO,
    ErrorToken,
    IDENTIFIER_INFO,
    KEYWORD_TOKEN,
    Keyword,
    KeywordToken,
    PrecedenceInfo,
    STRING_INFO,
    StringScanner,
    StringToken,
    Token;

import "keyword.dart" as own;

class Scanner extends StringScanner {
  Scanner(String input)
    : super.fromString(input);

  void appendKeywordToken(Keyword keyword) {
    if (isServicecKeyword(keyword.syntax)) {
      super.appendKeywordToken(own.Keyword.keywords[keyword.syntax]);
    } else {
      if (identical(keyword.syntax, "void")) {
        bool doesNotMatter = true;
        super.appendSubstringToken(IDENTIFIER_INFO,
                                   scanOffset - 4,
                                   doesNotMatter);
      } else {
        tail.next = new StringToken.fromString(STRING_INFO,
                                               keyword.syntax,
                                               tokenStart);
        tail = tail.next;
      }
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
}

bool isServicecKeyword(String string) {
  return own.Keyword.keywords.containsKey(string);
}
