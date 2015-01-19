// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library io;

part 'socket.dart';
part 'server_socket.dart';

const _LF = 0x0A;
const _CR = 0x0D;
const _SPACE = 0x20;

HttpRequest _readIncoming(Socket socket) {
  var data = [];
  int firstLineLength;
  do {
    int len = data.length;
    data.addAll(socket.read());
    for (int i = len; i < data.length - 1; i++) {
      if (data[i] == _CR && data[i + 1] == _LF) {
        firstLineLength = i - 1;
        break;
      }
    }
  } while (firstLineLength == null);
  int index = 0;
  while (data[index] != _SPACE) {
    index++;
    if (index == firstLineLength) throw "Bad request";
  }
  var method = data.sublist(0, index);
  index++;
  int uriStart = index;
  while (data[index] != _SPACE) {
    index++;
    if (index == firstLineLength) throw "Bad request";
  }
  var uri = data.sublist(uriStart, index);
}

class HttpServer {
  final ServerSocket _serverSocket;

  HttpServer.bind(String hostname, int port)
      : _serverSocket = ServerSocket.bind(hostname, port) {
  }

  Channel listen([channel]) {
    if (channel == null) channel = new Channel();
    Isolate.spawn(_serverHandler, [this, channel]);
    return channel;
  }

  int get port => _serverSocket.port;

  void close() {
    _serverSocket.close();
  }

  static _serverHandler(args) {
    var server = args[0];
    var channel = args[1];

    while (true) {
      var socket = server._serverSocket.accept();
      HttpRequest request = new HttpRequest._(socket);
      channel.send(request);
      Isolate.spawn(HttpRequest._requestHandler, request);
    }
  }
}

class HttpRequest {
  final _socket;

  HttpRequest._(this._socket);

  static _requestHandler() {
  }
}

void sleep(int milliseconds) {
  callBlocking("sleep", milliseconds);
}
