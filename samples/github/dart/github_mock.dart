// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';

class GithubMock {
  String host;
  ServerSocket _server;
  int delay = 0;

  int get port => _server.port;

  void startLocalServer([delay]) {
    if (delay != null) this.delay = delay;
    host = '127.0.0.1';
    _server = new ServerSocket(host, 0);
    Thread.fork(_run);
  }

  void close() {
    if (_server == null) return;
    _server.close();
    _server = null;
  }

  static const _requestPrefix = 'GET 127.0.0.1/';
  static const _requestSuffix = ' HTTP/1.1';

  void _run() {
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
    int start = _requestPrefix.length;
    //TODO(zerny): Replace: int end = request.indexOf(_requestSuffix, start);
    int end = -1;
    for (int i = start; i < request.length; ++i) {
      if (_requestSuffix == request.substring(i, i + _requestSuffix.length)) {
        end = i;
        break;
      }
    }
    if (end < 0) {
      print('GithubMock: Ill-formed request.');
    } else {
      var response = _readResponseFile(request.substring(start, end));
      socket.write(response);
    }
    socket.close();
  }

  ByteBuffer _readResponseFile(String resource) {
    var file;
    try {
      file = new File.open(_filePath(resource));
    } on FileException catch (e) {
      file = new File.open(_filePath('404'));
    }
    return file.read(file.length);
  }

  String _filePath(String resource) {
    return 'samples/github/dart/tests/data/${resource}.data';
  }
}
