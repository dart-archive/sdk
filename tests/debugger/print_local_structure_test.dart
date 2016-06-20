// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Get to the state where we can inspect the variables
// DartinoDebuggerCommands=b breakHere,r,f 1
// Access to local
// DartinoDebuggerCommands=p *a,p *i
// DartinoDebuggerCommands=p notExisting
// Check .fieldName operation
// DartinoDebuggerCommands=p a.s
// DartinoDebuggerCommands=p *a.s
// DartinoDebuggerCommands=p a.s.shadowMe
// DartinoDebuggerCommands=p a.s.shadowMe.a
// DartinoDebuggerCommands=p a.notExisting
// Check resolution of shadowed field
// DartinoDebuggerCommands=p a.shadowMe
// List access
// DartinoDebuggerCommands=p *list._list,p *list._list[1]
// Big list should be cut at 20 elements
// DartinoDebuggerCommands=p *bigList._list
// Slicing
// DartinoDebuggerCommands=p *list._list[1:2]
// DartinoDebuggerCommands=p *list._list[1:-1]
// DartinoDebuggerCommands=p *list._list[0:2]
// DartinoDebuggerCommands=p *list._list[1:2]
// DartinoDebuggerCommands=p *list._list[1:1]
// DartinoDebuggerCommands=p *bigList._list[100:102]
// Slicing errors
// DartinoDebuggerCommands=p *list._list[1:2][2]
// DartinoDebuggerCommands=p *list._list[1:2].a
// DartinoDebuggerCommands=p *list._list[-1:2]
// DartinoDebuggerCommands=p *list._list[1:55]
// DartinoDebuggerCommands=p *list._list[3:2]
// DartinoDebuggerCommands=p *list[3:2]
// Indexing out of bounds
// DartinoDebuggerCommands=p *list._list.[-1],
// DartinoDebuggerCommands=p *list._list.4,
// Indexing with non-int
// DartinoDebuggerCommands=p a[x]
// Accessing a field of a list
// DartinoDebuggerCommands=p *list._list.k,
// Syntax errors
// DartinoDebuggerCommands=p [4],p %%,p [1:2],p a[1e,p a.x[1]1,p a.
// Continue to end of program
// DartinoDebuggerCommands=c

class S0 {
  var str = 'spaß';
}

class S1 extends S0 {
  var i = 42;
  var i2 = 1 << 33;
}

class S2 extends S1 {
  var n;
  var d = 42.42;
}

class S3 extends S2 {
  var shadowMe = 0;
}

class A extends S3 {
  var shadowMe = 42;
  var t = true;
  var f = false;
  var s = new S3();
}

breakHere() { }

main() {
  var a = new A();
  var i = 42;
  var list = new List(3);
  list[1] = a;
  list[2] = 2;
  list[0] = 1;
  var bigList = new List.generate(200, (i) => i * i, growable: false);
  breakHere();
}
