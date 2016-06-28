// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Access to the operating system. Only supported when Dartino is running on a
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
/// tracker](https://github.com/dartino/sdk/issues/new?title=Add%20title&labels=Area-Package&body=%3Cissue%20description%3E%0A%3Crepro%20steps%3E%0A%3Cexpected%20outcome%3E%0A%3Cactual%20outcome%3E).
library os;

import 'dart:dartino';
import 'dart:dartino.ffi';
import 'dart:dartino.os' as os;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

part 'src/errno.dart';

part 'src/net_structs.dart';
part 'src/net_structs_android.dart';
part 'src/net_structs_linux.dart';
part 'src/net_structs_macos.dart';
part 'src/net_structs_posix.dart';

part 'src/system.dart';
part 'src/system_linux.dart';
part 'src/system_macos.dart';
part 'src/system_posix.dart';
part 'src/system_freertos.dart';

abstract class InternetAddress {
  factory InternetAddress(List<int> bytes) = _InternetAddress;
  bool get isIP4;
}

int errno() => sys.errno();
