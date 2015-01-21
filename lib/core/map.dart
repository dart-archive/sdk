// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

class _ConstantMap {
  var _keys = [];
  var _values = [];

  int get length => _keys.length;
  int get isEmpty => _keys.isEmpty;
  int get isNotEmpty => _keys.isNotEmpty;

  operator[](key) {
    int index = _indexOf(key);
    if (index >= 0) {
      return _values[index];
    }
    return null;
  }

  operator[]=(key, value) { throw "[]= not supported on a const Map"; }
  remove(key) { throw "remove not supported on a const Map"; }
  void clear() { throw "clear not supported on a const Map"; }

  bool containsKey(key) => _keys.contains(key);

  get keys => new _MapIterable(_keys);

  get values => new _MapIterable(_values);

  int _indexOf(key) {
    for (int i = 0; i < _keys.length; i++) {
      if (_keys[i] == key) return i;
    }
    return -1;
  }
}

class Map extends _ConstantMap {
  operator[]=(key, value) {
    int index = _indexOf(key);
    if (index >= 0) {
      _values[index] = value;
    } else {
      _keys.add(key);
      _values.add(value);
    }
  }

  remove(key) {
    int index = _indexOf(key);
    if (index >= 0) {
      _keys.removeAt(index);
      return _values.removeAt(index);
    }
    return null;
  }

  void clear() {
    _keys.clear();
    _values.clear();
  }
}

class _MapIterable {
  final _list;
  _MapIterable(this._list);

  Iterator get iterator => new _ListIterator(_list);
}
