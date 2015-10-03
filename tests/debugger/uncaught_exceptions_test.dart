// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// FletchDebuggerCommands=r,restart,restart,restart,restart

enum State {
  ThrowNumber,
  ThrowString,
  ThrowExceptionObject,
  ThrowCustomObject,
  AccessNoSuchMethod,
}

State state = State.ThrowNumber;

main() {
  foo();
}

foo() {
  switch (state) {
    case State.ThrowNumber:
      state = State.ThrowString;
      throw 42;
      break;
    case State.ThrowString:
      state = State.ThrowExceptionObject;
      throw 'foobar';
      break;
    case State.ThrowExceptionObject:
      state = State.ThrowCustomObject;
      throw new Exception('foobar');
      break;
    case State.ThrowCustomObject:
      state = State.AccessNoSuchMethod;
      throw new CustomException('foobar', 42);
      break;
    case State.AccessNoSuchMethod:
      var object = new MyObject();
      object.foo();
      object.bar();
      break;
  }
}

class CustomException {
  final String message;
  final int code;

  const CustomException(this.message, this.code);
}

class MyObject {
  foo() => print('foo');
}
