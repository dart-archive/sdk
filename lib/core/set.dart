// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
abstract class Set<E> implements Iterable<E> {
  factory Set() => new LinkedHashSet();

  factory Set.identity() {
    throw new UnimplementedError("Set.identity");
  }

  factory Set.from(Iterable<E> other) {
    throw new UnimplementedError("Set.from");
  }

  bool add(E value);

  void addAll(Iterable<E> elements);

  bool remove(Object value);

  E lookup(Object object);

  void removeAll(Iterable<Object> elements);

  void retainAll(Iterable<Object> elements);

  void removeWhere(bool test(E element));

  void retainWhere(bool test(E element));

  bool containsAll(Iterable<Object> other);

  Set<E> intersection(Set<Object> other);

  Set<E> union(Set<E> other);

  Set<E> difference(Set<E> other);

  void clear();
}
