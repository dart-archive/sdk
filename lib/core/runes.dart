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

// Matches dart:core on Jan 21, 2015.
class Runes implements Iterable<int> {
  final String string;
  Runes(this.string);

  RuneIterator get iterator => new RuneIterator(string);

  Iterable map(f(int element)) {
    throw new UnimplementedError("Runes.map");
  }

  Iterable<int> where(bool test(int element)) {
    throw new UnimplementedError("Runes.where");
  }

  Iterable expand(Iterable f(int element)) {
    throw new UnimplementedError("Runes.expand");
  }

  bool contains(Object element) {
    throw new UnimplementedError("Runes.contains");
  }

  void forEach(void f(int element)) {
    throw new UnimplementedError("Runes.forEach");
  }

  int reduce(int combine(int value, int element)) {
    throw new UnimplementedError("Runes.reduce");
  }

  dynamic fold(var initialValue,
               dynamic combine(var previousValue, int element)) {
    throw new UnimplementedError("Runes.fold");
  }

  bool every(bool test(int element)) {
    throw new UnimplementedError("Runes.every");
  }

  String join([String separator = ""]) {
    throw new UnimplementedError("Runes.join");
  }

  bool any(bool test(int element)) {
    throw new UnimplementedError("Runes.any");
  }

  List<E> toList({ bool growable: true }) {
    throw new UnimplementedError("Runes.toList");
  }

  Set<E> toSet() {
    throw new UnimplementedError("Runes.toSet");
  }

  int get length {
    throw new UnimplementedError("Runes.length");
  }

  bool get isEmpty {
    throw new UnimplementedError("Runes.isEmpty");
  }

  bool get isNotEmpty {
    throw new UnimplementedError("Runes.isNotEmpty");
  }

  Iterable<E> take(int n) {
    throw new UnimplementedError("Runes.take");
  }

  Iterable<E> takeWhile(bool test(int value)) {
    throw new UnimplementedError("Runes.takeWhile");
  }

  Iterable<E> skip(int n) {
    throw new UnimplementedError("Runes.skip");
  }

  Iterable<E> skipWhile(bool test(int value)) {
    throw new UnimplementedError("Runes.skipWhile");
  }

  int get first {
    throw new UnimplementedError("Runes.first");
  }

  int get last {
    throw new UnimplementedError("Runes.last");
  }

  int get single {
    throw new UnimplementedError("Runes.single");
  }

  int firstWhere(bool test(int element), { int orElse() }) {
    throw new UnimplementedError("Runes.firstWhere");
  }

  int lastWhere(bool test(int element), {int orElse()}) {
    throw new UnimplementedError("Runes.lastWhere");
  }

  int singleWhere(bool test(int element)) {
    throw new UnimplementedError("Runes.singleWhere");
  }

  int elementAt(int index) {
    throw new UnimplementedError("Runes.elementAt");
  }
}
