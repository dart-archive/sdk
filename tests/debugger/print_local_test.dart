// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// DartinoDebuggerCommands=b breakHere,r,f 1,p,q


class A {}

breakHere() { }

main() {
  var str = 'spaß';
  var i = 42;
  var i2 = 1 << 33;
  var a = new A();
  var n;
  var d = 42.42;
  var t = true;
  var f = false;
  breakHere();
}