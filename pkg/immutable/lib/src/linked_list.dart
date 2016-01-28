// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of immutable;

// TODO(kustermann): Consider making a sentinal for an empty list instead of
// representing empty lists as `null`.
class LinkedList<T> {
  final T head;
  final LinkedList<T> tail;

  const LinkedList(this.head, this.tail);

  factory LinkedList.fromList(List<T> list) {
    if (list == null || list.isEmpty) {
      return null;
    }

    LinkedList<T> current = new LinkedList(list.last, null);
    for (int i = list.length - 2; i >= 0; i--) {
      current = current.prepend(list[i]);
    }
    return current;
  }

  LinkedList<T> prepend(T value) => new LinkedList(value, this);

  int get length {
    int count = 1;
    LinkedList<T> current = tail;
    while (current != null) {
      count++;
      current = current.tail;
    }
    return count;
  }
}
