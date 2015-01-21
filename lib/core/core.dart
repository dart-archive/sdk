// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.core;

import 'dart:ffi';

part 'annotations.dart';
part 'comparable.dart';
part 'coroutine.dart';
part 'double.dart';
part 'error.dart';
part 'expando.dart';
part 'integer.dart';
part 'iterable.dart';
part 'list.dart';
part 'map.dart';
part 'messaging.dart';
part 'num.dart';
part 'print.dart';
part 'process.dart';
part 'string.dart';
part 'thread.dart';
part 'time.dart';
part 'unimplemented.dart';

// Matches dart:core on Jan 21, 2015.
external bool identical(Object a, Object b);

// Matches dart:core on Jan 21, 2015.
int identityHashCode(Object object) {
  throw new UnimplementedError("identityHashCode");
}

class Object {
  // TODO(ajohnsen): Handle this in const_interpreter.cc?
  const Object();

  bool operator ==(other) => identical(this, other);
  String toString() => "an object";

  noSuchMethod(invocation) {
    throw new NoSuchMethodError._empty();
  }

  // The noSuchMethod helper is automatically called from the
  // trampoline and it is passed the selector. The arguments
  // to the original call are still present on the stack, so
  // it is possible to dig them out if need be.
  _noSuchMethod(selector) => noSuchMethod(null);

  // The noSuchMethod trampoline is automatically generated
  // by the compiler. It calls the noSuchMethod helper and
  // takes care off removing an arbitrary number of arguments
  // from the caller stack before it returns.
  external _noSuchMethodTrampoline();

  bool _compareEqFromInteger(int other) => false;
  bool _compareEqFromDouble(double other) => false;
}

class Pattern {
}

// Matches dart:core on Jan 21, 2015.
abstract class Function {
  static apply(Function function,
               List positionalArguments,
              [Map<Symbol, dynamic> namedArguments]) {
    throw new UnimplementedError("Function.apply");
  }
}

// Matches dart:core on Jan 21, 2015.
abstract class Invocation {
  bool get isAccessor;

  bool get isGetter;

  bool get isMethod;

  bool get isSetter;

  Symbol get memberName;

  Map<Symbol, dynamic> get namedArguments;

  List get positionalArguments;
}

class Null {
  String toString() => "null";
}

class bool {
  String toString() => this ? "true" : "false";
}

class Symbol {
  final String _name;

  const Symbol(String name) : _name = name;

  bool operator ==(Symbol other) {
    return _name == other._name;
  }

  String toString() => _name;
}

class Type {
  Type._internal();
}

class _Type implements Type {
  final String _name;
  const _Type(this._name);
  String toString() => _name;
}

class StackTrace {
}
