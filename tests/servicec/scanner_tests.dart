// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future;

import 'package:expect/expect.dart';

import 'package:compiler/src/scanner/scannerlib.dart' show
    EOF_INFO,
    STRING_INFO,
    OPEN_CURLY_BRACKET_INFO,
    CLOSE_CURLY_BRACKET_INFO,

    Token,
    KeywordToken,
    StringToken,
    SymbolToken,
    ErrorToken,

    Keyword,

    StringScanner;

import 'test.dart' show
    Test;

List<ScannerTest> SCANNER_TESTS = <ScannerTest>[
    new Success('empty_input', '''
''',
                []),
    new Success('empty_service', '''
service EmptyService {}
''',
                <Token>[
                  new KeywordToken(new Keyword("service"), 0),
                  new StringToken.fromString(STRING_INFO, "EmptyService", 8),
                  new SymbolToken(OPEN_CURLY_BRACKET_INFO, 22),
                  new SymbolToken(CLOSE_CURLY_BRACKET_INFO, 23)
                ]),

    new Failure('unmatched_curly', '''
service EmptyService {
''')
];

abstract class ScannerTest extends Test {
  final String input;
  ScannerTest(String name, this.input)
      : super(name);
}

class Success extends ScannerTest {
  final List<Token> output;

  Success(String name, String input, this.output)
      : super(name, input);

  Future perform() async {
    foldScannerOutputTokens(
        input,
        (token, index, _) {
          Expect.isTrue(
              token == output[index],
              "Expected $token at index $index to be ${output[index]}");
        },
        null);
  }
}

/// Scanning fails if the output contains [ErrorToken]s.
class Failure extends ScannerTest {

  Failure(String name, String input)
      : super(name, input);

  Future perform() async {
    foldScannerOutputTokens(
      input,
      (token, index, foundError) => foundError || token is ErrorToken,
      false);
  }
}

typedef dynamic TokenReduction(Token token, int index, dynamic accumulated);

dynamic foldScannerOutputTokens(
    String input,
    TokenReduction reduce,
    dynamic identity) {
  var scanner = new StringScanner.fromString(input);
  Token tokenLinkedList = scanner.tokenize();

  int index = 0;
  while (tokenLinkedList.info != EOF_INFO) {
    identity = reduce(tokenLinkedList, index++, identity);
    tokenLinkedList = tokenLinkedList.next;
  }
  return identity;
}
