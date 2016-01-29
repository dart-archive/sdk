// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sdk_services/sdk_services.dart';

class TestOutputService implements OutputService {
  String output = "";

  void log(String s) { output = '$output\n$s'; }

  void startProgress(String s) { output = '$output\n$s'; }

  void endProgress(String s) { output = '$output\n$s'; }

  void updateProgress(String s) { output = '$output\n$s'; }

  void failure(String s) {
    output = '$output\n$s';
    throw new DownloadException("failed");
  }
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
