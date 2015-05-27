// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.system;

// TODO(ajohnsen): Temp hack to expose _GrowableList/_FixedList to core.
List newList(int length) {
  return (length == null) ? new _GrowableList() : new _FixedList(length);
}

class _Lists {
  static void setRange(List list,
                       int start,
                       int end,
                       Iterable iterable,
                       int skipCount) {
    int length = list.length;
    if (start < 0 || start > length) {
      throw new RangeError.range(start, 0, length);
    }
    if (end < start || end > length) {
      throw new RangeError.range(end, start, length);
    }
    if ((end - start) == 0) return;
    Iterator it = iterable.iterator;
    while (skipCount > 0) {
      if (!it.moveNext()) return;
      skipCount--;
    }
    for (int i = start; i < end; i++) {
      if (!it.moveNext()) return;
      list[i] = it.current;
    }
  }
}

class _ConstantList<E> extends ListBase<E> implements List<E> {
  final _list;

  _ConstantList(int length)
      : this._list = _new(length);

  // Not external, to match non-external setter.
  @native int get length {
    throw nativeError;
  }

  @native E operator[](int index) {
    switch (nativeError) {
      case wrongArgumentType:
        throw new ArgumentError(index);

      case indexOutOfBounds:
        throw new IndexError(index, this);
    }
  }

  @native static _ConstantList _new(int length) {
    throw new ArgumentError(length);
  }

  void operator[]=(int index, E value) {
    throw new UnsupportedError("Cannot modify an unmodifiable list");
  }

  void set length(int newLength) {
    throw new UnsupportedError("Cannot change length of fixed-length list");
  }

  void add(E value) {
    throw new UnsupportedError("Cannot add to fixed-length list");
  }

  void addAll(Iterable<E> iterable) {
    throw new UnsupportedError("Cannot add to fixed-length list");
  }

  Iterable<E> get reversed {
    throw new UnimplementedError("_ConstantList.reversed");
  }

  void sort([int compare(E a, E b)]) {
    throw new UnsupportedError("Cannot modify an unmodifiable list");
  }

  void shuffle([Random random]) {
    throw new UnsupportedError("Cannot modify an unmodifiable list");
  }

  void clear() {
    throw new UnsupportedError("Cannot remove from fixed-length list");
  }

  void insert(int index, E element) {
    throw new UnsupportedError("Cannot add to fixed-length list");
  }

  void insertAll(int index, Iterable<E> iterable) {
    throw new UnsupportedError("Cannot add to fixed-length list");
  }

  void setAll(int index, Iterable<E> iterable) {
    throw new UnsupportedError("Cannot add to fixed-length list");
  }

  bool remove(Object value) {
    throw new UnsupportedError("Cannot remove from fixed-length list");
  }

  E removeAt(int index) {
    throw new UnsupportedError("Cannot remove from fixed-length list");
  }

  E removeLast() {
    throw new UnsupportedError("Cannot remove from fixed-length list");
  }

  void removeWhere(bool test(E element)) {
    throw new UnsupportedError("Cannot remove from fixed-length list");
  }

  void retainWhere(bool test(E element)) {
    throw new UnsupportedError("Cannot remove from fixed-length list");
  }

  Iterable<E> getRange(int start, int end) {
    throw new UnimplementedError("_ConstantList.getRange");
  }

  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    throw new UnsupportedError("Cannot modify an unmodifiable list");
  }

  void removeRange(int start, int end) {
    throw new UnsupportedError("Cannot remove from fixed-length list");
  }

  void fillRange(int start, int end, [E fillValue]) {
    throw new UnsupportedError("Cannot modify an unmodifiable list");
  }

  void replaceRange(int start, int end, Iterable<E> replacement) {
    throw new UnsupportedError("Cannot remove from fixed-length list");
  }

  Map<int, E> asMap() {
    throw new UnimplementedError("_ConstantList.asMap");
  }
}

class _FixedList<E> extends _ConstantList<E> {
  _FixedList([int length])
      : super(length);

  void sort([int compare(E a, E b)]) {
    throw new UnimplementedError("_FixedList.sort");
  }

  void shuffle([Random random]) {
    throw new UnimplementedError("_FixedList.shuffle");
  }

  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    _Lists.setRange(this, start, end, iterable, skipCount);
  }

  void fillRange(int start, int end, [E fillValue]) {
    RangeError.checkValidRange(start, end, length);
    for (int i = start; i < end; i++) {
      this[i] = fillValue;
    }
  }

  @native E operator[]=(int index, value) {
    switch (nativeError) {
      case wrongArgumentType:
        throw new ArgumentError(index);

      case indexOutOfBounds:
        throw new IndexError(index, this);
    }
  }
}

class _GrowableList<E> extends ListBase<E> implements List<E> {
  int _length;
  _FixedList<E> _list;

  _GrowableList()
      : _length = 0,
        _list = new _FixedList<E>(4);

  int get length => _length;

  void add(E value) {
    _FixedList<E> list = _list;
    int length = _length;
    int newLength = length + 1;
    if (length >= list.length) {
      list = _grow(newLength);
    }
    list[length] = value;
    _length = newLength;
  }

  E operator[](int index) {
    if (index is! int) throw new ArgumentError(index);
    if (index >= _length) throw new IndexError(index, this);
    return _list[index];
  }

  void operator[]=(int index, value) {
    if (index >= length) throw new IndexError(index, this);
    return _list[index] = value;
  }

  void set length(int newLength) {
    if (newLength > _list.length) {
      _grow(newLength);
    }
    _length = newLength;
  }

  void addAll(Iterable<E> iterable) {
    iterable.forEach((E each) {
      add(each);
    });
  }

  void clear() {
    if (_length != 0) {
      _length = 0;
      _list = new _FixedList(4);
    }
  }

  bool remove(Object value) {
    List list = _list;
    int length = _length;
    for (int i = 0; i < length; ++i) {
      if (list[i] == value) {
        _shiftDown(i, length);
        return true;
      }
    }
    return false;
  }

  E removeAt(int index) {
    int length = _length;
    if (index >= length) throw new IndexError(index, this);
    E result = _list[index];
    _shiftDown(index, length);
    return result;
  }

  E removeLast() {
    int index = _length - 1;
    if (index < 0) throw new IndexError(index, this);
    List list = _list;
    E result = list[index];
    list[index] = null;
    _length = index;
    return result;
  }

  void removeWhere(bool test(E element)) {
    for (int i = 0; i < _length; i++) {
      if (test(this[i])) removeAt(i);
    }
  }

  void retainWhere(bool test(E element)) {
    for (int i = 0; i < _length; i++) {
      if (!test(this[i])) removeAt(i);
    }
  }

  _FixedList<E> _grow(minSize) {
    // TODO(ager): play with heuristics here.
    var newList = new _FixedList<E>(minSize + (minSize >> 2));
    for (int i = 0; i < _list.length; ++i) {
      newList[i] = _list[i];
    }
    return _list = newList;
  }

  void _shiftDown(int i, int length) {
    _FixedList<E> list = _list;
    --length;
    while (i < length) {
      int j = i + 1;
      list[i] = list[j];
      i = j;
    }
    _length = length;
    list[length] = null;
  }
}
