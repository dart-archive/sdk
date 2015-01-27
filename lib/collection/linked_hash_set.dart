// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.collection;

class LinkedHashSet<E> extends IterableBase<E> implements Set<E> {
  final List _values = [];

  LinkedHashSet();

  LinkedHashSet.from(Iterable<E> other) {
    addAll(other);
  }

  Iterator<E> get iterator => _values.iterator;

  List<E> toList({ bool growable: true }) => _values.toList(growable);

  Set<E> toSet() => new LinkedHashSet.from(this);

  int get length => _values.length;

  bool get isEmpty => _values.isEmpty;

  bool get isNotEmpty => _values.isNotEmpty;

  E get first => _values.first;

  E get last => _values.last;

  E elementAt(int index) {
    if (index is! int) throw new ArgumentError('$index');
    return _values[index];
  }

  bool add(E value) {
    int index = _values.indexOf(value);
    if (index >= 0) return false;
    _values.add(value);
    return true;
  }

  void addAll(Iterable<E> elements) {
    elements.forEach((E each) {
      add(each);
    });
  }

  bool remove(Object value) => _values.remove(value);

  E lookup(Object object) {
    int index = _values.indexOf(object);
    return (index < 0) ? null : _values[index];
  }

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
    _values.clear();
  }
}
