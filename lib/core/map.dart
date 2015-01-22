// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
abstract class Map<K, V> {
  factory Map() => new LinkedHashMap();

  factory Map.from(Map<K, V> other) {
    throw new UnimplementedError("Map.from");
  }

  factory Map.identity() {
    throw new UnimplementedError("Map.identity");
  }

  factory Map.fromIterable(Iterable iterable,
      {K key(element), V value(element)}) {
    throw new UnimplementedError("Map.fromIterable");
  }

  factory Map.fromIterables(Iterable<K> keys, Iterable<V> values) {
    throw new UnimplementedError("Map.fromIterables");
  }

  bool containsValue(Object value);

  bool containsKey(Object key);

  V operator[](Object key);

  void operator[]=(K key, V value);

  V putIfAbsent(K key, V ifAbsent());

  void addAll(Map<K, V> other);

  V remove(Object key);

  void clear();

  void forEach(void f(K key, V value));

  Iterable<K> get keys;

  Iterable<V> get values;

  int get length;

  bool get isEmpty;

  bool get isNotEmpty;
}

class _ConstantMap<K, V> implements Map<K, V> {
  var _keys = [];
  var _values = [];

  bool containsValue(Object value) => _values.contains(value);

  bool containsKey(Object key) => _keys.contains(key);

  V operator[](Object key) {
    int index = _keys.indexOf(key);
    if (index < 0) return null;
    return _values[index];
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
    for (int i = 0; i < _keys.length; i++) {
      f(_keys[i], _values[i]);
    }
  }

  Iterable<K> get keys => new _MapIterable(_keys);

  Iterable<V> get values => new _MapIterable(_values);

  int get length => _keys.length;

  bool get isEmpty => _keys.isEmpty;

  bool get isNotEmpty => _keys.isEmpty;
}

class _MapIterable<E> implements Iterable<E> {
  final _list;
  _MapIterable(this._list);

  Iterator<E> get iterator => new _ListIterator(_list);

  Iterable map(f(E element)) {
    throw new UnimplementedError("_MapIterable.map");
  }

  Iterable<E> where(bool test(E element)) {
    throw new UnimplementedError("_MapIterable.where");
  }

  Iterable expand(Iterable f(E element)) {
    throw new UnimplementedError("_MapIterable.expand");
  }

  bool contains(Object element) {
    return _list.contains(element);
  }

  void forEach(void f(E element)) {
    _list.forEach(f);
  }

  E reduce(E combine(E value, E element)) {
    throw new UnimplementedError("_MapIterable.reduce");
  }

  dynamic fold(var initialValue,
               dynamic combine(var previousValue, E element)) {
    throw new UnimplementedError("_MapIterable.fold");
  }

  bool every(bool test(E element)) {
    throw new UnimplementedError("_MapIterable.every");
  }

  String join([String separator = ""]) {
    throw new UnimplementedError("_MapIterable.join");
  }

  bool any(bool test(E element)) {
    throw new UnimplementedError("_MapIterable.any");
  }

  List<E> toList({ bool growable: true }) {
    throw new UnimplementedError("_MapIterable.toList");
  }

  Set<E> toSet() {
    throw new UnimplementedError("_MapIterable.toSet");
  }

  int get length => _list.length;

  bool get isEmpty => _list.isEmpty;

  bool get isNotEmpty => _list.isNotEmpty;

  Iterable<E> take(int n) {
    throw new UnimplementedError("_MapIterable.take");
  }

  Iterable<E> takeWhile(bool test(E value)) {
    throw new UnimplementedError("_MapIterable.takeWhile");
  }

  Iterable<E> skip(int n) {
    throw new UnimplementedError("_MapIterable.skip");
  }

  Iterable<E> skipWhile(bool test(E value)) {
    throw new UnimplementedError("_MapIterable.skipWhile");
  }

  E get first {
    throw new UnimplementedError("_MapIterable.first");
  }

  E get last {
    throw new UnimplementedError("_MapIterable.last");
  }

  E get single {
    throw new UnimplementedError("_MapIterable.single");
  }

  E firstWhere(bool test(E element), { E orElse() }) {
    throw new UnimplementedError("_MapIterable.firstWhere");
  }

  E lastWhere(bool test(E element), {E orElse()}) {
    throw new UnimplementedError("_MapIterable.lastWhere");
  }

  E singleWhere(bool test(E element)) {
    throw new UnimplementedError("_MapIterable.singleWhere");
  }

  E elementAt(int index) => _list[index];
}
