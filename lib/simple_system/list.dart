// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.system;

// TODO(ajohnsen): Implement 'List'.
class _ConstantList<E> {
  final _list;

  _ConstantList(int length)
      : this._list = _new(length);

  @native external int get length;

  int get isEmpty => length == 0;

  int get isNotEmpty => length != 0;

  @native external E operator[](int index);

  @native external static _ConstantList _new(int length);
}

class _FixedList<E> extends _ConstantList<E> {
  _FixedList([int length])
      : super(length);

  @native external E operator[]=(int index, value);
}

// TODO(ajohnsen): Implement 'List'.
class _GrowableList<E> {
  int _length;
  _FixedList<E> _list;

  _GrowableList()
      : _length = 0,
        _list = new _FixedList<E>(4);

  int get length => _length;

  int get isEmpty => _length == 0;

  int get isNotEmpty => _length != 0;

  void add(E value) {
    _FixedList<E> list = _list;
    int length = _length;
    int newLength = length + 1;
    if (length >= list.length) {
      list = _grow(newLength);
    }
    list[length] = value;
    _length = newLength;
  }

  E operator[](int index) {
    // TODO(ajohnsen): Fix throw of exception.
    if (index >= _length) throw "new IndexError(index, this)";
    return _list[index];
  }

  void operator[]=(int index, value) {
    // TODO(ajohnsen): Fix throw of exception.
    if (index >= length) throw "new IndexError(index, this);";
    return _list[index] = value;
  }

  _FixedList<E> _grow(minSize) {
    // TODO(ager): play with heuristics here.
    var newList = new _FixedList<E>(minSize + (minSize >> 2));
    for (int i = 0; i < _list.length; ++i) {
      newList[i] = _list[i];
    }
    return _list = newList;
  }
}
