// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch.io' as io;
import 'dart:fletch.os' as os;
import 'dart:typed_data';

import 'package:expect/expect.dart';
import 'package:socket/socket.dart';

void main() {
  testLookup();
  testBindListen();
  testConnect();
  testReadWrite();
  testSpawnAccept();
  testLargeChunk();
  testShutdown();
}

void testLookup() {
  os.InternetAddress address = io.lookup("127.0.0.1");
  Expect.isTrue(address is os.InternetAddress);
}

void testBindListen() {
  new ServerSocket("127.0.0.1", 0).close();
}

void testConnect() {
  var server = new ServerSocket("127.0.0.1", 0);

  var socket = new Socket.connect("127.0.0.1", server.port);

  var client = server.accept();
  Expect.isNotNull(client);

  client.close();
  socket.close();
  server.close();
}

createBuffer(int length) {
  var list = new Uint8List(length);
  for (int i = 0; i < length; i++) {
    list[i] = i & 0xFF;
  }
  return list.buffer;
}

void validateBuffer(buffer, int length) {
  Expect.equals(length, buffer.lengthInBytes);
  var list = new Uint8List.view(buffer);
  for (int i = 0; i < length; i++) {
    Expect.equals(i & 0xFF, list[i]);
  }
}

const CHUNK_SIZE = 256;

void testReadWrite() {
  var server = new ServerSocket("127.0.0.1", 0);
  var socket = new Socket.connect("127.0.0.1", server.port);
  var client = server.accept();

  socket.write(createBuffer(CHUNK_SIZE));
  validateBuffer(client.read(CHUNK_SIZE), CHUNK_SIZE);

  client.write(createBuffer(CHUNK_SIZE));
  validateBuffer(socket.read(CHUNK_SIZE), CHUNK_SIZE);

  Expect.equals(0, socket.available);
  Expect.equals(0, client.available);

  client.close();
  socket.close();
  server.close();
}

void spawnAcceptCallback(Socket client) {
  validateBuffer(client.read(CHUNK_SIZE), CHUNK_SIZE);
  client.write(createBuffer(CHUNK_SIZE));
  Expect.equals(0, client.available);

  client.close();
}

void testSpawnAccept() {
  var server = new ServerSocket("127.0.0.1", 0);
  var socket = new Socket.connect("127.0.0.1", server.port);
  server.spawnAccept(spawnAcceptCallback);

  socket.write(createBuffer(CHUNK_SIZE));
  validateBuffer(socket.read(CHUNK_SIZE), CHUNK_SIZE);
  Expect.equals(0, socket.available);

  socket.close();
  server.close();
}

const LARGE_CHUNK_SIZE = 128 * 1024;

void largeChunkClient(Socket client) {
  validateBuffer(client.read(LARGE_CHUNK_SIZE), LARGE_CHUNK_SIZE);
  client.write(createBuffer(LARGE_CHUNK_SIZE));
  Expect.equals(0, client.available);

  client.close();
}

void testLargeChunk() {
  var server = new ServerSocket("127.0.0.1", 0);
  var socket = new Socket.connect("127.0.0.1", server.port);
  server.spawnAccept(largeChunkClient);

  socket.write(createBuffer(LARGE_CHUNK_SIZE));
  validateBuffer(socket.read(LARGE_CHUNK_SIZE), LARGE_CHUNK_SIZE);

  Expect.equals(0, socket.available);

  socket.close();
  server.close();
}

bool isSocketException(e) => e is SocketException;

void testShutdown() {
  var server = new ServerSocket("127.0.0.1", 0);
  var socket = new Socket.connect("127.0.0.1", server.port);
  var client = server.accept();

  socket.write(createBuffer(CHUNK_SIZE));
  socket.shutdownWrite();

  validateBuffer(client.read(CHUNK_SIZE), CHUNK_SIZE);
  Expect.equals(null, client.read(CHUNK_SIZE));
  client.write(createBuffer(CHUNK_SIZE));
  client.shutdownWrite();

  validateBuffer(socket.read(CHUNK_SIZE), CHUNK_SIZE);
  Expect.equals(null, socket.read(CHUNK_SIZE));

  Expect.throws(() => client.write(createBuffer(CHUNK_SIZE)),
                isSocketException);
  Expect.throws(() => socket.write(createBuffer(CHUNK_SIZE)),
                isSocketException);

  client.close();
  socket.close();
  server.close();
}
