// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.socket;

import 'dart:dartino.ffi';
import 'dart:typed_data';
import 'dart:dartino.os';
import 'dart:dartino';

final _lookupHost = ForeignLibrary.main.lookup("network_lookup_host");

final _available = ForeignLibrary.main.lookup("socket_available");
final _close = ForeignLibrary.main.lookup("socket_close");
final _connect = ForeignLibrary.main.lookup("socket_connect");
final _listenForEvent = ForeignLibrary.main.lookup("socket_listen_for_event");
final _createSocket = ForeignLibrary.main.lookup("create_socket");
final _recv = ForeignLibrary.main.lookup("socket_recv");
final _registerSocket = ForeignLibrary.main.lookup("network_register_socket");
final _resetSocketFlags = ForeignLibrary.main.lookup("socket_reset_flags");
final _send = ForeignLibrary.main.lookup("socket_send");
final _shutdown = ForeignLibrary.main.lookup("socket_shutdown");
final _unregisterAndClose = ForeignLibrary.main.lookup("socket_unregister");

class SocketException {
  final String message;
  const SocketException(this.message);
  String toString() => "SocketException: '$message'";
}

class Socket {
  static const int SOCKET_READ = 1 << 0;
  static const int SOCKET_WRITE = 1 << 1;
  static const int SOCKET_CLOSED = 1 << 2;

  static const int AF_INET = 2;
  static const int SOCK_STREAM = 1;
  static const int IPPROTO_TCP = 6;

  static const int SHUTDOWN_READ_WRITE = 2;

  int _socket;
  int _handle;
  Port _port;
  Channel _channel;

  static int _htons(int port) {
    return ((port & 0xFF) << 8) + ((port & 0xFF00) >> 8);
  }

  Socket.connect(String host, int port) {
    ForeignMemory string = new ForeignMemory.fromStringAsUTF8(host);
    int address;
    try {
      address = _lookupHost.icall$1(string.address);
    } finally {
      string.free();
    }
    if (address == 0) {
      throw new SocketException("Unable to find $host");
    }
    _socket = _createSocket.icall$3(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (_socket == -1) {
      throw const SocketException("Failed to create socket.");
    }
    // TODO(karlklose): save result as errno.
    int result = _connect.icall$3(_socket, address, _htons(port));
    if (result != 0) {
      _close.vcall$1(_socket);
      throw new SocketException("Can't connect to $host:$port ($result)");
    }
    _handle = _registerSocket.icall$1(_socket);
    _channel = new Channel();
    _port = new Port(_channel);
  }

  int write(ByteBuffer buffer) {
    if ((_waitForEvent(SOCKET_WRITE | SOCKET_CLOSED) & SOCKET_CLOSED) != 0) {
      return null;
    }
    ForeignMemory memory = _foreign(buffer);
    return _send.icall$4(_socket, memory.address, buffer.lengthInBytes, 0);
  }

  ForeignMemory _foreign(ByteBuffer buffer) {
    var b = buffer;
    return b.getForeign();
  }

  ByteBuffer readNext([int maxSize]) {
    if ((_waitForEvent(SOCKET_READ | SOCKET_CLOSED) & SOCKET_CLOSED) != 0) {
      return null;
    }
    int toRead = available();
    if (maxSize != null && maxSize < toRead) {
      toRead = maxSize;
    }
    ByteBuffer buffer = new Uint8List(toRead).buffer;
    int read = _recv.icall$4(_socket, _foreign(buffer), toRead, 0);
    if (read < toRead) {
      throw new SocketException('unable to read all data');
    }
    return buffer;
  }

  close() {
    _unregisterAndClose.vcall$1(_socket);
  }

  shutdown() {
    _shutdown.vcall$2(_socket, SHUTDOWN_READ_WRITE);
  }

  int available() => _available.icall$1(_socket);

  int _waitForEvent(int mask) {
    eventHandler.registerPortForNextEvent(_handle, _port,
                                          mask);
    _listenForEvent.vcall$2(_socket, mask);
    int event = _channel.receive();
    _resetSocketFlags.vcall$1(_handle);
    return event;
  }
}
