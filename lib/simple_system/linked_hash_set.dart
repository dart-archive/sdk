// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.system;

class LinkedHashSetImpl<E> extends IterableBase<E> implements LinkedHashSet<E> {
  static const int _INITIAL_SIZE = 8;

  _Node _sentinel = new _Node(null);
  List _buckets;
  int _elements = 0;

  LinkedHashSetImpl() : _buckets = new List(_INITIAL_SIZE) {
    _sentinel.previousLink = _sentinel;
    _sentinel.nextLink = _sentinel;
  }

  LinkedHashSetImpl._(int buckets) : _buckets = new List(buckets) {
    _sentinel.previousLink = _sentinel;
    _sentinel.nextLink = _sentinel;
  }

  factory LinkedHashSetImpl.from(Iterable<E> other) {
    var result = new LinkedHashSetImpl();
    result.addAll(other);
    return result;
  }

  Iterator<E> get iterator => new _LinkedHashSetIterator(this);

  Set<E> toSet() => new LinkedHashSetImpl.from(this);

  int get length => _elements;

  bool get isEmpty => _elements == 0;

  bool get isNotEmpty => _elements != 0;

  bool add(E value) {
    var bucketCount = _buckets.length;
    if (_elements > (bucketCount - (bucketCount >> 2))) {
      var rehashed = new LinkedHashSetImpl<E>._(bucketCount * 2);
      rehashed.addAll(this);
      _buckets = rehashed._buckets;
      _sentinel = rehashed._sentinel;
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
    node = new _Node(value);
    node.next = _buckets[index];
    _buckets[index] = node;
    var sentinel = _sentinel;
    node.nextLink = sentinel;
    node.previousLink = sentinel.previousLink;
    sentinel.previousLink.nextLink = node;
    sentinel.previousLink = node;
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
        node.previousLink.nextLink = node.nextLink;
        node.nextLink.previousLink = node.previousLink;
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
    throw new UnimplementedError("LinkedHashSet.retainAll");
  }

  void removeWhere(bool test(E element)) {
    throw new UnimplementedError("LinkedHashSet.removeWhere");
  }

  void retainWhere(bool test(E element)) {
    throw new UnimplementedError("LinkedHashSet.retainWhere");
  }

  bool containsAll(Iterable<Object> other) {
    throw new UnimplementedError("LinkedHashSet.containsAll");
  }

  Set<E> intersection(Set<Object> other) {
    throw new UnimplementedError("LinkedHashSet.intersection");
  }

  Set<E> union(Set<E> other) {
    throw new UnimplementedError("LinkedHashSet.union");
  }

  Set<E> difference(Set<E> other) {
    throw new UnimplementedError("LinkedHashSet.difference");
  }

  void clear() {
    _sentinel.nextLink = _sentinel;
    _sentinel.previousLink = _sentinel;
    _buckets = new List(_INITIAL_SIZE);
    _elements = 0;
  }
}

class _Node<E> {
  final E value;
  _Node next;

  _Node nextLink;
  _Node previousLink;

  _Node(this.value);
}

class _LinkedHashSetIterator<E> implements Iterator<E> {
  // TODO(ager): Deal with concurrent modification errors.
  final LinkedHashSetImpl _set;
  _Node<E> _next;
  E _current;

  _LinkedHashSetIterator(this._set) {
    _next = _set._sentinel.nextLink;
  }

  bool moveNext() {
    var next = _next;
    if (identical(next, _set._sentinel)) {
      _current = null;
      return false;
    }
    _current = next.value;
    _next = next.nextLink;
    return true;
  }

  E get current => _current;
}
