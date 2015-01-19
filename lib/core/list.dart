// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

class List {
  factory List([int count]) {
    if (identical(count, null)) return new _GrowableList();
    return new _FixedList(count);
  }
}

class _ConstantList {
  final _list;

  _ConstantList(int count) : this._list = _new(count);

  Iterator get iterator => new _ListIterator(this);

  int get length native;
  int get isEmpty => length == 0;
  int get isNotEmpty => length != 0;

  void add(value) { throw "add not supported on fixed-size List"; }
  void addAll(iterable) { throw "addAll not supported on fixed-size List"; }
  bool remove(value) { throw "remove not supported on fixed-size List"; }
  removeAt(int index) { throw "removeAt not supported on fixed-size List"; }
  removeLast() { throw "removeAt not supported on fixed-size List"; }
  void clear() { throw "clear not supported on fixed-size List"; }
  void removeWhere(bool test(element)) {
    throw "removeWhere not supported on fixed-size List";
  }

  get first => this[0];
  get last => this[length - 1];

  operator[](int index) native catch (error) {
    switch (error) {
      case _wrongArgumentType:
        throw new ArgumentError();
      case _indexOutOfBounds:
        throw new RangeError();
    }
  }

  operator[]=(int index, value) { throw "[]= not supported on a const List"; }

  String toString() => "List";

  bool contains(value) {
    for (int i = 0; i < length; i++) {
      if (this[i] == value) return true;
    }
    return false;
  }

  List sublist(int start, int end) {
    var result = new List();
    for (int i = start; i < end; i++) {
      result.add(this[i]);
    }
    return result;
  }

  static _new(int count) native;
}

class _FixedList extends _ConstantList {
  _FixedList([int count]) : super(count);

  operator[]=(int index, value) native catch (error) {
    switch (error) {
      case _wrongArgumentType:
        throw new ArgumentError();
      case _indexOutOfBounds:
        throw new RangeError();
    }
  }
}

class _GrowableList {
  var length;
  var _list;

  _GrowableList() : length = 0, _list = new _FixedList(4);

  Iterator get iterator => new _ListIterator(this);

  int get isEmpty => length == 0;
  int get isNotEmpty => length != 0;

  get first => this[0];
  get last => this[length - 1];

  void _grow(minSize) {
    // TODO(ager): play with heuristics here.
    var newList = new _FixedList(minSize + (minSize >> 2));
    for (int i = 0; i < _list.length; ++i) {
      newList[i] = _list[i];
    }
    _list = newList;
  }

  void add(value) {
    if (length >= _list.length) {
      _grow(length + 1);
    }
    _list[length++] = value;
  }

  void addAll(iterable) {
    for (int i = 0; i < iterable.length; ++i) {
      add(iterable[i]);
    }
  }

  void _shiftDown(int i) {
    for (int j = i + 1; j < length; ++j, ++i) {
      _list[i] = _list[j];
    }
    --length;
    _list[length] = null;
  }

  bool remove(value) {
    int i = 0;
    for (; i < length; ++i) {
      if (_list[i] == value) {
        _shiftDown(i);
        return true;
      }
    }
    return false;
  }

  removeAt(int index) {
    if (index >= length) throw "RangeError";
    var result = _list[index];
    _shiftDown(index);
    return result;
  }

  removeLast() {
    if (length == 0) throw "RangeError";
    --length;
    var result = _list[length];
    _list[length] = null;
    return result;
  }

  void clear() {
    if (length != 0) {
      length = 0;
      _list = new _GrowableList();
    }
  }

  operator[](int index) {
    if (index >= length) throw "RangeError";
    return _list[index];
  }

  operator[]=(int index, value) {
    if (index >= length) throw "RangeError";
    return _list[index] = value;
  }

  removeWhere(bool test(element)) {
    for (int i = 0; i < length; i++) {
      if (test(this[i])) removeAt(i);
    }
  }

  bool contains(value) {
    for (int i = 0; i < length; i++) {
      if (this[i] == value) return true;
    }
    return false;
  }

  List sublist(int start, int end) {
    var result = new List();
    for (int i = start; i < end; i++) {
      result.add(this[i]);
    }
    return result;
  }
}

class Iterator {
  bool moveNext();
  get current;
}

class _ListIterator implements Iterator {
  final List _list;
  int _index = -1;
  var current;

  _ListIterator(this._list);

  bool moveNext() {
    if (++_index < _list.length) {
      current = _list[_index];
      return true;
    }
    current = null;
    return false;
  }
}
