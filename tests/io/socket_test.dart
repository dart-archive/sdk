// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:io' as io;

import 'package:expect/expect.dart';

void main() {
  testLookup();
  testBindListen();
  testConnect();
  testReadWrite();
  testSpawnAccept();
}

void testLookup() {
  InternetAddress address = io.lookup("127.0.0.1");
  Expect.isNotNull(address);
}

void testBindListen() {
  new io.ServerSocket("127.0.0.1", 0).close();
}

void testConnect() {
  var server = new io.ServerSocket("127.0.0.1", 0);

  var socket = new io.Socket.connect("127.0.0.1", server.port);

  var client = server.accept();
  Expect.isNotNull(client);

  client.close();
  socket.close();
  server.close();
}

void testReadWrite() {
  var server = new io.ServerSocket("127.0.0.1", 0);
  var socket = new io.Socket.connect("127.0.0.1", server.port);
  var client = server.accept();

  socket.write(new io.ByteBuffer(256));
  Expect.equals(256, client.read(256).length);

  client.write(new io.ByteBuffer(256));
  Expect.equals(256, socket.read(256).length);

  // TODO(ajohnsen): Validate the data.

  Expect.equals(0, socket.available);
  Expect.equals(0, client.available);

  client.close();
  socket.close();
  server.close();
}

void spawnAcceptCallback(Socket client) {
  Expect.equals(256, client.read(256).length);
  client.write(new io.ByteBuffer(256));
  Expect.equals(0, client.available);

  client.close();
}

void testSpawnAccept() {
  var server = new io.ServerSocket("127.0.0.1", 0);
  var socket = new io.Socket.connect("127.0.0.1", server.port);
  server.spawnAccept(spawnAcceptCallback);

  socket.write(new io.ByteBuffer(256));
  Expect.equals(256, socket.read(256).length);
  Expect.equals(0, socket.available);

  socket.close();
  server.close();
}
