// Copyright (c) 2015, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import "deferred_load_library_wrong_args_lib.dart" deferred as lib;

void main() {
  // Loadlibrary should be called without arguments.
  lib.loadLibrary(
      10 /// 01: runtime error
  );
}