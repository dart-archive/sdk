// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Fletch operating system package.
///
/// This is a preliminary API providing access to the operating system
/// access when Fletch is running on a Posix platform.
library os;

import 'dart:fletch';
import 'dart:fletch.ffi';
import 'dart:fletch.os' as os;
import 'dart:typed_data';

part 'errno.dart';
part 'system.dart';
part 'system_android.dart';
part 'system_linux.dart';
part 'system_macos.dart';
part 'system_posix.dart';

abstract class InternetAddress {
  factory InternetAddress(List<int> bytes) = _InternetAddress;
  bool get isIp4;
}

// TODO(ajohnsen): Take a Duration?
void sleep(int milliseconds) => sys.sleep(milliseconds);
Errno errno() => sys.errno();
