// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// DartinoDebuggerCommands=r,bt,t internal,bt,q

// Tests that stack traces work in the debugger when there are
// no visible frames (in that case 'bt' doesn't print anything).
// This program will hit a compile-time error when calling
// main in internal non-user code.
void main(a, b, c) {}