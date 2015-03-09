// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
abstract class List<E> implements Iterable<E> {
  factory List([int length]) {
    return (length == null) ? new _GrowableList() : new _FixedList(length);
  }

  factory List.filled(int length, E fill) {
    var result = new List<E>(length);
    if (fill != null) {
      for (var i = 0; i < length; ++i) {
        result[i] = fill;
      }
    }
    return result;
  }

  factory List.from(Iterable other, { bool growable: true }) {
    List result = [];
    other.forEach((each) => result.add(each));
    return growable ? result : result.toList(false);
  }

  factory List.generate(int length, E generator(int index),
                       { bool growable: true }) {
    var result;
    if (growable) {
      result = <E>[];
      result.length = length;
    } else {
      result = new List<E>(length);
    }
    for (var i = 0; i < length; ++i) {
      result[i] = generator(i);
    }
    return result;
  }

  E operator[](int index);

  void operator[]=(int index, E value);

  int get length;

  void set length(int newLength);

  void add(E value);

  void addAll(Iterable<E> iterable);

  Iterable<E> get reversed;

  void sort([int compare(E a, E b)]);

  void shuffle([Random random]);

  int indexOf(E element, [int start = 0]);

  int lastIndexOf(E element, [int start]);

  void clear();

  void insert(int index, E element);

  void insertAll(int index, Iterable<E> iterable);

  void setAll(int index, Iterable<E> iterable);

  bool remove(Object value);

  E removeAt(int index);

  E removeLast();

  void removeWhere(bool test(E element));

  void retainWhere(bool test(E element));

  List<E> sublist(int start, [int end]);

  Iterable<E> getRange(int start, int end);

  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]);

  void removeRange(int start, int end);

  void fillRange(int start, int end, [E fillValue]);

  void replaceRange(int start, int end, Iterable<E> replacement);

  Map<int, E> asMap();
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

class _ConstantList<E> extends IterableBase<E> implements List<E> {
  final _list;

  _ConstantList(int length) : this._list = _new(length);

  Iterator<E> get iterator => new _ListIterator(this);

  Iterable expand(Iterable f(E element)) {
    throw new UnimplementedError("_ConstantList.expand");
  }

  int get length native;

  int get isEmpty => length == 0;

  int get isNotEmpty => length != 0;

  E get first {
    if (length == 0) throw new StateError("No element");
    return this[0];
  }

  E get last {
    if (length == 0) throw new StateError("No element");
    return this[length - 1];
  }

  E get single {
    if (length == 0) throw new StateError("No element");
    if (length != 1) throw new StateError("Too many elements");
    return this[0];
  }

  E elementAt(int index) {
    if (index is! int) throw new ArgumentError('$index');
    return this[index];
  }

  E operator[](int index) native catch (error) {
    switch (error) {
      case _wrongArgumentType:
        throw new ArgumentError();
      case _indexOutOfBounds:
        throw new IndexError(index, this);
    }
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

  int indexOf(E element, [int start = 0]) {
    if (start >= length) return -1;
    if (start < 0) start = 0;
    for (int i = start; i < length; i++) {
      if (this[i] == element) return i;
    }
    return -1;
  }

  int lastIndexOf(E element, [int start]) {
    if (start == null) start = length - 1;
    if (start < 0) return -1;
    if (start >= length) start = length - 1;
    for (int i = start; i >= 0; i--) {
      if (this[i] == element) {
        return i;
      }
    }
    return -1;
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

  List<E> sublist(int start, [int end]) {
    var result = new List();
    for (int i = start; i < end; i++) {
      result.add(this[i]);
    }
    return result;
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

  String toString() => "List";

  static _ConstantList _new(int length) native;
}

class _FixedList<E> extends _ConstantList<E> {
  _FixedList([int length]) : super(length);

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

  E operator[]=(int index, value) native catch (error) {
    switch (error) {
      case _wrongArgumentType:
        throw new ArgumentError();
      case _indexOutOfBounds:
        throw new IndexError(index, this);
    }
  }
}

class _GrowableList<E> extends IterableBase<E> implements List<E> {
  int _length;
  _FixedList _list;

  _GrowableList() : _length = 0, _list = new _FixedList(4);

  Iterator<E> get iterator => new _ListIterator(this);

  Iterable expand(Iterable f(E element)) {
    throw new UnimplementedError("_GrowableList.expand");
  }

  int get length => _length;

  int get isEmpty => _length == 0;

  int get isNotEmpty => _length != 0;

  E get first {
    if (length == 0) throw new StateError("No element");
    return this[0];
  }

  E get last {
    if (length == 0) throw new StateError("No element");
    return this[length - 1];
  }

  E get single {
    if (length == 0) throw new StateError("No element");
    if (length != 1) throw new StateError("Too many elements");
    return this[0];
  }

  E elementAt(int index) {
    if (index is! int) throw new ArgumentError('$index');
    return this[index];
  }

  E operator[](int index) {
    if (index >= length) throw new IndexError(index, this);
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

  void add(E value) {
    List list = _list;
    int length = _length;
    int newLength = length + 1;
    if (length >= list.length) {
      list = _grow(newLength);
    }
    list[length] = value;
    _length = newLength;
  }

  void addAll(Iterable<E> iterable) {
    iterable.forEach((E each) {
      add(each);
    });
  }

  Iterable<E> get reversed {
    throw new UnimplementedError("_GrowableList.reversed");
  }

  void sort([int compare(E a, E b)]) {
    if (compare == null) {
      compare = Comparable.compare;
    }
    _Sort.sort(this, compare);
  }

  void shuffle([Random random]) {
    throw new UnimplementedError("_GrowableList.shuffle");
  }

  int indexOf(E element, [int start = 0]) {
    if (start >= length) return -1;
    if (start < 0) start = 0;
    for (int i = start; i < length; i++) {
      if (this[i] == element) return i;
    }
    return -1;
  }

  int lastIndexOf(E element, [int start]) {
    if (start == null) start = length - 1;
    if (start < 0) return -1;
    if (start >= length) start = length - 1;
    for (int i = start; i >= 0; i--) {
      if (this[i] == element) {
        return i;
      }
    }
    return -1;
  }

  void clear() {
    if (_length != 0) {
      _length = 0;
      _list = new _FixedList(4);
    }
  }

  void insert(int index, E element) {
    throw new UnimplementedError("_GrowableList.insert");
  }

  void insertAll(int index, Iterable<E> iterable) {
    throw new UnimplementedError("_GrowableList.insertAll");
  }

  void setAll(int index, Iterable<E> iterable) {
    throw new UnimplementedError("_GrowableList.setAll");
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

  List<E> sublist(int start, [int end]) {
    var result = new List();
    for (int i = start; i < end; i++) {
      result.add(this[i]);
    }
    return result;
  }

  Iterable<E> getRange(int start, int end) {
    throw new UnimplementedError("_GrowableList.getRange");
  }

  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    _Lists.setRange(this, start, end, iterable, skipCount);
  }

  void removeRange(int start, int end) {
    RangeError.checkValidRange(start, end, length);
    for (int i = 0; i < length - end; i++) {
      this[start + i] = this[end + i];
    }
    length -= (end - start);
  }

  void fillRange(int start, int end, [E fillValue]) {
    RangeError.checkValidRange(start, end, length);
    for (int i = start; i < end; i++) {
      this[i] = fillValue;
    }
  }

  void replaceRange(int start, int end, Iterable<E> replacement) {
    throw new UnimplementedError("_GrowableList.replaceRange");
  }

  Map<int, E> asMap() {
    throw new UnimplementedError("_GrowableList.asMap");
  }

  String toString() => "List";

  _FixedList _grow(minSize) {
    // TODO(ager): play with heuristics here.
    var newList = new _FixedList(minSize + (minSize >> 2));
    for (int i = 0; i < _list.length; ++i) {
      newList[i] = _list[i];
    }
    return _list = newList;
  }

  void _shiftDown(int i, int length) {
    List list = _list;
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

class _ListIterator<E> implements Iterator<E> {
  final List _list;

  int _index = -1;
  E _current;

  _ListIterator(this._list);

  E get current => _current;

  bool moveNext() {
    if (++_index < _list.length) {
      _current = _list[_index];
      return true;
    }
    _current = null;
    return false;
  }
}

/**
 * Dual-Pivot Quicksort algorithm.
 *
 * This class implements the dual-pivot quicksort algorithm as presented in
 * Vladimir Yaroslavskiy's paper.
 *
 * Some improvements have been copied from Android's implementation.
 */
class _Sort {
  // When a list has less then [:_INSERTION_SORT_THRESHOLD:] elements it will
  // be sorted by an insertion sort.
  static const int _INSERTION_SORT_THRESHOLD = 32;

  /**
   * Sorts all elements of the given list [:a:] according to the given
   * [:compare:] function.
   *
   * The [:compare:] function takes two arguments [:x:] and [:y:] and returns
   *  -1 if [:x < y:],
   *   0 if [:x == y:], and
   *   1 if [:x > y:].
   *
   * The function's behavior must be consistent. It must not return different
   * results for the same values.
   */
  static void sort(List a, int compare(a, b)) {
    _doSort(a, 0, a.length - 1, compare);
  }

  /**
   * Sorts all elements in the range [:from:] (inclusive) to [:to:] (exclusive)
   * of the given list [:a:].
   *
   * If the given range is invalid an "OutOfRange" error is raised.
   * TODO(floitsch): do we want an error?
   *
   * See [:sort:] for requirements of the [:compare:] function.
   */
  static void sortRange(List a, int from, int to, int compare(a, b)) {
    if ((from < 0) || (to > a.length) || (to < from)) {
      throw "OutOfRange";
    }
    _doSort(a, from, to - 1, compare);
  }

  /**
   * Sorts the list in the interval [:left:] to [:right:] (both inclusive).
   */
  static void _doSort(List a, int left, int right, int compare(a, b)) {
    if ((right - left) <= _INSERTION_SORT_THRESHOLD) {
      _insertionSort(a, left, right, compare);
    } else {
      _dualPivotQuicksort(a, left, right, compare);
    }
  }

  static void _insertionSort(List a, int left, int right, int compare(a, b)) {
    for (int i = left + 1; i <= right; i++) {
      var el = a[i];
      int j = i;
      while ((j > left) && (compare(a[j - 1], el) > 0)) {
        a[j] = a[j - 1];
        j--;
      }
      a[j] = el;
    }
  }

  static void _dualPivotQuicksort(List a,
                                  int left, int right,
                                  int compare(a, b)) {
    assert(right - left > _INSERTION_SORT_THRESHOLD);

    // Compute the two pivots by looking at 5 elements.
    int sixth = (right - left + 1) ~/ 6;
    int index1 = left + sixth;
    int index5 = right - sixth;
    int index3 = (left + right) ~/ 2;  // The midpoint.
    int index2 = index3 - sixth;
    int index4 = index3 + sixth;

    var el1 = a[index1];
    var el2 = a[index2];
    var el3 = a[index3];
    var el4 = a[index4];
    var el5 = a[index5];

    // Sort the selected 5 elements using a sorting network.
    if (compare(el1, el2) > 0) { var t = el1; el1 = el2; el2 = t; }
    if (compare(el4, el5) > 0) { var t = el4; el4 = el5; el5 = t; }
    if (compare(el1, el3) > 0) { var t = el1; el1 = el3; el3 = t; }
    if (compare(el2, el3) > 0) { var t = el2; el2 = el3; el3 = t; }
    if (compare(el1, el4) > 0) { var t = el1; el1 = el4; el4 = t; }
    if (compare(el3, el4) > 0) { var t = el3; el3 = el4; el4 = t; }
    if (compare(el2, el5) > 0) { var t = el2; el2 = el5; el5 = t; }
    if (compare(el2, el3) > 0) { var t = el2; el2 = el3; el3 = t; }
    if (compare(el4, el5) > 0) { var t = el4; el4 = el5; el5 = t; }

    var pivot1 = el2;
    var pivot2 = el4;

    // el2 and el4 have been saved in the pivot variables. They will be written
    // back, once the partioning is finished.
    a[index1] = el1;
    a[index3] = el3;
    a[index5] = el5;

    a[index2] = a[left];
    a[index4] = a[right];

    int less = left + 1;    // First element in the middle partition.
    int great = right - 1;  // Last element in the middle partition.

    bool pivots_are_equal = (compare(pivot1, pivot2) == 0);
    if (pivots_are_equal) {
      var pivot = pivot1;
      // Degenerated case where the partioning becomes a dutch national flag
      // problem.
      //
      // [ |  < pivot  | == pivot | unpartitioned | > pivot  | ]
      //  ^             ^          ^             ^            ^
      // left         less         k           great         right
      //
      // a[left] and a[right] are undefined and are filled after the
      // partitioning.
      //
      // Invariants:
      //   1) for x in ]left, less[ : x < pivot.
      //   2) for x in [less, k[ : x == pivot.
      //   3) for x in ]great, right[ : x > pivot.
      for (int k = less; k <= great; k++) {
        var ak = a[k];
        int comp = compare(ak, pivot);
        if (comp == 0) continue;
        if (comp < 0) {
          if (k != less) {
            a[k] = a[less];
            a[less] = ak;
          }
          less++;
        } else {
          // comp > 0.
          //
          // Find the first element <= pivot in the range [k - 1, great] and
          // put [:ak:] there. We know that such an element must exist:
          // When k == less, then el3 (which is equal to pivot) lies in the
          // interval. Otherwise a[k - 1] == pivot and the search stops at k-1.
          // Note that in the latter case invariant 2 will be violated for a
          // short amount of time. The invariant will be restored when the
          // pivots are put into their final positions.
          while (true) {
            comp = compare(a[great], pivot);
            if (comp > 0) {
              great--;
              // This is the only location in the while-loop where a new
              // iteration is started.
              continue;
            } else if (comp < 0) {
              // Triple exchange.
              a[k] = a[less];
              a[less++] = a[great];
              a[great--] = ak;
              break;
            } else {
              // comp == 0;
              a[k] = a[great];
              a[great--] = ak;
              // Note: if great < k then we will exit the outer loop and fix
              // invariant 2 (which we just violated).
              break;
            }
          }
        }
      }
    } else {
      // We partition the list into three parts:
      //  1. < pivot1
      //  2. >= pivot1 && <= pivot2
      //  3. > pivot2
      //
      // During the loop we have:
      // [ | < pivot1 | >= pivot1 && <= pivot2 | unpartitioned  | > pivot2  | ]
      //  ^            ^                        ^              ^             ^
      // left         less                     k              great        right
      //
      // a[left] and a[right] are undefined and are filled after the
      // partitioning.
      //
      // Invariants:
      //   1. for x in ]left, less[ : x < pivot1
      //   2. for x in [less, k[ : pivot1 <= x && x <= pivot2
      //   3. for x in ]great, right[ : x > pivot2
      for (int k = less; k <= great; k++) {
        var ak = a[k];
        int comp_pivot1 = compare(ak, pivot1);
        if (comp_pivot1 < 0) {
          if (k != less) {
            a[k] = a[less];
            a[less] = ak;
          }
          less++;
        } else {
          int comp_pivot2 = compare(ak, pivot2);
          if (comp_pivot2 > 0) {
            while (true) {
              int comp = compare(a[great], pivot2);
              if (comp > 0) {
                great--;
                if (great < k) break;
                // This is the only location inside the loop where a new
                // iteration is started.
                continue;
              } else {
                // a[great] <= pivot2.
                comp = compare(a[great], pivot1);
                if (comp < 0) {
                  // Triple exchange.
                  a[k] = a[less];
                  a[less++] = a[great];
                  a[great--] = ak;
                } else {
                  // a[great] >= pivot1.
                  a[k] = a[great];
                  a[great--] = ak;
                }
                break;
              }
            }
          }
        }
      }
    }

    // Move pivots into their final positions.
    // We shrunk the list from both sides (a[left] and a[right] have
    // meaningless values in them) and now we move elements from the first
    // and third partition into these locations so that we can store the
    // pivots.
    a[left] = a[less - 1];
    a[less - 1] = pivot1;
    a[right] = a[great + 1];
    a[great + 1] = pivot2;

    // The list is now partitioned into three partitions:
    // [ < pivot1   | >= pivot1 && <= pivot2   |  > pivot2   ]
    //  ^            ^                        ^             ^
    // left         less                     great        right

    // Recursive descent. (Don't include the pivot values.)
    _doSort(a, left, less - 2, compare);
    _doSort(a, great + 2, right, compare);

    if (pivots_are_equal) {
      // All elements in the second partition are equal to the pivot. No
      // need to sort them.
      return;
    }

    // In theory it should be enough to call _doSort recursively on the second
    // partition.
    // The Android source however removes the pivot elements from the recursive
    // call if the second partition is too large (more than 2/3 of the list).
    if (less < index1 && great > index5) {
      while (compare(a[less], pivot1) == 0) { less++; }
      while (compare(a[great], pivot2) == 0) { great--; }

      // Copy paste of the previous 3-way partitioning with adaptions.
      //
      // We partition the list into three parts:
      //  1. == pivot1
      //  2. > pivot1 && < pivot2
      //  3. == pivot2
      //
      // During the loop we have:
      // [ == pivot1 | > pivot1 && < pivot2 | unpartitioned  | == pivot2 ]
      //              ^                      ^              ^
      //            less                     k              great
      //
      // Invariants:
      //   1. for x in [ *, less[ : x == pivot1
      //   2. for x in [less, k[ : pivot1 < x && x < pivot2
      //   3. for x in ]great, * ] : x == pivot2
      for (int k = less; k <= great; k++) {
        var ak = a[k];
        int comp_pivot1 = compare(ak, pivot1);
        if (comp_pivot1 == 0) {
          if (k != less) {
            a[k] = a[less];
            a[less] = ak;
          }
          less++;
        } else {
          int comp_pivot2 = compare(ak, pivot2);
          if (comp_pivot2 == 0) {
            while (true) {
              int comp = compare(a[great], pivot2);
              if (comp == 0) {
                great--;
                if (great < k) break;
                // This is the only location inside the loop where a new
                // iteration is started.
                continue;
              } else {
                // a[great] < pivot2.
                comp = compare(a[great], pivot1);
                if (comp < 0) {
                  // Triple exchange.
                  a[k] = a[less];
                  a[less++] = a[great];
                  a[great--] = ak;
                } else {
                  // a[great] == pivot1.
                  a[k] = a[great];
                  a[great--] = ak;
                }
                break;
              }
            }
          }
        }
      }
      // The second partition has now been cleared of pivot elements and looks
      // as follows:
      // [  *  |  > pivot1 && < pivot2  | * ]
      //        ^                      ^
      //       less                  great
      // Sort the second partition using recursive descent.
      _doSort(a, less, great, compare);
    } else {
      // The second partition looks as follows:
      // [  *  |  >= pivot1 && <= pivot2  | * ]
      //        ^                        ^
      //       less                    great
      // Simply sort it by recursive descent.
      _doSort(a, less, great, compare);
    }
  }
}
