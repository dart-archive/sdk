// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// FletchDebuggerCommands=b,r,s,finish,s,s,s,s,finish,s,s,s,s,finish,s,s,s,s,s,finish,b y,s,s,finish,c

class A {
  int _x = 32;
  int get x => _x;
  int y() => 32 + 32 + _x;
  int z() => y();
}

int foo() => 32;

main() {
  foo();
  32 + 32 + foo();
  var a = new A();
  a.x;
  a.y();
  a.z();
  1;
}
