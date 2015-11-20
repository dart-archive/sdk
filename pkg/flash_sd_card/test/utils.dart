// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flash_sd_card/src/context.dart';

// Environment for running a test.
//
// This creates a Context where the stdin/stdout are not bound to the
// terminal.
class TestEnvironment {
  String name;
  Context ctx;
  StreamController stdinController;
  TestConsumer consumer;
  IOSink stdoutSink;
  Directory _tmpDir;

  TestEnvironment(this.name) {
    stdinController = new StreamController();
    consumer = new TestConsumer();
    stdoutSink = new IOSink(consumer);
    ctx = new Context([],
                      stdinStream: stdinController.stream,
                      stdoutSink: stdoutSink,
                      writeInstallLog: false);
  }

  String get consoleOutput => consumer.content;

  Future<Directory> get tmpDir async {
    _tmpDir ??= (await Directory.systemTemp.createTemp(name));
    return _tmpDir;
  }

  Future<File> createTmpFile(String name) async {
    var tmp = await tmpDir;
    return new File('${tmp.path}${Platform.pathSeparator}$name');
  }

  Future close() async {
    _tmpDir?.delete(recursive: true);
  }
}

class TestConsumer implements StreamConsumer {
  final List<int> received = <int>[];

  Future addStream(Stream<List<int>> stream) async {
    await for (List<int> bytes in stream) {
      received.addAll(bytes);
    }
  }

  Future close() async {}

  String get content => UTF8.decode(received);
}

// Test server
class Server {
  static const oneKBytes = 1024;
  HttpServer _httpServer;
  Future done;

  Server(this._httpServer, this.done);

  static Future<Server> start({int failureCount: 0}) async {
    var oneKData = new Uint8List(oneKBytes);

    var completer = new Completer();
    var server = await HttpServer.bind('127.0.0.1', 0);
    var count = 0;

    server.listen((request) async {
        count++;
        // Announce 2k of data.
        request.response.contentLength = 2 * oneKBytes;

        var socket = await request.response.detachSocket();

        socket.add(oneKData);
        if (count > failureCount) {
          socket.add(oneKData);
        }
        socket.close();
        if (count > failureCount) {
          server.close();
        }
      }, onDone: () => completer.complete());

    return new Server(server, completer.future);
  }

  int get port => _httpServer.port;

  int get successDownloadSize => oneKBytes * 2;

  Future close() async => await _httpServer.close();
}
