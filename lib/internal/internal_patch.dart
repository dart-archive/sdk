// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino._system' as dartino;
import 'dart:dartino._system' show patch;

@patch @dartino.native external void printToConsole(String line);

@patch class Symbol {
  // TODO(ajohnsen): Decide what to do with 'name'.
  @patch const Symbol(String name) : _name = name;

  @patch int get hashCode {
    const arbitraryPrime = 664597;
    return 0x1fffffff & (arbitraryPrime * _name.hashCode);
  }
}
