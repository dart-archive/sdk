// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
class Expando<T> {
  final String name;
  Expando(this.name);

  T operator[](Object object) {
    throw new UnimplementedError("Expando.[]");
  }

  void operator[]=(Object object, T value) {
    throw new UnimplementedError("Expando.[]=");
  }
}
