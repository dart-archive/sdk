// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test that we get a meaningful stack trace when called from the
// event loop.

// DartinoDebuggerCommands=b breakHere,r,bt,t internal,bt,c

import 'dart:async';

void breakHere() { }

main() {
  new Future.delayed(new Duration(milliseconds: 1), breakHere);
}
