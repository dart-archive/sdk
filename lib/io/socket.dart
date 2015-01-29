// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.io;

class _SocketBase {
  int _fd = -1;
  var _channel;
  var _port;

  void _addSocketToEventHandler() {
    if (sys.addToEventHandler(_fd) == -1) {
      _error("Failed to assign socket to event handler");
    }
    _channel = new Channel();
    _port = new Port(_channel);
  }

  int _waitFor(int mask) {
    sys.setPortForNextEvent(_fd, _port, mask);
    return _channel.receive();
  }

  /**
   * Close the socket. Operations on the socket are invalid after a call to
   * [close].
   */
  void close() {
    if (_fd != -1) {
      _port.close();
      sys.close(_fd);
      _fd = -1;
    }
  }

  void _error(String message) {
    close();
    throw new SocketException(message, sys.errno());
  }
}

class Socket extends _SocketBase {
  /**
   * Connect to the endpoint '[host]:[port]'.
   */
  Socket.connect(String host, int port) {
    var address = sys.lookup(host);
    if (address == null) _error("Failed to lookup address '$host'");
    _fd = sys.socket();
    if (_fd == -1) _error("Failed to create socket");
    sys.setBlocking(_fd, false);
    if (sys.connect(_fd, address, port) == -1 &&
        sys.errno() != Errno.EAGAIN) {
      _error("Failed to connect to $host:$port");
    }
    _addSocketToEventHandler();
    int events = _waitFor(WRITE_EVENT);
    if (events != WRITE_EVENT) {
      _error("Failed to connect to $host:$port");
    }
  }

  Socket._fromFd(fd) {
    // Be sure it's not in the event handler.
    _fd = fd;
    _addSocketToEventHandler();
  }

  /**
   * Get the number of available bytes.
   */
  int get available {
    int value = sys.available(_fd);
    if (value == -1) {
      _error("Failed to get the number of available bytes");
    }
    return value;
  }

  /**
   * Read [bytes] number of bytes from the socket.
   * Will block until all bytes are available.
   * Returns `null` if the socket was closed for reading.
   */
  ByteBuffer read(int bytes) {
    ByteBuffer buffer = new ByteBuffer._create(bytes);
    int offset = 0;
    while (offset < bytes) {
      int events = _waitFor(READ_EVENT);
      int read = 0;
      if ((events & READ_EVENT) != 0) {
        read = sys.read(_fd, buffer, offset, bytes - offset);
      }
      if (read == 0 || (events & CLOSE_EVENT) != 0) {
        if (offset + read < bytes) return null;
      }
      if (read < 0 || (events & ERROR_EVENT) != 0) {
        _error("Failed to read from socket");
      }
      offset += read;
    }
    return buffer;
  }

  /**
   * Read the next chunk of bytes.
   * Will block until some bytes are available.
   * Returns `null` if the socket was closed for reading.
   */
  ByteBuffer readNext();

  /**
   * Write [buffer] on the socket. Will block until all of [buffer] is written.
   */
  void write(ByteBuffer buffer) {
    int offset = 0;
    int bytes = buffer.lengthInBytes;
    while (true) {
      int wrote = sys.write(_fd, buffer, offset, bytes - offset);
      if (wrote == -1) {
        _error("Failed to write to socket");
      }
      offset += wrote;
      if (offset == bytes) return;
      int events = _waitFor(WRITE_EVENT);
      if ((events & ERROR_EVENT) != 0) {
        _error("Failed to write to socket");
      }
    }
  }

  /**
   * Close the socket for writing. After the socket is closed for writing,
   * [write] to the socket will fail.
   */
  void shutdownWrite() {
    if (sys.shutdown(_fd, SHUT_WR) == -1) {
      _error("Failed to shutdown socket for writing");
    }
  }
}

class ServerSocket extends _SocketBase {
  /**
   * Create a new server socket, listening on '[host]:[port]'.
   *
   * If [port] is '0', a random free port will be selected for the socket.
   */
  ServerSocket(String host, int port) {
    var address = sys.lookup(host);
    if (address == null) _error("Failed to lookup address '$host'");
    _fd = sys.socket();
    if (_fd == -1) _error("Failed to create socket");
    sys.setBlocking(_fd, false);
    if (sys.bind(_fd, address, port) == -1) {
      _error("Failed to bind to $host:$port");
    }
    if (sys.listen(_fd) == -1) _error("Failed to listen on $host:$port");
    _addSocketToEventHandler();
  }

  /**
   * Get the port of the server socket.
   */
  int get port {
    int value = sys.port(_fd);
    if (value == -1) {
      _error("Failed to get port");
    }
    return value;
  }

  static void _callAcceptCallback(port) {
    var channel = new Channel();
    port.send(new Port(channel));
    var fn = channel.receive();
    int client = channel.receive();
    fn(new Socket._fromFd(client));
  }

  /**
   * Accept the incoming socket. This function will block until a socket is
   * accepted.
   * A new process will be spawned and the [fn] function called on that process
   * with the new socket as argument.
   */
  void spawnAccept(void fn(Socket socket)) {
    int client = _accept();
    // TODO(ajohnsen): This is a bit slow. Change to sending a blob of data
    // containing the two entries, once we have support for that.
    var channel = new Channel();
    Process.spawn(_callAcceptCallback, new Port(channel));
    var port = channel.receive();
    port.send(fn);
    port.send(client);
  }

  /**
   * Accept the incoming socket. This function will block until a socket is
   * accepted.
   */
  Socket accept() {
    return new Socket._fromFd(_accept());
  }

  int _accept() {
    int events = _waitFor(READ_EVENT);
    if (events != READ_EVENT) {
      _error("Server socket closed while receiving socket");
    }
    int client = sys.accept(_fd);
    if (client == -1) _error("Failed to accept socket");
    sys.setBlocking(client, false);
    return client;
  }
}

class SocketException implements Exception {
  final String message;
  final Errno errno;
  SocketException(this.message, this.errno);

  String toString() => "SocketException: $message, $errno";
}
