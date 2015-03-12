// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.system;

// TODO(ajohnsen): Rename String to e.g. _StringImpl.
abstract class String implements core.String {
  static String fromCharCode(int charCode) {
    var result = _create(1);
    result._setCodeUnitAt(0, charCode);
    return result;
  }

  String toString() => this;

  @native external String operator +(String other);

  @native external static String _create(int length);

  @native external void _setCodeUnitAt(int offset, int char);

  operator[] (index) {
    throw "operator[](index) isn't implemented";
  }

  codeUnitAt(index) {
    throw "codeUnitAt(index) isn't implemented";
  }

  get length {
    throw "get length isn't implemented";
  }

  endsWith(other) {
    throw "endsWith(other) isn't implemented";
  }

  startsWith(pattern, [index]) {
    throw "startsWith(pattern, [index]) isn't implemented";
  }

  indexOf(pattern, [start]) {
    throw "indexOf(pattern, [start]) isn't implemented";
  }

  lastIndexOf(pattern, [start]) {
    throw "lastIndexOf(pattern, [start]) isn't implemented";
  }

  get isEmpty {
    throw "get isEmpty isn't implemented";
  }

  get isNotEmpty {
    throw "get isNotEmpty isn't implemented";
  }

  substring(startIndex, [endIndex]) {
    throw "substring(startIndex, [endIndex]) isn't implemented";
  }

  trim() {
    throw "trim() isn't implemented";
  }

  trimLeft() {
    throw "trimLeft() isn't implemented";
  }

  trimRight() {
    throw "trimRight() isn't implemented";
  }

  operator* (times) {
    throw "operator*(times) isn't implemented";
  }

  padLeft(width, [padding]) {
    throw "padLeft(width, [padding]) isn't implemented";
  }

  padRight(width, [padding]) {
    throw "padRight(width, [padding]) isn't implemented";
  }

  contains(other, [startIndex]) {
    throw "contains(other, [startIndex]) isn't implemented";
  }

  replaceFirst(from, to, [startIndex]) {
    throw "replaceFirst(from, to, [startIndex]) isn't implemented";
  }

  replaceFirstMapped(from, replace, [startIndex]) {
    throw "replaceFirstMapped(from, replace, [startIndex]) isn't implemented";
  }

  replaceAll(from, replace) {
    throw "replaceAll(from, replace) isn't implemented";
  }

  replaceAllMapped(from, replace) {
    throw "replaceAllMapped(from, replace) isn't implemented";
  }

  replaceRange(start, end, replacement) {
    throw "replaceRange(start, end, replacement) isn't implemented";
  }

  split(pattern) {
    throw "split(pattern) isn't implemented";
  }

  splitMapJoin(pattern, {onMatch, onNonMatch}) {
    throw "splitMapJoin(pattern, {onMatch, onNonMatch}) isn't implemented";
  }

  get codeUnits {
    throw "get codeUnits isn't implemented";
  }

  get runes {
    throw "get runes isn't implemented";
  }

  toLowerCase() {
    throw "toLowerCase() isn't implemented";
  }

  toUpperCase() {
    throw "toUpperCase() isn't implemented";
  }
}
