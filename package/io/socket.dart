// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

class Socket {
  final String name;
  final int port;
  final Channel _channel;

  static Socket connect(String name, int port) {
    var channel = new Channel();
    var socket = _Socket$connect(name, port, channel);
    if (!channel.next) {
      throw "Failed to connect to '$name:$port'";
    }
    return new Socket(name, port, channel);
  }

  Socket(this.name, this.port, this._channel);

  void write(List<int> data) {
    _channel.send("write");
    _channel.send(data);
  }

  List<int> read() {
    _channel.send("read");
    return _channel.next;
  }

  void close() {
    _channel.send("close");
    _channel.next;
  }

  external static _Socket$connect(name, port, channel);
}

