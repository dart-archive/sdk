// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

abstract class BidirectionalIterator<T> extends Iterator<T> {
  bool movePrevious();
}

class DateTime {
  factory DateTime(int year, [int month=1, int day=1, int hour=0, int minute=0, int second=0, int millisecond=0])
      => throw new UnimplementedError("DateTime");
  DateTime.fromMillisecondsSinceEpoch(int millisecondsSinceEpoch, {bool isUtc: false})
      => throw new UnimplementedError("DateTime.fromMillisecondsSinceEpoch");
  DateTime.now()
      => throw new UnimplementedError("DateTime.now");
  DateTime.utc(int year, [int month=1, int day=1, int hour=0, int minute=0, int second=0, int millisecond=0])
      => throw new UnimplementedError("DateTime.utc");
}

class Duration {
  const Duration({int days: 0, int hours: 0, int minutes: 0, int seconds: 0, int milliseconds: 0, int microseconds: 0});
}

class Expando {
  factory Expando([String name])
      => throw new UnimplementedError("Expando");
}

class Invocation {
  Invocation._internal();
}

abstract class Iterable<E> {
}

abstract class Match {
}

class RegExp {
  factory RegExp(String source, {bool multiLine: false, bool caseSensitive: true})
      => throw new UnimplementedError("RegExp");
}

class RuneIterator implements BidirectionalIterator<int> {
  factory RuneIterator(String string)
      => throw new UnimplementedError("RuneIterator");
  factory RuneIterator.at(String string, int index)
      => throw new UnimplementedError("RuneIterator.at");
}

class Runes {
  factory Runes(String string)
      => throw new UnimplementedError("Runes");
}

class Set {
  factory Set()
      => throw new UnimplementedError("Set");
  factory Set.from(Iterable<E> other)
      => throw new UnimplementedError("Set.from");
  factory Set.identity()
      => throw new UnimplementedError("Set.identity");
}

abstract class Sink<T> {
}

abstract class StringSink {
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
