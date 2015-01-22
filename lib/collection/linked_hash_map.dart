// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.collection;

// TODO(kasperl): Stop relying on being able to use private classes
// from dart:core here.
class LinkedHashMap<K, V> extends _ConstantMap<K, V> {
  void operator[]=(K key, V value) {
    int index = _keys.indexOf(key);
    if (index >= 0) {
      _values[index] = value;
    } else {
      _keys.add(key);
      _values.add(value);
    }
  }

  V putIfAbsent(K key, V ifAbsent()) {
    V result = this[key];
    if (result == null && !containsKey(key)) {
      result = ifAbsent();
      this[key] = result;
    }
    return result;
  }

  void addAll(Map<K, V> other) {
    other.forEach((K key, V value) {
      this[key] = value;
    });
  }

  V remove(Object key) {
    int index = _keys.indexOf(key);
    if (index < 0) return null;
    _keys.removeAt(index);
    return _values.removeAt(index);
  }

  void clear() {
    _keys.clear();
    _values.clear();
  }
}
