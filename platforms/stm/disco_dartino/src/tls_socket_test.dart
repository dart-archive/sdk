// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Wrapper for the TLS socket sample that initializes the ethernet adapter
// before using sockets.

import 'dart:dartino' show sleep;
import 'package:stm32/ethernet.dart';
import '../../../../samples/general/tls-socket.dart' as sample;

main() {
  if (!ethernet.InitializeNetworkStack(
    const InternetAddress(const <int>[192, 168, 0, 10]),
    const InternetAddress(const <int>[255, 255, 255, 0]),
    const InternetAddress(const <int>[192, 168, 0, 1]),
    const InternetAddress(const <int>[8, 8, 8, 8]))) {
    throw 'Failed to initialize network stack';
  }

  while (NetworkInterface.list().isEmpty) {
    sleep(10);
  }

  sample.main();
}
