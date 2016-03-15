// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Demonstrates how to use the ethernet package.

import 'dart:dartino';
import 'package:stm32f746g_disco/ethernet.dart';

void printNetworkInfo() {
  for (NetworkInterface interface in
      NetworkInterface.list(includeLoopback: true)) {
    print("${interface.name}:");
    for (InternetAddress address in interface.addresses) {
      print("  $address");
    }
    print("  ${interface.isConnected ? 'connected' : 'not connected'}");
  }
}

main() {
  print('Hello from Dartino');
  if (!ethernet.InitializeNetworkStack(
      const InternetAddress(const <int>[192, 168, 0, 10]),
      const InternetAddress(const <int>[255, 255, 255, 0]),
      const InternetAddress(const <int>[192, 168, 0, 1]),
      const InternetAddress(const <int>[8, 8, 8, 8]))) {
    throw 'Failed to initialize network stack';
  }

  print('Network up, requesting DHCP configuration...');

  int i = 0;
  while (true) {
    printNetworkInfo();
    sleep(5000);
    i++;
    print("waited ${i*5}000 ms");
  }
}
