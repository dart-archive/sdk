// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test to open a TCP connection to a fixed host and port, send, and receive
// data.

import 'dart:dartino';
import 'package:stm32f746g_disco/ethernet.dart';
import 'package:stm32f746g_disco/socket.dart';
import 'dart:typed_data';

ByteBuffer createBuffer(int length) {
  var list = new Uint8List(length);
  for (int i = 0; i < length; i++) {
    list[i] = i & 0xFF;
  }
  return list.buffer;
}

String formatBuffer(ByteBuffer buffer) {
  return buffer.asUint8List()
          .map((int i) => i.toRadixString(16))
          .map((String s) => s.length == 2 ? '0x$s' : '0x0$s')
          .join(' ');
}

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

  print('Network interface is up.');
  try {
    Socket s = new Socket.connect("192.168.0.2", 5001);
    print('Socket connected.');
    ByteBuffer buffer = createBuffer(5);
    int bytesWritten = s.write(buffer);
    print('Wrote $bytesWritten bytes');
    buffer = s.readNext();
    if (buffer != null) {
      int bytesRead = buffer.lengthInBytes;
      print('Read $bytesRead bytes: ${formatBuffer(buffer)}');
    } else {
      print('Socket closed by peer.');
    }
    s.shutdown();
    s.close();
  } on SocketException catch (e) {
    print('Caught exception: $e.');
  }

  print('Program finished');
  while (true) {
    sleep(100);
  }
}
