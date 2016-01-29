// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// FletchDebuggerCommands=r,q

main() {
  try {
    throw 42;
  } on String catch (e) {
    print('not rethrowing from here');
  }
}
