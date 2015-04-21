// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.system;

import 'dart:core' hide
    double,
    int,
    String;

import 'dart:core' as core show
    double,
    int,
    String;

import 'dart:_internal';
import 'dart:collection';
import 'dart:math';

part 'double.dart';
part 'integer.dart';
part 'linked_hash_map.dart';
part 'linked_hash_set.dart';
part 'list.dart';
part 'map.dart';
part 'string.dart';

const native = "native";

const wrongArgumentType = "Wrong argument type.";
const indexOutOfBounds = "Index out of bounds.";
const illegalState = "Illegal state.";

/// This is a magic method recognized by the compiler, and references to it
/// will be substituted for the actual main method.
/// [arguments] is supposed to be a List<String> with command line arguments.
/// [isolateArgument] is an extra argument that can be passed via
/// [Isolate.spawnUri].
external invokeMain([arguments, isolateArgument]);

/// This is the main entry point for a Fletch program, and it takes care of
/// calling "main" and exiting the VM when "main" is done.
void entry(int mainArity) {
  Thread.exit(invokeMain([]));
}

runToEnd(entry) {
  Thread.exit(entry());
}

unresolved(name) {
  throw new NoSuchMethodError(
      null,
      name,
      null,
      null);
}

compileError() {
  print("Compile error");
  halt(254);
}

@native halt(int code) {
  yield(true);
}

/// Exits the VM cleanly.
external yield(bool halt);

external get nativeError;

// Change execution to [coroutine], passing along [argument].
external coroutineChange(coroutine, argument);
