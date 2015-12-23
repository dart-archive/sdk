// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// throwing_program.dart is used in rerun_throwing_program_test.dart.
// Test that trying to run a program with uncaught exception provides correct
// error message.

main () {
  throw 42;
}