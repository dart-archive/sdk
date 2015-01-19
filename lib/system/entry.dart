// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.system;

bool _exposeGC() native;
_gc() native;

_halt(int code) native catch (error) {
  _yield(true);
}

_entry(int mainArity) {
  if (mainArity == 0) {
    _runToEnd(main);
  } else {
    var arguments = _exposeGC() ? [_gc] : [];
    _runToEnd(() => main(arguments));
  }
}

_runToEnd(entry) {
  Thread.exit(entry());
}

_unresolved(x) {
  throw new NoSuchMethodError._withName(x);
}

_processYield() => _yield(false);

external _yield(bool halt);
