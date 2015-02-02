// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.collection;

abstract class IterableBase<E> implements Iterable<E> {
  const IterableBase();

  Iterable map(f(E element)) => new _MappedIterable<E, dynamic>(this, f);

  Iterable<E> where(bool f(E element)) => new _WhereIterable<E>(this, f);

  Iterable expand(Iterable f(E element)) {
    return new _ExpandIterable<E, dynamic>(this, f);
  }

  bool contains(Object element) {
    for (E e in this) {
      if (e == element) return true;
    }
    return false;
  }

  void forEach(void f(E element)) {
    for (E element in this) f(element);
  }

  E reduce(E combine(E value, E element)) {
    Iterator<E> iterator = this.iterator;
    if (!iterator.moveNext()) {
      throw _IterableErrors.noElement();
    }
    E value = iterator.current;
    while (iterator.moveNext()) {
      value = combine(value, iterator.current);
    }
    return value;
  }

  dynamic fold(var initialValue,
               dynamic combine(var previousValue, E element)) {
    var value = initialValue;
    for (E element in this) value = combine(value, element);
    return value;
  }

  bool every(bool f(E element)) {
    for (E element in this) {
      if (!f(element)) return false;
    }
    return true;
  }

  String join([String separator = ""]) {
    Iterator<E> iterator = this.iterator;
    if (!iterator.moveNext()) return "";
    StringBuffer buffer = new StringBuffer();
    if (separator == null || separator == "") {
      do {
        buffer.write("${iterator.current}");
      } while (iterator.moveNext());
    } else {
      buffer.write("${iterator.current}");
      while (iterator.moveNext()) {
        buffer.write(separator);
        buffer.write("${iterator.current}");
      }
    }
    return buffer.toString();
  }

  bool any(bool f(E element)) {
    for (E element in this) {
      if (f(element)) return true;
    }
    return false;
  }

  List<E> toList({ bool growable: true }) =>
      new List<E>.from(this, growable: growable);

  Set<E> toSet() => new Set<E>.from(this);

  int get length {
    int count = 0;
    Iterator it = iterator;
    while (it.moveNext()) {
      count++;
    }
    return count;
  }

  bool get isEmpty => !iterator.moveNext();

  bool get isNotEmpty => !isEmpty;

  Iterable<E> take(int n) {
    return new _TakeIterable<E>(this, n);
  }

  Iterable<E> takeWhile(bool test(E value)) {
    return new _TakeWhileIterable<E>(this, test);
  }

  Iterable<E> skip(int n) {
    return new _SkipIterable<E>(this, n);
  }

  Iterable<E> skipWhile(bool test(E value)) {
    return new _SkipWhileIterable<E>(this, test);
  }

  E get first {
    Iterator it = iterator;
    if (!it.moveNext()) {
      throw _IterableErrors.noElement();
    }
    return it.current;
  }

  E get last {
    Iterator it = iterator;
    if (!it.moveNext()) {
      throw _IterableErrors.noElement();
    }
    E result;
    do {
      result = it.current;
    } while(it.moveNext());
    return result;
  }

  E get single {
    Iterator it = iterator;
    if (!it.moveNext()) throw _IterableErrors.noElement();
    E result = it.current;
    if (it.moveNext()) throw _IterableErrors.tooManyElements();
    return result;
  }

  E firstWhere(bool test(E value), { E orElse() }) {
    for (E element in this) {
      if (test(element)) return element;
    }
    if (orElse != null) return orElse();
    throw _IterableErrors.noElement();
  }

  E lastWhere(bool test(E value), { E orElse() }) {
    E result = null;
    bool foundMatching = false;
    for (E element in this) {
      if (test(element)) {
        result = element;
        foundMatching = true;
      }
    }
    if (foundMatching) return result;
    if (orElse != null) return orElse();
    throw _IterableErrors.noElement();
  }

  E singleWhere(bool test(E value)) {
    E result = null;
    bool foundMatching = false;
    for (E element in this) {
      if (test(element)) {
        if (foundMatching) {
          throw _IterableErrors.tooManyElements();
        }
        result = element;
        foundMatching = true;
      }
    }
    if (foundMatching) return result;
    throw _IterableErrors.noElement();
  }

  E elementAt(int index) {
    // TODO(ager): The compiler does not like this:
    // throw new ArgumentError.notNull("index");
    if (index is! int) throw new ArgumentError("index must not be null");
    RangeError.checkNotNegative(index, "index");
    int elementIndex = 0;
    for (E element in this) {
      if (index == elementIndex) return element;
      elementIndex++;
    }
    throw new RangeError.index(index, this, "index", null, elementIndex);
  }

  static String iterableToFullString(Iterable iterable,
                                     [String leftDelimiter = '(',
                                      String rightDelimiter = ')']) {
    throw new UnimplementedError('IterableBase.iterableToFullString');
  }
}

typedef T _Transformation<S, T>(S value);

class _MappedIterable<S, T> extends IterableBase<T> {
  final Iterable<S> _iterable;
  final _Transformation<S, T> _f;

  factory _MappedIterable(Iterable iterable, T function(S value)) {
    return new _MappedIterable<S, T>._(iterable, function);
  }

  _MappedIterable._(this._iterable, T this._f(S element));

  Iterator<T> get iterator => new _MappedIterator<S, T>(_iterable.iterator, _f);

  // Length related functions are independent of the mapping.
  int get length => _iterable.length;
  bool get isEmpty => _iterable.isEmpty;

  // Index based lookup can be done before transforming.
  T get first => _f(_iterable.first);
  T get last => _f(_iterable.last);
  T get single => _f(_iterable.single);
  T elementAt(int index) => _f(_iterable.elementAt(index));
}

class _MappedIterator<S, T> extends Iterator<T> {
  T _current;
  final Iterator<S> _iterator;
  final _Transformation<S, T> _f;

  _MappedIterator(this._iterator, T this._f(S element));

  bool moveNext() {
    if (_iterator.moveNext()) {
      _current = _f(_iterator.current);
      return true;
    }
    _current = null;
    return false;
  }

  T get current => _current;
}

typedef bool _ElementPredicate<E>(E arg);

class _WhereIterable<E> extends IterableBase<E> {
  final Iterable<E> _iterable;
  final _ElementPredicate _f;

  _WhereIterable(this._iterable, bool this._f(E element));

  Iterator<E> get iterator => new _WhereIterator<E>(_iterable.iterator, _f);
}

class _WhereIterator<E> extends Iterator<E> {
  final Iterator<E> _iterator;
  final _ElementPredicate _f;

  _WhereIterator(this._iterator, bool this._f(E element));

  bool moveNext() {
    while (_iterator.moveNext()) {
      if (_f(_iterator.current)) {
        return true;
      }
    }
    return false;
  }

  E get current => _iterator.current;
}

typedef Iterable<T> _ExpandFunction<S, T>(S sourceElement);

class _ExpandIterable<S, T> extends IterableBase<T> {
  final Iterable<S> _iterable;
  final _ExpandFunction _f;

  _ExpandIterable(this._iterable, Iterable<T> this._f(S element));

  Iterator<T> get iterator => new _ExpandIterator<S, T>(_iterable.iterator, _f);
}

class _ExpandIterator<S, T> implements Iterator<T> {
  final Iterator<S> _iterator;
  final _ExpandFunction _f;
  // Initialize _currentExpansion to an empty iterable. A null value
  // marks the end of iteration, and we don't want to call _f before
  // the first moveNext call.
  Iterator<T> _currentExpansion = const _EmptyIterator();
  T _current;

  _ExpandIterator(this._iterator, Iterable<T> this._f(S element));

  T get current => _current;

  bool moveNext() {
    if (_currentExpansion == null) return false;
    while (!_currentExpansion.moveNext()) {
      _current = null;
      if (_iterator.moveNext()) {
        // If _f throws, this ends iteration. Otherwise _currentExpansion and
        // _current will be set again below.
        _currentExpansion = null;
        _currentExpansion = _f(_iterator.current).iterator;
      } else {
        return false;
      }
    }
    _current = _currentExpansion.current;
    return true;
  }
}

class _TakeIterable<E> extends IterableBase<E> {
  final Iterable<E> _iterable;
  final int _takeCount;

  factory _TakeIterable(Iterable<E> iterable, int takeCount) {
    if (takeCount is! int || takeCount < 0) {
      throw new ArgumentError(takeCount);
    }
    return new _TakeIterable<E>._(iterable, takeCount);
  }

  _TakeIterable._(this._iterable, this._takeCount);

  Iterator<E> get iterator {
    return new _TakeIterator<E>(_iterable.iterator, _takeCount);
  }
}

class _TakeIterator<E> extends Iterator<E> {
  final Iterator<E> _iterator;
  int _remaining;

  _TakeIterator(this._iterator, this._remaining);

  bool moveNext() {
    _remaining--;
    if (_remaining >= 0) {
      return _iterator.moveNext();
    }
    _remaining = -1;
    return false;
  }

  E get current {
    if (_remaining < 0) return null;
    return _iterator.current;
  }
}

class _TakeWhileIterable<E> extends IterableBase<E> {
  final Iterable<E> _iterable;
  final _ElementPredicate _f;

  _TakeWhileIterable(this._iterable, bool this._f(E element));

  Iterator<E> get iterator {
    return new _TakeWhileIterator<E>(_iterable.iterator, _f);
  }
}

class _TakeWhileIterator<E> extends Iterator<E> {
  final Iterator<E> _iterator;
  final _ElementPredicate _f;
  bool _isFinished = false;

  _TakeWhileIterator(this._iterator, bool this._f(E element));

  bool moveNext() {
    if (_isFinished) return false;
    if (!_iterator.moveNext() || !_f(_iterator.current)) {
      _isFinished = true;
      return false;
    }
    return true;
  }

  E get current {
    if (_isFinished) return null;
    return _iterator.current;
  }
}

class _SkipIterable<E> extends IterableBase<E> {
  final Iterable<E> _iterable;
  final int _skipCount;

  factory _SkipIterable(Iterable<E> iterable, int count) {
    return new _SkipIterable<E>._(iterable, count);
  }

  _SkipIterable._(this._iterable, this._skipCount) {
    if (_skipCount is! int) {
      throw new ArgumentError.value(_skipCount, "count is not an integer");
    }
    RangeError.checkNotNegative(_skipCount, "count");
  }

  Iterable<E> skip(int count) {
    if (_skipCount is! int) {
      throw new ArgumentError.value(_skipCount, "count is not an integer");
    }
    RangeError.checkNotNegative(_skipCount, "count");
    return new _SkipIterable<E>._(_iterable, _skipCount + count);
  }

  Iterator<E> get iterator {
    return new _SkipIterator<E>(_iterable.iterator, _skipCount);
  }
}

class _SkipIterator<E> extends Iterator<E> {
  final Iterator<E> _iterator;
  int _skipCount;

  _SkipIterator(this._iterator, this._skipCount);

  bool moveNext() {
    for (int i = 0; i < _skipCount; i++) _iterator.moveNext();
    _skipCount = 0;
    return _iterator.moveNext();
  }

  E get current => _iterator.current;
}

class _SkipWhileIterable<E> extends IterableBase<E> {
  final Iterable<E> _iterable;
  final _ElementPredicate _f;

  _SkipWhileIterable(this._iterable, bool this._f(E element));

  Iterator<E> get iterator {
    return new _SkipWhileIterator<E>(_iterable.iterator, _f);
  }
}

class _SkipWhileIterator<E> extends Iterator<E> {
  final Iterator<E> _iterator;
  final _ElementPredicate _f;
  bool _hasSkipped = false;

  _SkipWhileIterator(this._iterator, bool this._f(E element));

  bool moveNext() {
    if (!_hasSkipped) {
      _hasSkipped = true;
      while (_iterator.moveNext()) {
        if (!_f(_iterator.current)) return true;
      }
    }
    return _iterator.moveNext();
  }

  E get current => _iterator.current;
}

class _EmptyIterator<E> implements Iterator<E> {
  const _EmptyIterator();
  bool moveNext() => false;
  E get current => null;
}

class _IterableErrors {
  static noElement() => new StateError("No element");
  static tooManyElements() => new StateError("Too many elements");
}