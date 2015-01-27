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
    if (count <= 0) return new _EmptyIterable<E>();
    return new _GeneratorIterable<E>(count, generator);
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

typedef E _Generator<E>(int index);

class _GeneratorIterable<E> extends IterableBase<E> {
  final int _start;
  final int _end;
  final _Generator<E> _generator;
  _GeneratorIterable(this._end, E generator(int n))
      : _start = 0,
        _generator = (generator != null) ? generator : _id;

  _GeneratorIterable.slice(this._start, this._end, this._generator);

  Iterator<E> get iterator =>
      new _GeneratorIterator<E>(_start, _end, _generator);
  int get length => _end - _start;

  Iterable<E> skip(int count) {
    RangeError.checkNotNegative(count, "count");
    if (count == 0) return this;
    int newStart = _start + count;
    if (newStart >= _end) return new _EmptyIterable<E>();
    return new _GeneratorIterable<E>.slice(newStart, _end, _generator);
  }

  Iterable<E> take(int count) {
    RangeError.checkNotNegative(count, "count");
    if (count == 0) return new _EmptyIterable<E>();
    int newEnd = _start + count;
    if (newEnd >= _end) return this;
    return new _GeneratorIterable<E>.slice(_start, newEnd, _generator);
  }

  static int _id(int n) => n;
}

class _GeneratorIterator<E> implements Iterator<E> {
  final int _end;
  final _Generator<E> _generator;
  int _index;
  E _current;

  _GeneratorIterator(this._index, this._end, this._generator);

  bool moveNext() {
    if (_index < _end) {
      _current = _generator(_index);
      _index++;
      return true;
    } else {
      _current = null;
      return false;
    }
  }

  E get current => _current;
}

class _EmptyIterable<E> extends IterableBase<E> {
  const _EmptyIterable();

  Iterator<E> get iterator => const _EmptyIterator();

  void forEach(void action(E element)) {}

  bool get isEmpty => true;

  int get length => 0;

  E get first { throw IterableElementError.noElement(); }

  E get last { throw IterableElementError.noElement(); }

  E get single { throw IterableElementError.noElement(); }

  E elementAt(int index) { throw new RangeError.range(index, 0, 0, "index"); }

  bool contains(Object element) => false;

  bool every(bool test(E element)) => true;

  bool any(bool test(E element)) => false;

  E firstWhere(bool test(E element), { E orElse() }) {
    if (orElse != null) return orElse();
    throw IterableElementError.noElement();
  }

  E lastWhere(bool test(E element), { E orElse() }) {
    if (orElse != null) return orElse();
    throw IterableElementError.noElement();
  }

  E singleWhere(bool test(E element), { E orElse() }) {
    if (orElse != null) return orElse();
    throw IterableElementError.noElement();
  }

  String join([String separator = ""]) => "";

  Iterable<E> where(bool test(E element)) => this;

  Iterable map(f(E element)) => const _EmptyIterable();

  E reduce(E combine(E value, E element)) {
    throw IterableElementError.noElement();
  }

  fold(var initialValue, combine(var previousValue, E element)) {
    return initialValue;
  }

  Iterable<E> skip(int count) {
    RangeError.checkNotNegative(count, "count");
    return this;
  }

  Iterable<E> skipWhile(bool test(E element)) => this;

  Iterable<E> take(int count) {
    RangeError.checkNotNegative(count, "count");
    return this;
  }

  Iterable<E> takeWhile(bool test(E element)) => this;

  List toList({ bool growable: true }) => growable ? <E>[] : new List<E>(0);

  Set toSet() => new Set<E>();
}

class _EmptyIterator<E> implements Iterator<E> {
  const _EmptyIterator();
  bool moveNext() => false;
  E get current => null;
}
