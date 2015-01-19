// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

class ServerSocket {
  final String name;
  final int port;
  final Channel _channel;

  static ServerSocket bind(String name, int port) {
    var channel = new Channel();
    _ServerSocket$bind(name, port, channel);
    port = channel.next;
    return new ServerSocket(name, port, channel);
  }

  accept() {
    _channel.send("accept");
    var clientChannel = _channel.next;
    return new Socket(name, port, clientChannel);
  }

  void close() {
    _channel.send("close");
    _channel.next;
  }

  ServerSocket(this.name, this.port, this._channel);

  external static void _ServerSocket$bind(name, port, channel);
}
