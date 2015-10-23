// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.fletch._system;

// TODO(ajohnsen): Temp hack to expose _GrowableList/_FixedList to core.
List newList(int length) {
  return (length == null) ? new _GrowableList() : new _FixedList(length);
}

abstract class _FixedListBase<E>
    extends Object with ListMixin<E>
    implements List<E> {
  final _list;

  _FixedListBase([int length])
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
}

class _ConstantList<E> extends _FixedListBase<E> with UnmodifiableListMixin<E> {
}

class _ConstantByteList<E> extends _ConstantList<E> {
  @native E operator[](int index) {
    switch (nativeError) {
      case wrongArgumentType:
        throw new ArgumentError(index);

      case indexOutOfBounds:
        throw new IndexError(index, this);
    }
  }
}

class _FixedList<E> extends _FixedListBase<E> with FixedLengthListMixin<E> {
  _FixedList([int length])
      : super(length);

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
  int _length = 0;
  _FixedList<E> _list = new _FixedList<E>(4);

  _GrowableList();

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
    int length = this.length;
    Iterator it = iterable.iterator;
    if (!it.moveNext()) return;
    do {
      int capacity = _list.length;
      while (length < capacity) {
        int newLength = length + 1;
        _length = newLength;
        _list[length] = it.current;
        if (!it.moveNext()) return;
        if (this.length != newLength) {
          throw new ConcurrentModificationError(this);
        }
        length = newLength;
      }
      _grow(capacity * 2);
    } while (true);
  }

  void forEach(f(E element)) {
    int initialLength = length;
    for (int i = 0; i < length; i++) {
      f(this[i]);
      if (length != initialLength) throw new ConcurrentModificationError(this);
    }
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
    E result = this[index];
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
    for (int i = 0; i < _length;) {
      if (test(this[i])) {
        removeAt(i);
      } else {
        i++;
      }
    }
  }

  void retainWhere(bool test(E element)) {
    for (int i = 0; i < _length;) {
      if (!test(this[i])) {
        removeAt(i);
      } else {
        i++;
      }
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
