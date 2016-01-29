// Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.keyword;

import "package:compiler/src/tokens/keyword.dart" as dart2js;

/// Custom Keyword class for the servicec front-end.
class Keyword extends dart2js.Keyword {
  static const Keyword service = const Keyword("service");
  static const Keyword struct = const Keyword("struct");
  static const Keyword union = const Keyword("union");

  static Map<String, Keyword> keywords = {
    "service": service,
    "struct" : struct,
    "union" : union
  };

  const Keyword(String syntax)
    : super(syntax);
}
