// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

class String implements Comparable<String>, Pattern {

  int get length native;

  bool get isEmpty => length == 0;
  bool get isNotEmpty => length > 0;

  String operator+(String other) native;
  bool operator ==(String other) native;
  String operator[](int index) {
    return substring(index, index + 1);
  }

  String substring([int start, int end]) {
    if (start == null) start == 0;
    if (end == null) end = length;
    return _substring(start, end);
  }

  int compareTo(String other) {
    throw "Unimplemented";
  }

  String toString() => this;

  int codeUnitAt(int index) native catch (error) {
    switch (error) {
      case _wrongArgumentType:
        throw new ArgumentError();
      case _indexOutOfBounds:
        throw new RangeError();
    }
  }

  String _substring(int start, int end) native catch (error) {
    switch (error) {
      case _wrongArgumentType:
        throw new ArgumentError();
      case _indexOutOfBounds:
        throw new RangeError();
    }
  }
}

class StringBuffer {
  var _buffer;
  StringBuffer([this._buffer = ""]);

  void write(Object o) {
    _buffer += o.toString();
  }

  String toString() => _buffer;
}
