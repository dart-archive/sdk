// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';
import 'dart:typed_data';

import 'package:socket/socket.dart';

import '../BenchmarkBase.dart';

const int MESSAGE_SIZE = 256;
const int PING_PONG_COUNT = 1000;

class SocketBenchmark extends BenchmarkBase {
  final int clients;

  final channel = new Channel();
  var port;
  int serverSocketPort;
  var serverPort;

  SocketBenchmark(int clients)
    : super("SocketPingPong$clients"),
      this.clients = clients;

  static void acceptProcess(Socket socket) {
    var buffer = new Uint8List(MESSAGE_SIZE).buffer;
    while (true) {
      if (socket.read(MESSAGE_SIZE) == null) break;
      socket.write(buffer);
    }
    socket.close();
  }

  static void serverProcess(port) {
    var channel = new Channel();
    port.send(new Port(channel));
    var server = new ServerSocket("127.0.0.1", 0);
    port.send(server.port);

    int count;
    do {
      count = channel.receive();
      for (int i = 0; i < count; i++) {
        server.spawnAccept(acceptProcess);
      }
    } while (count > 0);

    server.close();
  }

  void setup() {
    port = new Port(channel);
    var localPort = port;
    Process.spawnDetached(() => serverProcess(localPort));
    serverPort = channel.receive();
    serverSocketPort = channel.receive();
  }

  void teardown() {
    serverPort.send(0);
  }

  void exercise() => run();

  void run() {
    serverPort.send(clients);
    for (int i = 0; i < clients; i++) {
      var channel = new Channel();
      var handshakePort = new Port(channel);
      Process.spawnDetached(() => clientProcess(handshakePort));
      var clientPort = channel.receive();
      clientPort.send(serverSocketPort);
      clientPort.send(port);
    }
    for (int i = 0; i < clients; i++) {
      channel.receive();
    }
  }

  static void clientProcess(port) {
    var channel = new Channel();
    port.send(new Port(channel));

    var socket = new Socket.connect("127.0.0.1", channel.receive());
    port = channel.receive();
    var buffer = new Uint8List(MESSAGE_SIZE).buffer;
    for (int i = 0; i < PING_PONG_COUNT; i++) {
      socket.write(buffer);
      if (socket.read(MESSAGE_SIZE) == null) throw "Bad socket response";
    }
    socket.close();

    port.send(null);
  }
}
