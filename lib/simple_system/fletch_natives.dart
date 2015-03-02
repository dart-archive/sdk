// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.fletch;

import 'dart:_fletch_system'
    show native;

@native external printString(String s);

@native external halt(int code);
