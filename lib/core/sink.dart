// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
abstract class Sink<T> {
  void add(T data);
  void close();
}

// Matches dart:core on Jan 21, 2015.
abstract class StringSink {
  void write(Object obj);

  void writeAll(Iterable objects, [String separator=""]);

  void writeCharCode(int charCode);

  void writeln([Object obj=""]);
}
