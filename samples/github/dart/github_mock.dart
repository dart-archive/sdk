// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:fletch';
import 'dart:fletch.io';
import 'dart:typed_data';

import 'package:http/http.dart';

abstract class _Connection {
  final String host;
  final int port;
  final bool open;
  void close();
  Socket accept();
}

class _ConnectionImpl implements _Connection {
  final String host;
  ServerSocket _socket;
  get port => _socket.port;
  _ConnectionImpl(this.host, port) {
    _socket = new ServerSocket(host, port);
  }
  bool get open => _socket != null;
  void close() {
    if (!open) return;
    _socket.close();
    _socket = null;
  }
  Socket accept() => _socket.accept();
}

class _ConnectionInvertedImpl implements _Connection {
  final String host = '127.0.0.1';
  final int port;
  bool open = true;
  _ConnectionInvertedImpl(this.port) {
    // Signal availability to the "client".
    accept().close();
  }
  void close() {
    open = false;
  }
  Socket accept() {
    return new Socket.connect(host, port);
  }
}

class GithubMock {
  final int delay;
  bool verbose = false;
  _Connection _connection;
  static const String _requestSuffix = ' HTTP/1.1';

  String get host => _connection.host;
  int get port => _connection.port;

  GithubMock([host = '127.0.0.1', int port = 0, int this.delay = 0]) {
    _connection = new _ConnectionImpl(host, port);
  }

  GithubMock.invertedForTesting(int port, [int this.delay = 0]) {
    _connection = new _ConnectionInvertedImpl(port);
  }

  void close() {
    _connection.close();
  }

  void spawn() {
    Fiber.fork(run);
  }

  void run() {
    if (verbose) print('Running server on $host:$port');
    while (_connection.open) {
      try {
        _accept(_connection.accept());
      } on SocketException catch (_) {
        // outstanding accept throws when the server closes.
      }
    }
    if (verbose) print('Terminated server');
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

  String _dataDir = 'samples/github/dart/github_mock_data';

  ByteBuffer _readResponseFile(String resource) {
    int code = 200;
    String path = '$_dataDir/$resource.data';
    if (!File.existsAsFile(path)) {
      code = 404;
      path = '$_dataDir/404.data';
    }
    if (verbose) {
      print('Response $code on request for $resource');
    }
    File file = new File.open(path);
    return file.read(file.length);
  }
}
