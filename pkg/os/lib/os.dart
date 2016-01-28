// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Access to the operating system. Only supported when Fletch is running on a
/// Posix platform.
///
/// Usage
/// -----
/// ```dart
/// import 'package:os/os.dart';
///
/// main() {
///   SystemInformation si = sys.info();
///   print('Hello from ${si.operatingSystemName} running on ${si.nodeName}.');
/// }
/// ```
///
/// Reporting issues
/// ----------------
/// Please file an issue [in the issue
/// tracker](https://github.com/dart-lang/fletch/issues/new?title=Add%20title&labels=Area-Package&body=%3Cissue%20description%3E%0A%3Crepro%20steps%3E%0A%3Cexpected%20outcome%3E%0A%3Cactual%20outcome%3E).
library os;

import 'dart:fletch';
import 'dart:fletch.ffi';
import 'dart:fletch.os' as os;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

part 'errno.dart';

part 'net_structs.dart';
part 'net_structs_android.dart';
part 'net_structs_linux.dart';
part 'net_structs_macos.dart';
part 'net_structs_posix.dart';

part 'system.dart';
part 'system_linux.dart';
part 'system_macos.dart';
part 'system_posix.dart';

abstract class InternetAddress {
  factory InternetAddress(List<int> bytes) = _InternetAddress;
  bool get isIP4;
}

// TODO(ajohnsen): Take a Duration?
void sleep(int milliseconds) => sys.sleep(milliseconds);
int errno() => sys.errno();
