// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.system;

// Move to dart:collection_patch as a private member.
class LinkedHashMapImpl<K, V> implements LinkedHashMap<K, V> {
  static const int _INITIAL_SIZE = 8;

  _LinkedHashMapNode _sentinel = new _LinkedHashMapNode(null, null);
  List _buckets;
  int _elements = 0;

  // TODO(ager): Other versions of constructors. Parameterization with
  // comparison etc.
  LinkedHashMapImpl() : _buckets = new List(_INITIAL_SIZE) {
    _sentinel.previousLink = _sentinel;
    _sentinel.nextLink = _sentinel;
  }

  LinkedHashMapImpl._(int buckets) : _buckets = new List(buckets) {
    _sentinel.previousLink = _sentinel;
    _sentinel.nextLink = _sentinel;
  }

  _LinkedHashMapNode<K, V> _lookup(K key) {
    var hash = key.hashCode.abs();
    var index = hash % _buckets.length;
    var node = _buckets[index];
    while (node != null) {
      if (node.key == key) return node;
      node = node.next;
    }
    return null;
  }

  bool containsValue(Object value) {
    for (var v in values) {
      if (v == value) return true;
    }
    return false;
  }

  bool containsKey(Object key) => _lookup(key) != null;

  V operator[](Object key) {
    var node = _lookup(key);
    if (node == null) return null;
    return node.value;
  }

  void _resizeIfNeeded() {
    var bucketCount = _buckets.length;
    if (_elements > (bucketCount - (bucketCount >> 2))) {
      var rehashed = new LinkedHashMapImpl<K, V>._(bucketCount * 2);
      rehashed.addAll(this);
      _buckets = rehashed._buckets;
      _sentinel = rehashed._sentinel;
      bucketCount = bucketCount * 2;
    }
  }

  void operator[]=(K key, V value) {
    _resizeIfNeeded();
    var hash = key.hashCode.abs();
    var index = hash % _buckets.length;
    var node = _buckets[index];
    while (node != null) {
      if (node.key == key) break;
      node = node.next;
    }
    if (node != null) {
      node.value = value;
    } else {
      var node = new _LinkedHashMapNode(key, value);
      node.next = _buckets[index];
      _buckets[index] = node;
      var sentinel = _sentinel;
      node.nextLink = sentinel;
      node.previousLink = sentinel.previousLink;
      sentinel.previousLink.nextLink = node;
      sentinel.previousLink = node;
      ++_elements;
    }
  }

  V putIfAbsent(K key, V ifAbsent()) {
    var node = _lookup(key);
    if (node != null) return node.value;
    var value = ifAbsent();
    return this[key] = value;
  }

  void addAll(Map<K, V> other) {
    for (var k in other.keys) {
      this[k] = other[k];
    }
  }

  V remove(Object key) {
    var hash = key.hashCode.abs();
    var index = hash % _buckets.length;
    var node = _buckets[index];
    var previous = null;
    while (node != null) {
      if (node.key == key) {
        if (previous == null) {
          _buckets[index] = node.next;
        } else {
          previous.next = node.next;
        }
        --_elements;
        node.previousLink.nextLink = node.nextLink;
        node.nextLink.previousLink = node.previousLink;
        return node.value;
      }
      previous = node;
      node = node.next;
    }
    return null;
  }

  void clear() {
    _sentinel.nextLink = _sentinel;
    _sentinel.previousLink = _sentinel;
    _buckets = new List(_INITIAL_SIZE);
    _elements = 0;
  }

  void forEach(void f(K key, V value)) {
    for (var k in this.keys) {
      f(k, this[k]);
    }
  }

  Iterable<K> get keys => new _LinkedKeyIterable(this);

  Iterable<V> get values => new _LinkedValueIterable(this);

  int get length => _elements;

  bool get isEmpty => _elements == 0;

  bool get isNotEmpty => !isEmpty;

  String toString() => Maps.mapToString(this);
}

class _LinkedHashMapNode<K, V> {
  final K key;
  V value;
  _LinkedHashMapNode next;

  _LinkedHashMapNode nextLink;
  _LinkedHashMapNode previousLink;

  _LinkedHashMapNode(this.key, this.value);
}

class _LinkedKeyIterable<K, V> extends IterableBase<K> implements Iterable<K> {
  final LinkedHashMapImpl<K, V> _map;
  _LinkedKeyIterable(this._map);
  Iterator<K> get iterator => new _LinkedKeyIterator<K, V>(_map);
}

class _LinkedKeyIterator<K, V> implements Iterator<K> {
  final LinkedHashMapImpl<K, V> _map;
  _LinkedHashMapNode<K, V> _next;
  K _current;

  _LinkedKeyIterator(this._map) {
    _next = _map._sentinel.nextLink;
  }

  bool moveNext() {
    var next = _next;
    if (identical(_next, _map._sentinel)) {
      _current = null;
      return false;
    }
    _current = next.key;
    _next = next.nextLink;
    return true;
  }

  K get current => _current;
}

class _LinkedValueIterable<K, V>
    extends IterableBase<V> implements Iterable<V> {
  final LinkedHashMapImpl<K, V> _map;
  _LinkedValueIterable(this._map);
  Iterator<V> get iterator => new _LinkedValueIterator<K, V>(_map);
}

class _LinkedValueIterator<K, V> implements Iterator<V> {
  final LinkedHashMapImpl<K, V> _map;
  _LinkedHashMapNode<K, V> _next;
  V _current;

  _LinkedValueIterator(this._map) {
    _next = _map._sentinel.nextLink;
  }

  bool moveNext() {
    var next = _next;
    if (identical(_next, _map._sentinel)) {
      _current = null;
      return false;
    }
    _current = next.value;
    _next = next.nextLink;
    return true;
  }

  V get current => _current;
}
