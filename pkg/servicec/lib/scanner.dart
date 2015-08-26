// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.scanner;

import "package:compiler/src/scanner/scannerlib.dart" show
    Token,
    ErrorToken,
    StringToken,
    KeywordToken,
    KEYWORD_TOKEN,

    Keyword,
    PrecedenceInfo,

    StringScanner,

    EOF_INFO,
    STRING_INFO;

class Scanner extends StringScanner {
  Scanner(String input)
    : super.fromString(input);

  void appendKeywordToken(Keyword keyword) {
    if (isServicecKeyword(keyword.syntax)) {
      super.appendKeywordToken(keyword);
    } else {
      tail.next = new StringToken.fromString(STRING_INFO,
                                             keyword.syntax,
                                             tokenStart);
      tail = tail.next;
    }
  }

  void appendSubstringToken(PrecedenceInfo info, int start,
                            bool asciiOnly, [int extraOffset = 0]) {
    String syntax = string.substring(start, scanOffset + extraOffset);
    if (isServicecKeyword(syntax)) {
      Keyword keyword = keywords[syntax];
      super.appendKeywordToken(keyword);
    } else {
      super.appendSubstringToken(info, start, asciiOnly, extraOffset);
    }
  }
}

Map<String, Keyword> keywords = {
    "service": const Keyword("service"),
    "struct" : const Keyword("struct")
};

bool isServicecKeyword(String word) {
  return keywords.containsKey(word);
}
