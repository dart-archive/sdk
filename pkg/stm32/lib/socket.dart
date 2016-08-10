// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.socket;

import 'dart:dartino.ffi';
import 'dart:typed_data';
import 'dart:dartino.os';
import 'dart:dartino';
import 'package:stm32/ethernet.dart';
import 'package:socket/socket.dart' as system;

final _lookupHost = ForeignLibrary.main.lookup("network_lookup_host");

final _available = ForeignLibrary.main.lookup("socket_available");
final _close = ForeignLibrary.main.lookup("socket_close");
final _connect = ForeignLibrary.main.lookup("socket_connect");
final _bind = ForeignLibrary.main.lookup("socket_bind");
final _listenForEvent = ForeignLibrary.main.lookup("socket_listen_for_event");
final _createSocket = ForeignLibrary.main.lookup("create_socket");
final _recv = ForeignLibrary.main.lookup("socket_recv");
final _recvfrom = ForeignLibrary.main.lookup("socket_recvfrom");
final _registerSocket = ForeignLibrary.main.lookup("network_register_socket");
final _resetSocketFlags = ForeignLibrary.main.lookup("socket_reset_flags");
final _send = ForeignLibrary.main.lookup("socket_send");
final _sendTo = ForeignLibrary.main.lookup("socket_sendto");
final _shutdown = ForeignLibrary.main.lookup("socket_shutdown");
final _unregisterAndClose = ForeignLibrary.main.lookup("socket_unregister");
final _sockAddrSize = ForeignLibrary.main.lookup("SockAddrSize");
final _listen = ForeignLibrary.main.lookup("socket_listen");
final _accept = ForeignLibrary.main.lookup("socket_accept");

int sockAddrSize = _sockAddrSize.icall$0();

class SocketException implements system.SocketException {
  final String message;
  int get errno => null;
  const SocketException(this.message);
  String toString() => "SocketException: '$message'";
}

// These constants need to be in sync with FreeRTOS+TCP.
const int SOCKET_READ = 1 << 0;
const int SOCKET_WRITE = 1 << 1;
const int SOCKET_CLOSED = 1 << 2;
const int AF_INET = 2;
const int SOCK_STREAM = 1;
const int SOCK_DGRAM = 2;
const int IPPROTO_TCP = 6;
const int IPPROTO_UDP = 17;
const int SHUTDOWN_READ_WRITE = 2;

class _SocketBase {
  int _socket;
  int _handle;
  Port _port;
  Channel _channel;

  int _htons(int port) {
    return ((port & 0xFF) << 8) + ((port & 0xFF00) >> 8);
  }

  ForeignMemory _foreign(ByteBuffer buffer) {
    var b = buffer;
    return b.getForeign();
  }

  int get available => _available.icall$1(_socket);

  int _waitForEvent(int mask) {
    eventHandler.registerPortForNextEvent(_handle, _port,
                                          mask);
    _listenForEvent.vcall$2(_socket, mask);
    int event = _channel.receive();
    _resetSocketFlags.vcall$1(_handle);
    return event;
  }

  shutdownWrite() {
    // FreeRTOS ignores the second argument and always shuts down both ways.  We
    // use SHUTDOWN_READ_WRITE for compatibility with future versions.
    _shutdown.vcall$2(_socket, SHUTDOWN_READ_WRITE);
  }

  close() {
    shutdownWrite();
    _unregisterAndClose.vcall$1(_socket);
  }
}

class Socket extends _SocketBase implements system.Socket {
  Socket.connect(String host, int port) {
    if (Foreign.platform != Foreign.FREERTOS) {
      throw new SocketException(
          "Library only supported for FreeRTOS embedding");
    }
    if (!ethernet.isInitialized) {
      throw new SocketException("Network stack not initialized");
    }
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

  Socket._fromHandle(int socketHandle) {
    _socket = socketHandle;
    _handle = _registerSocket.icall$1(_socket);
    _channel = new Channel();
    _port = new Port(_channel);
  }

  void write(ByteBuffer buffer) {
    if ((_waitForEvent(SOCKET_WRITE | SOCKET_CLOSED) & SOCKET_CLOSED) != 0) {
      return null;
    }
    ForeignMemory memory = _foreign(buffer);
    _send.icall$4(_socket, memory.address, buffer.lengthInBytes, 0);
  }

  ByteBuffer readNext([int maxSize]) {
    if ((_waitForEvent(SOCKET_READ | SOCKET_CLOSED) & SOCKET_CLOSED) != 0) {
      return null;
    }
    int toRead = available;
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

  ByteBuffer read(int bytes) {
    ByteBuffer buffer = new Uint8List(bytes).buffer;
    int offset = 0;
    int address = _foreign(buffer).address;
    while (offset < bytes) {
      int events = _waitForEvent(SOCKET_READ | SOCKET_CLOSED);
      int read = 0;
      if ((events & SOCKET_READ) != 0) {
        read = _recv.icall$3(_socket, address + offset, bytes - offset);
      }
      if (read == 0 || (events & SOCKET_CLOSED) != 0) {
        if (offset + read < bytes) return null;
      }
      if (read < 0 || (events & SOCKET_CLOSED) != 0) {
        throw new SocketException("Failed to read from socket");
      }
      offset += read;
    }
    return buffer;
  }
}

class DatagramSocket extends _SocketBase implements system.DatagramSocket {
  ForeignMemory _sockaddr;
  final int port;

  DatagramSocket.bind(String host, this.port) {
    if (Foreign.platform != Foreign.FREERTOS) {
      throw new SocketException(
          "Library only supported for FreeRTOS embedding");
    }
    if (!ethernet.isInitialized) {
      throw new SocketException("network stack not initialized");
    }
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
    _socket = _createSocket.icall$3(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (_socket == -1) {
      throw const SocketException("Failed to create socket.");
    }
    // TODO(karlklose): save result as errno.
    int result = _bind.icall$3(_socket, address, _htons(port));
    if (result != 0) {
      _close.vcall$1(_socket);
      throw new SocketException("Can't connect to $host:$port ($result)");
    }
    _handle = _registerSocket.icall$1(_socket);
    _channel = new Channel();
    _port = new Port(_channel);
    // Allocate and zero out a `freertos_sockaddr` structure to be used in
    // sending and receiving.
    _sockaddr = new ForeignMemory.allocatedFinalized(sockAddrSize);
    _sockaddr.setUint32(0, 0);
    _sockaddr.setUint32(4, 0);
  }

  int send(InternetAddress address, int port, ByteBuffer buffer) {
    int targetPort = _htons(port);
    // There is no family field in `freertos_sockaddr`.
    _sockaddr.setUint16(0, targetPort);
    _sockaddr.copyBytesFromList(address.bytes, 4, 8, 0);
    ForeignMemory memory = _foreign(buffer);
    return _sendTo.icall$6(_socket, memory.address, memory.length, 0,
        _sockaddr.address, _sockaddr.length);
  }

  system.Datagram receive({int bufferSize: 1500}) {
    if (_waitForEvent(SOCKET_READ) != SOCKET_READ) {
      return null;
    }
    ByteBuffer buffer = new Uint8List(bufferSize).buffer;
    ForeignMemory addressLength = _foreign(new Uint8List(4).buffer);
    addressLength.setUint32(0, sockAddrSize);
    ForeignMemory memory = _foreign(buffer);
    int result = _recvfrom.icall$6(_socket, memory.address, memory.length, 0,
        _sockaddr.address, addressLength.address);
    if (result == 0) {
      return null;
    } else if (result < 0) {
      throw new SocketException("recvfrom returned $result");
    } else {
      if (result < bufferSize) {
        // Create a new [ByteBuffer] and copy the data to ensure that its
        // length field is correct.
        ByteBuffer newBuffer = new Uint8List(result).buffer;
        ForeignMemory newMemory = _foreign(newBuffer);
        for (int i = 0; i < result; ++i) {
          newMemory.setUint8(i, memory.getUint8(i));
        }
        buffer = newBuffer;
      }
      List<int> bytes = new List<int>(4);
      _sockaddr.copyBytesToList(bytes, 4, 8, 0);
      InternetAddress address = new InternetAddress(bytes);
      int port = _htons(_sockaddr.getUint16(0));
      return new system.Datagram(address, port, buffer);
    }
  }
}

class ServerSocket extends _SocketBase implements system.ServerSocket {
  ForeignMemory _sockaddr;
  final int port;

  ServerSocket(String host, this.port, {int backlog: 64}) {
    if (Foreign.platform != Foreign.FREERTOS) {
      throw new SocketException(
          "Library only supported for FreeRTOS embedding");
    }
    if (!ethernet.isInitialized) {
      throw new SocketException("Network stack not initialized");
    }
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
      throw const SocketException("Failed to create socket");
    }
    // TODO(karlklose): save result as errno.
    int result = _bind.icall$3(_socket, address, _htons(port));
    if (result != 0) {
      _close.vcall$1(_socket);
      throw new SocketException(
          "Failed to bind socket to ${host}:${port} ($result)");
    }
    if (_listen.icall$2(_socket, backlog) != 0) {
      _close.vcall$1(_socket);
      throw new SocketException("Failed to place socket into listening state");
    }

    _handle = _registerSocket.icall$1(_socket);
    _channel = new Channel();
    _port = new Port(_channel);

    // Allocate and zero out a `freertos_sockaddr` structure to be used when
    // accepting incoming connections.
    _sockaddr = new ForeignMemory.allocatedFinalized(sockAddrSize);
    _sockaddr.setUint32(0, 0);
    _sockaddr.setUint32(4, 0);
  }

  spawnAccept(Function f) {
    throw new UnimplementedError(
        "spawnAccept is not supported on FreeRTOS; use accept instead");
  }

  Socket accept() {
    if ((_waitForEvent(SOCKET_READ | SOCKET_CLOSED) & SOCKET_CLOSED) != 0) {
      return null;
    }
    int childSocket =_accept.icall$3(_socket, _sockaddr.address, 0);
    if (childSocket == -1 || childSocket == 0) {
      throw new SocketException(
          "Accept did not return a valid socket handle ($childSocket)");
    }
    return new Socket._fromHandle(childSocket);
  }
}
