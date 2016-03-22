// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.dartino._system;

import 'dart:_internal' hide Symbol;
import 'dart:collection';
import 'dart:dartino';
import 'dart:dartino._ffi';

part 'list.dart';
part 'map.dart';
part 'nsm.dart';

const native = "native";

class _Patch {
  const _Patch();
}

const patch = const _Patch();

const bool enableBigint =
    const bool.fromEnvironment('dartino.enable-bigint', defaultValue: true);

// These strings need to be kept in sync with the strings allocated
// for the raw failure objects in src/vm/program.cc.
const wrongArgumentType = "Wrong argument type.";
const indexOutOfBounds = "Index out of bounds.";
const illegalState = "Illegal state.";

// This enum must be kept in sync with the Interpreter::InterruptKind
// enum in src/vm/interpreter.h.
enum InterruptKind {
  ready,
  terminate,
  interrupt,
  yield,
  targetYield,
  uncaughtException,
  compileTimeError,
  breakPoint,
  ffiReturn,
}

class _Arguments
    extends Object with UnmodifiableListMixin<String>, ListMixin<String>
    implements List<String> {

  _Arguments();

  @native external int get length;

  String operator[](int index) {
    return _toString(index);
  }

  @native external static String _toString(int index);
}

/// This is a magic method recognized by the compiler, and references to it
/// will be substituted for the actual main method.
/// [arguments] is supposed to be a List<String> with command line arguments.
/// [isolateArgument] is an extra argument that can be passed via
/// [Isolate.spawnUri].
external invokeMain([arguments, isolateArgument]);

// Trivial wrapper around invokeMain to have a frame to restart from
// if we want to restart main.
// TODO(ager): Get rid of this wrapper.
callMain(arguments) => invokeMain(arguments);

/// This is the entry point for the Dartino intepreter.
///
/// This function is called:
/// - when the program starts, as the main entry point for the Dartino program,
/// - for FFI callbacks, in which case it redirects to the correct Dart closure.
///
/// When it is invoked at the program start, it redirects to the `main` function
/// and exits the VM when `main` is done.
///
/// All arguments are only used for FFI callbacks.
///
/// If the [oldCoroutine] is not equal to 0, this is an entry for a FFI call.
///
/// The [errorReturnValue] is the value that is returned if the callback throws
/// an exception.
/// The [returnSlot] is used to return a value to C.
/// The [oldCoroutine] should not be used, but is passed to make the GC find the
/// object, and is used as sentinel to know if this is a FFI call.
void entry(int ffiId, int arity, arg0, arg1, arg2, returnSlot, oldCoroutine) {
  if (oldCoroutine != 0) {
    returnSlot = ForeignCallback.doFfiCallback(ffiId, arity, arg0, arg1, arg2);
    yield(InterruptKind.ffiReturn.index);
  }
  Fiber.exit(callMain(new _Arguments()));
}

runToEnd(entry) {
  Fiber.exit(entry());
}

unresolved(name) {
  throw new NoSuchMethodError(
      null,
      name,
      null,
      null);
}

compileError(String message) {
  print("Compile error: $message");
  yield(InterruptKind.compileTimeError.index);
}

halt() {
  yield(InterruptKind.terminate.index);
}

/// Make the current process yield. Either to allow other fibers to
/// make progress or to terminate execution.
external yield(int reason);

external get nativeError;

// Change execution to [coroutine], passing along [argument].
external coroutineChange(coroutine, argument);
