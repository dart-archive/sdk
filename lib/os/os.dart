// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.fletch.os;

import 'dart:fletch';
import 'dart:fletch.ffi';
import 'dart:typed_data';
import 'dart:_fletch_system' as fletch;

part 'errno.dart';
part 'native_process.dart';
part 'system.dart';
part 'system_android.dart';
part 'system_linux.dart';
part 'system_macos.dart';
part 'system_posix.dart';

abstract class InternetAddress { }
