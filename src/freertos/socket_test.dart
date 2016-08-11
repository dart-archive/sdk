// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Test to open a TCP/UDP connection to a fixed host and port, send, and receive
// data.

import 'dart:dartino';
import 'dart:typed_data';

import 'package:stm32/ethernet.dart';
import 'package:stm32/socket.dart';

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

const List REMOTE_IP = const [192, 168, 0, 2];
const String REMOTE_IP_STRING = "192.168.0.2";
const List HOST_IP = const [192, 168, 0, 10];
const String HOST_IP_STRING = "192.168.0.10";
const int UDP_LOCAL_PORT = 4000;
const int UDP_REMOTE_PORT = 4001;
const int TCP_REMOTE_PORT = 5001;

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

void tcpSocketTest() {
  try {
    Socket s = new Socket.connect(REMOTE_IP_STRING, TCP_REMOTE_PORT);
    print('Socket connected.');
    s.close();
    print('Socket closed.');

    s = new Socket.connect(REMOTE_IP_STRING, TCP_REMOTE_PORT);
    print('Socket connected.');
    ByteBuffer buffer = createBuffer(5);
    s.write(buffer);
    print('Wrote data...');
    buffer = s.readNext();
    if (buffer != null) {
      int bytesRead = buffer.lengthInBytes;
      print('Read $bytesRead bytes: ${formatBuffer(buffer)}');
    } else {
      print('Socket closed by peer.');
    }
    s.close();
    print('Socket closed.');
  } on SocketException catch (e) {
    print('Caught exception: $e.');
  }
}

void udpSocketTest() {
  // Try that we can bind to INADDR_ANY
  new DatagramSocket.bind(IP_INADDR_ANY, 0).close();

  // Try to connect to the remote server
  try {
      DatagramSocket s = new DatagramSocket.bind(HOST_IP_STRING,
          UDP_LOCAL_PORT);
      print('Datagram socket created.');
      ByteBuffer buffer = createBuffer(5);
      // Send two messages to make it more likely that one comes through.
      for (int i = 0; i < 2; ++i) {
        int sent = s.send(new InternetAddress(REMOTE_IP), UDP_REMOTE_PORT,
            buffer);
        print('Datagram sent ($sent bytes)...');
        sleep(1000);
      }
      print('Waiting for response');
      var d = s.receive();
      print('${d.data.lengthInBytes} bytes received'
          ' from ${d.sender}:${d.port}');
      s.close();
      print('socket closed');
  } on SocketException catch (e) {
    print('Caught exception: $e.');
  }
}

main() {
  initializeNetwork();
  tcpSocketTest();
  udpSocketTest();
}
