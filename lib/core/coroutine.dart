// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

class Coroutine {

  // TODO(kasperl): The VM has assumptions about the layout
  // of coroutine fields. We should validate that the code
  // agrees with those assumptions.
  var _stack;
  var _caller;

  Coroutine(entry) {
    _stack = _coroutineNewStack(this, entry);
  }

  bool get isSuspended => identical(_caller, null);
  bool get isRunning => !isSuspended && !isDone;
  bool get isDone => identical(_caller, this);

  call(argument) {
    if (!isSuspended) throw "Cannot call non-suspended coroutine";
    _caller = _coroutineCurrent();
    var result = _coroutineChange(this, argument);

    // If the called coroutine is done now, we clear the
    // stack reference in it so the memory can be reclaimed.
    if (isDone) {
      _stack = null;
    } else {
      _caller = null;
    }
    return result;
  }

  static yield(value) {
    Coroutine caller = _coroutineCurrent()._caller;
    if (caller == null) throw "Cannot yield outside coroutine";
    return _coroutineChange(caller, value);
  }

  _coroutineStart(entry) {
    // The first call to changeStack is actually skipped but we need
    // it to make sure the newly started coroutine is suspended in
    // exactly the same way as we do when yielding.
    var argument = _coroutineChange(0, 0);
    var result = entry(argument);

    // Mark this coroutine as done and change back to the caller.
    Coroutine caller = _caller;
    _caller = this;
    _coroutineChange(caller, result);
  }

  static _coroutineCurrent() native;
  static _coroutineNewStack(coroutine, entry) native;

  // The compiler generates a special bytecode for calls to this
  // magical external method.
  external static _coroutineChange(coroutine, argument);
}
