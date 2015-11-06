// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.fletch._system;

class _ConstantMap<K, V> implements Map<K, V> {
  final _keys;
  final _values;

  bool containsValue(Object value) => _values.contains(value);

  bool containsKey(Object key) => _keys.contains(key);

  V operator[](Object key) {
    int length = _keys.length;
    for (int i = 0; i < length; i++) {
      if (_keys[i] == key) return _values[i];
    }
    return null;
  }

  void operator[]=(K key, V value) {
    throw new UnsupportedError("Cannot update unmodifiable map");
  }

  V putIfAbsent(K key, V ifAbsent()) {
    throw new UnsupportedError("Cannot update unmodifiable map");
  }

  void addAll(Map<K, V> other) {
    throw new UnsupportedError("Cannot update unmodifiable map");
  }

  V remove(Object key) {
    throw new UnsupportedError("Cannot remove from unmodifiable map");
  }

  void clear() {
    throw new UnsupportedError("Cannot remove from unmodifiable map");
  }

  void forEach(void f(K key, V value)) {
    int length = _keys.length;
    for (int i = 0; i < length; i++) {
      f(_keys[i], _values[i]);
    }
  }

  Iterable<K> get keys => new _ConstantMapIterable(_keys);

  Iterable<V> get values => new _ConstantMapIterable(_values);

  int get length => _keys.length;

  bool get isEmpty => _keys.isEmpty;

  bool get isNotEmpty => _keys.isEmpty;

  String toString() => Maps.mapToString(this);
}

class _ConstantMapIterable<E> extends IterableBase<E> implements Iterable<E> {
  final _list;

  _ConstantMapIterable(this._list);

  Iterator<E> get iterator => new ListIterator(_list);

  int get length => _list.length;

  bool get isEmpty => _list.isEmpty;

  bool get isNotEmpty => _list.isNotEmpty;
}
