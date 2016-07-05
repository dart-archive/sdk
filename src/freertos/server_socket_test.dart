// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Tests that a [ServerSocket] can be used to respond an HTTP request with a
// predefined welcome page.

import 'dart:dartino';
import 'dart:typed_data';

import 'package:stm32/ethernet.dart';
import 'package:stm32/socket.dart';

ByteBuffer stringToBuffer(String s) {
  var list = new Uint8List(s.length);
  for (int i = 0; i < s.length; i++) {
    list[i] = s.codeUnitAt(i) & 0xFF;
  }
  return list.buffer;
}

String formatBuffer(ByteBuffer buffer) {
  return buffer.asUint8List()
          .map((int i) => i.toRadixString(16))
          .map((String s) => s.length == 2 ? '0x$s' : '0x0$s')
          .join(' ');
}

const String page = '''
<html>
<body>
<h1>Hello from Dartino!</h1>
</body>
</html>
''';

String response = '''
HTTP/1.0 200 OK
Content-Type: text/html
Content-Length: ${page.length}

$page''';

const List HOST_IP = const [192, 168, 0, 10];
const String HOST_IP_STRING = "192.168.0.10";
const int HOST_PORT = 80;

void initializeNetwork() {
  if (!ethernet.initializeNetworkStack(
    const InternetAddress(HOST_IP),
    const InternetAddress(const <int>[255, 255, 255, 0]),
    const InternetAddress(const <int>[192, 168, 0, 1]),
    const InternetAddress(const <int>[8, 8, 8, 8]))) {
    throw 'Failed to initialize network stack';
  }

  while (NetworkInterface.list().first.addresses.isEmpty) {
    sleep(10);
  }

  print('Network interface is up.');
}

main() {
  initializeNetwork();

  ServerSocket socket = new ServerSocket(HOST_IP_STRING, HOST_PORT);
  while (true) {
    print('Waiting for connection');
    Socket remote = socket.accept();
    print('Connection accepted');
    ByteBuffer buffer = remote.readNext();
    remote.write(stringToBuffer(response));
    remote.close();
    print('Socket closed');
    print(formatBuffer(buffer));
  }
}
