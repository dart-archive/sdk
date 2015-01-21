// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

typedef int Comparator<T>(T a, T b);

abstract class Comparable<T> {

  int compareTo(T other);

  static int compare(Comparable a, Comparable b) => a.compareTo(b);

}
