// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
abstract class Iterator<E> {
  bool moveNext();
  E get current;
}

// Matches dart:core on Jan 21, 2015.
abstract class BidirectionalIterator<E> implements Iterator<E> {
  bool movePrevious();
}

// Matches dart:core on Jan 21, 2015.
abstract class Iterable<E> {
  const Iterable();

  factory Iterable.generate(int count, [E generator(int index)]) {
    throw new UnimplementedError("Iterable.generate");
  }

  Iterator<E> get iterator;

  Iterable map(f(E element));

  Iterable<E> where(bool test(E element));

  Iterable expand(Iterable f(E element));

  bool contains(Object element);

  void forEach(void f(E element));

  E reduce(E combine(E value, E element));

  dynamic fold(var initialValue,
               dynamic combine(var previousValue, E element));

  bool every(bool test(E element));

  String join([String separator = ""]) {
    StringBuffer buffer = new StringBuffer();
    buffer.writeAll(this, separator);
    return buffer.toString();
  }

  bool any(bool test(E element));

  List<E> toList({ bool growable: true });

  Set<E> toSet();

  int get length;

  bool get isEmpty;

  bool get isNotEmpty;

  Iterable<E> take(int n);

  Iterable<E> takeWhile(bool test(E value));

  Iterable<E> skip(int n);

  Iterable<E> skipWhile(bool test(E value));

  E get first;

  E get last;

  E get single;

  E firstWhere(bool test(E element), { E orElse() });

  E lastWhere(bool test(E element), {E orElse()});

  E singleWhere(bool test(E element));

  E elementAt(int index);
}
