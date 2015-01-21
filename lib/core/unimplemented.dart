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


class Uri {
  factory Uri({String scheme: "", String userInfo: "", String host, int port, String path, Iterable<String> pathSegments, String query, Map<String, String> queryParameters, String fragment})
      => throw new UnimplementedError("Uri");
  factory Uri.file(String path, {bool windows})
      => throw new UnimplementedError("Uri.file");
  factory Uri.http(String authority, String unencodedPath, [Map<String, String> queryParameters])
      => throw new UnimplementedError("Uri.http");
  factory Uri.https(String authority, String unencodedPath, [Map<String, String> queryParameters])
      => throw new UnimplementedError("Uri.https");
}
