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

class LinkedHashSet<E> implements Set<E> {

  Iterator<E> get iterator {
    throw new UnimplementedError("Set.iterator");
  }

  Iterable map(f(E element)) {
    throw new UnimplementedError("Set.map");
  }

  Iterable<E> where(bool test(E element)) {
    throw new UnimplementedError("Set.where");
  }

  Iterable expand(Iterable f(E element)) {
    throw new UnimplementedError("Set.expand");
  }

  bool contains(Object element) {
    throw new UnimplementedError("Set.contains");
  }

  void forEach(void f(E element)) {
    throw new UnimplementedError("Set.forEach");
  }

  E reduce(E combine(E value, E element)) {
    throw new UnimplementedError("Set.reduce");
  }
  dynamic fold(var initialValue,
               dynamic combine(var previousValue, E element)) {
    throw new UnimplementedError("Set.fold");
  }

  bool every(bool test(E element)) {
    throw new UnimplementedError("Set.every");
  }

  String join([String separator = ""]) {
    StringBuffer buffer = new StringBuffer();
    buffer.writeAll(this, separator);
    return buffer.toString();
  }

  bool any(bool test(E element)) {
    throw new UnimplementedError("Set.any");
  }

  List<E> toList({ bool growable: true }) {
    throw new UnimplementedError("Set.toList");
  }

  Set<E> toSet() {
    throw new UnimplementedError("Set.toSet");
  }

  int get length {
    throw new UnimplementedError("Set.length");
  }

  bool get isEmpty {
    throw new UnimplementedError("Set.isEmpty");
  }

  bool get isNotEmpty {
    throw new UnimplementedError("Set.isNotEmpty");
  }

  Iterable<E> take(int n) {
    throw new UnimplementedError("Set.take");
  }

  Iterable<E> takeWhile(bool test(E value)) {
    throw new UnimplementedError("Set.takeWhile");
  }

  Iterable<E> skip(int n) {
    throw new UnimplementedError("Set.skip");
  }

  Iterable<E> skipWhile(bool test(E value)) {
    throw new UnimplementedError("Set.skipWhile");
  }

  E get first {
    throw new UnimplementedError("Set.first");
  }

  E get last {
    throw new UnimplementedError("Set.last");
  }

  E get single {
    throw new UnimplementedError("Set.single");
  }

  E firstWhere(bool test(E element), { E orElse() }) {
    throw new UnimplementedError("Set.firstWhere");
  }

  E lastWhere(bool test(E element), {E orElse()}) {
    throw new UnimplementedError("Set.lastWhere");
  }

  E singleWhere(bool test(E element)) {
    throw new UnimplementedError("Set.singleWhere");
  }

  E elementAt(int index) {
    throw new UnimplementedError("Set.elementAt");
  }

  bool add(E value) {
    throw new UnimplementedError("Set.add");
  }

  void addAll(Iterable<E> elements) {
    throw new UnimplementedError("Set.addAll");
  }

  bool remove(Object value) {
    throw new UnimplementedError("Set.remove");
  }

  E lookup(Object object) {
    throw new UnimplementedError("Set.lookup");
  }

  void removeAll(Iterable<Object> elements) {
    throw new UnimplementedError("Set.removeAll");
  }

  void retainAll(Iterable<Object> elements) {
    throw new UnimplementedError("Set.retainAll");
  }

  void removeWhere(bool test(E element)) {
    throw new UnimplementedError("Set.removeWhere");
  }

  void retainWhere(bool test(E element)) {
    throw new UnimplementedError("Set.retainWhere");
  }

  bool containsAll(Iterable<Object> other) {
    throw new UnimplementedError("Set.containsAll");
  }

  Set<E> intersection(Set<Object> other) {
    throw new UnimplementedError("Set.intersection");
  }

  Set<E> union(Set<E> other) {
    throw new UnimplementedError("Set.union");
  }

  Set<E> difference(Set<E> other) {
    throw new UnimplementedError("Set.difference");
  }

  void clear() {
    throw new UnimplementedError("Set.clear");
  }

}
