// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.collection;

class LinkedHashSet<E> implements Set<E> {
  Iterator<E> get iterator {
    throw new UnimplementedError("LinkedHashSet.iterator");
  }

  Iterable map(f(E element)) {
    throw new UnimplementedError("LinkedHashSet.map");
  }

  Iterable<E> where(bool test(E element)) {
    throw new UnimplementedError("LinkedHashSet.where");
  }

  Iterable expand(Iterable f(E element)) {
    throw new UnimplementedError("LinkedHashSet.expand");
  }

  bool contains(Object element) {
    throw new UnimplementedError("LinkedHashSet.contains");
  }

  void forEach(void f(E element)) {
    throw new UnimplementedError("LinkedHashSet.forEach");
  }

  E reduce(E combine(E value, E element)) {
    throw new UnimplementedError("LinkedHashSet.reduce");
  }
  dynamic fold(var initialValue,
               dynamic combine(var previousValue, E element)) {
    throw new UnimplementedError("LinkedHashSet.fold");
  }

  bool every(bool test(E element)) {
    throw new UnimplementedError("LinkedHashSet.every");
  }

  String join([String separator = ""]) {
    StringBuffer buffer = new StringBuffer();
    buffer.writeAll(this, separator);
    return buffer.toString();
  }

  bool any(bool test(E element)) {
    throw new UnimplementedError("LinkedHashSet.any");
  }

  List<E> toList({ bool growable: true }) {
    throw new UnimplementedError("LinkedHashSet.toList");
  }

  Set<E> toSet() {
    throw new UnimplementedError("LinkedHashSet.toSet");
  }

  int get length {
    throw new UnimplementedError("LinkedHashSet.length");
  }

  bool get isEmpty {
    throw new UnimplementedError("LinkedHashSet.isEmpty");
  }

  bool get isNotEmpty {
    throw new UnimplementedError("LinkedHashSet.isNotEmpty");
  }

  Iterable<E> take(int n) {
    throw new UnimplementedError("LinkedHashSet.take");
  }

  Iterable<E> takeWhile(bool test(E value)) {
    throw new UnimplementedError("LinkedHashSet.takeWhile");
  }

  Iterable<E> skip(int n) {
    throw new UnimplementedError("LinkedHashSet.skip");
  }

  Iterable<E> skipWhile(bool test(E value)) {
    throw new UnimplementedError("LinkedHashSet.skipWhile");
  }

  E get first {
    throw new UnimplementedError("LinkedHashSet.first");
  }

  E get last {
    throw new UnimplementedError("LinkedHashSet.last");
  }

  E get single {
    throw new UnimplementedError("LinkedHashSet.single");
  }

  E firstWhere(bool test(E element), { E orElse() }) {
    throw new UnimplementedError("LinkedHashSet.firstWhere");
  }

  E lastWhere(bool test(E element), {E orElse()}) {
    throw new UnimplementedError("LinkedHashSet.lastWhere");
  }

  E singleWhere(bool test(E element)) {
    throw new UnimplementedError("LinkedHashSet.singleWhere");
  }

  E elementAt(int index) {
    throw new UnimplementedError("LinkedHashSet.elementAt");
  }

  bool add(E value) {
    throw new UnimplementedError("LinkedHashSet.add");
  }

  void addAll(Iterable<E> elements) {
    throw new UnimplementedError("LinkedHashSet.addAll");
  }

  bool remove(Object value) {
    throw new UnimplementedError("LinkedHashSet.remove");
  }

  E lookup(Object object) {
    throw new UnimplementedError("LinkedHashSet.lookup");
  }

  void removeAll(Iterable<Object> elements) {
    throw new UnimplementedError("LinkedHashSet.removeAll");
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
    throw new UnimplementedError("LinkedHashSet.clear");
  }
}
