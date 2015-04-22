// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'github_mock_data.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';

class GithubMock {
  final String host;
  final int delay;
  ServerSocket _server;
  static const String _requestSuffix = ' HTTP/1.1';

  int get port => _server.port;

  GithubMock([String host = '127.0.0.1', int port = 0, int delay = 0])
      : this.host = host,
        this.delay = delay,
        _server = new ServerSocket(host, port);

  void close() {
    if (_server == null) return;
    _server.close();
    _server = null;
  }

  void spawn() {
    Thread.fork(run);
  }

  void run() {
    while (_server != null) {
      try {
        _accept(_server.accept());
      } catch (_) {
        // outstanding accept throws when the server closes.
      }
    }
  }

  void _accept(Socket socket) {
    if (delay > 0) sleep(delay);
    var data = new Uint8List.view(socket.readNext());
    var request = new String.fromCharCodes(data);

    // TODO(zerny): Use String.indexOf for start/end once implemented.
    int start = -1;
    for (int i = 0; i < request.length; ++i) {
      if (request[i] == '/') {
        start = i + 1;
        break;
      }
    }
    if (start < 0) {
      print('GithubMock: Ill-formed request.');
      socket.close();
      return;
    }

    int end = -1;
    for (int i = start; i < request.length; ++i) {
      if (_requestSuffix == request.substring(i, i + _requestSuffix.length)) {
        end = i;
        break;
      }
    }
    if (end < 0) {
      print('GithubMock: Ill-formed request.');
      socket.close();
      return;
    }

    var response = _readResponseFile(request.substring(start, end));
    socket.write(response);
    socket.close();
  }

  ByteBuffer _readResponseFile(String resource) {
    var result = githubMockData[resource];
    return (result != null) ?
        stringToByteBuffer(result) :
        stringToByteBuffer(githubMockData404);
  }
}
