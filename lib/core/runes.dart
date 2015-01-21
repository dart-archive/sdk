// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
class RuneIterator implements BidirectionalIterator<int> {
  final String string = "";

  factory RuneIterator(String string) {
    throw new UnimplementedError("RuneIterator");
  }

  factory RuneIterator.at(String string, int index) {
    throw new UnimplementedError("RuneIterator.at");
  }

  int get rawIndex {
    throw new UnimplementedError("RuneIterator.rawIndex");
  }

  void set rawIndex(int rawIndex) {
    throw new UnimplementedError("RuneIterator.rawIndex=");
  }

  void reset([int rawIndex = 0]) {
    throw new UnimplementedError("RuneIterator.reset");
  }

  int get current {
    throw new UnimplementedError("RuneIterator.current");
  }

  int get currentSize {
    throw new UnimplementedError("RuneIterator.currentSize");
  }

  String get currentAsString {
    throw new UnimplementedError("RuneIterator.currentAsString");
  }

  bool moveNext() {
    throw new UnimplementedError("RuneIterator.moveNext");
  }

  bool movePrevious() {
    throw new UnimplementedError("RuneIterator.movePrevious");
  }
}

class Runes implements Iterable<int> {
  final String string;
  Runes(this.string);

  RuneIterator get iterator => new RuneIterator(string);

  // TODO(kasperl): Add the unimplemented missing iterable methods.
}
