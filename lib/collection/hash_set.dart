// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.collection;

class HashSet<E> extends IterableBase<E> implements Set<E> {
  static const int _INITIAL_SIZE = 8;

  List _buckets;
  int _elements = 0;

  HashSet() : _buckets = new List(_INITIAL_SIZE);

  HashSet._(int buckets) : _buckets = new List(buckets);

  factory HashSet.from(Iterable<E> other) {
    var result = new HashSet();
    result.addAll(other);
    return result;
  }

  Iterator<E> get iterator => new _HashSetIterator(this);

  Set<E> toSet() => new HashSet.from(this);

  int get length => _elements;

  bool get isEmpty => _elements == 0;

  bool get isNotEmpty => _elements != 0;

  bool add(E value) {
    var bucketCount = _buckets.length;
    if (_elements > (bucketCount - (bucketCount >> 2))) {
      var rehashed = new HashSet<E>._(bucketCount * 2);
      rehashed.addAll(this);
      _buckets = rehashed._buckets;
      bucketCount = bucketCount * 2;
    }
    var hash = value.hashCode.abs();
    var index = hash % bucketCount;
    var node = _buckets[index];
    while (node != null) {
      if (node.value == value) {
        return false;
      }
      node = node.next;
    }
    node = new _HashSetNode(value);
    node.next = _buckets[index];
    _buckets[index] = node;
    ++_elements;
    return true;
  }

  void addAll(Iterable<E> elements) {
    elements.forEach((E each) {
      add(each);
    });
  }

  bool remove(Object value) {
    var hash = value.hashCode.abs();
    var index = hash % _buckets.length;
    var node = _buckets[index];
    var previous = null;
    while (node != null) {
      if (node.value == value) {
        if (previous == null) {
          _buckets[index] = node.next;
        } else {
          previous.next = node.next;
        }
        --_elements;
        return true;
      }
      previous = node;
      node = node.next;
    }
    return false;
  }

  E lookup(Object object) {
    var hash = object.hashCode.abs();
    var index = hash % _buckets.length;
    var node = _buckets[index];
    while (node != null) {
      if (node.value == object) return node.value;
      node = node.next;
    }
    return null;
  }

  bool contains(Object object) => lookup(object) != null;

  void removeAll(Iterable<Object> elements) {
    elements.forEach((E each) {
      remove(each);
    });
  }

  void retainAll(Iterable<Object> elements) {
    throw new UnimplementedError("HashSet.retainAll");
  }

  void removeWhere(bool test(E element)) {
    throw new UnimplementedError("HashSet.removeWhere");
  }

  void retainWhere(bool test(E element)) {
    throw new UnimplementedError("HashSet.retainWhere");
  }

  bool containsAll(Iterable<Object> other) {
    throw new UnimplementedError("HashSet.containsAll");
  }

  Set<E> intersection(Set<Object> other) {
    throw new UnimplementedError("HashSet.intersection");
  }

  Set<E> union(Set<E> other) {
    throw new UnimplementedError("HashSet.union");
  }

  Set<E> difference(Set<E> other) {
    throw new UnimplementedError("HashSet.difference");
  }

  void clear() {
    _buckets = new List(_INITIAL_SIZE);
    _elements = 0;
  }
}

class _HashSetNode<E> {
  final E value;
  _HashSetNode next;

  _HashSetNode(this.value);
}

class _HashSetIterator<E> implements Iterator<E> {
  final HashSet _set;

  int _index = -1;
  _HashSetNode<E> _current;

  _HashSetIterator(this._set);

  bool moveNext() {
    if (_current != null) {
      _current = _current.next;
      if (_current != null) return true;
    }
    _index++;
    int limit = _set._buckets.length;
    for (; _index < limit; _index++) {
      if (_set._buckets[_index] != null) {
        _current = _set._buckets[_index];
        return true;
      }
    }
    return false;
  }

  E get current => (_current != null) ? _current.value : null;
}