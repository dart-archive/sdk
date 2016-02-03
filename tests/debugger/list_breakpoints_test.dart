// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test that the 'lb' list breakpoints command works.

// DartinoDebuggerCommands=b main,b breakHere,lb,q

void breakHere() { }

main() { breakHere(); }
