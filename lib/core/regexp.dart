// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
abstract class Pattern {
  Iterable<Match> allMatches(String string, [int start=0]);

  Match matchAsPrefix(String string, [int start=0]);
}

// Matches dart:core on Jan 21, 2015.
abstract class Match {
  int get start;

  int get end;

  String group(int group);

  String operator[](int group);

  List<String> groups(List<int> groupIndices);

  int get groupCount;

  String get input;

  Pattern get pattern;
}

// Matches dart:core on Jan 21, 2015.
abstract class RegExp implements Pattern {
  factory RegExp(String source, {bool multiLine: false,
                                 bool caseSensitive: true}) {
    throw new UnimplementedError("RegExp");
  }

  Match firstMatch(String input);

  Iterable<Match> allMatches(String input, [int start = 0]);

  bool hasMatch(String input);

  String stringMatch(String input);

  String get pattern;

  bool get isMultiLine;

  bool get isCaseSensitive;
}
