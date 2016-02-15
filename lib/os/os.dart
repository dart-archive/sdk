// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.dartino.os;

import 'dart:dartino._system' as dartino;
import 'dart:dartino';
import 'dart:dartino.ffi';

part 'native_process.dart';
part 'event_handler.dart';

final ForeignFunction _nanosleep = ForeignLibrary.main.lookup("nanosleep");

class _Timespec extends Struct {
  _Timespec() : super(2);
  int get tv_sec => getField(0);
  int get tv_nsec => getField(1);
  void set tv_sec(int value) => setField(0, value);
  void set tv_nsec(int value) => setField(1, value);
}
