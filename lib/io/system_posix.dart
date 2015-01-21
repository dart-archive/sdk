// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of system;

const int AF_INET  = 2;
const int AF_INET6 = 10;

const int SOCK_STREAM = 1;

const int F_GETFL = 3;
const int F_SETFL = 4;

const int O_NONBLOCK = 0x800;

class Timespec extends Struct {
  Timespec() : super(2);
  int get tv_sec => getField(0);
  int get tv_nsec => getField(1);
  void set tv_sec(int value) => setField(0, value);
  void set tv_nsec(int value) => setField(1, value);
}

// The AddrInfo class is platform specific. The name and address fields
// are swapped on MacOS compared to Linux.
abstract class AddrInfo extends Struct {
  factory AddrInfo() {
    switch (Foreign.platform) {
      case Foreign.LINUX: return new LinuxAddrInfo();
      case Foreign.MACOS: return new MacOSAddrInfo();
      default:
        throw "Unsupported platform for dart:io";
    }
  }

  factory AddrInfo.fromAddress(int address) {
    switch (Foreign.platform) {
      case Foreign.LINUX: return new LinuxAddrInfo.fromAddress(address);
      case Foreign.MACOS: return new MacOSAddrInfo.fromAddress(address);
      default:
        throw "Unsupported platform for dart:io";
    }
  }

  AddrInfo._() : super(8);
  AddrInfo._fromAddress(int address) : super.fromAddress(address, 8);

  int get _addrlenOffset => 16;

  int get ai_flags => getInt32(0);
  int get ai_family => getInt32(4);
  void set ai_family(int value) { setInt32(4, value); }
  int get ai_socktype => getInt32(8);
  int get ai_protocol => getInt32(12);

  int get ai_addrlen => getInt32(_addrlenOffset);

  Foreign get ai_addr;
  get ai_canonname;
  AddrInfo get ai_next;
}

class PosixSystem implements System {
  static final Foreign _accept = Foreign.lookup("accept");
  static final Foreign _bind = Foreign.lookup("bind");
  static final Foreign _close = Foreign.lookup("close");
  static final Foreign _connect = Foreign.lookup("connect");
  static final Foreign _fcntl = Foreign.lookup("fcntl");
  static final Foreign _freeaddrinfo = Foreign.lookup("freeaddrinfo");
  static final Foreign _getaddrinfo = Foreign.lookup("getaddrinfo");
  static final Foreign _getsockname = Foreign.lookup("getsockname");
  static final Foreign _ioctl = Foreign.lookup("ioctl");
  static final Foreign _listen = Foreign.lookup("listen");
  static final Foreign _nanosleep = Foreign.lookup("nanosleep");
  static final Foreign _read = Foreign.lookup("read");
  static final Foreign _socket = Foreign.lookup("socket");
  static final Foreign _write = Foreign.lookup("write");

  int get FIONREAD;

  int socket() {
    return _retry(() => _socket.icall$3(AF_INET, SOCK_STREAM, 0));
  }

  InternetAddress lookup(String host) {
    Foreign node = new Foreign.fromString(host);
    // TODO(ajohnsen): Actually apply hints.
    AddrInfo hints = new AddrInfo();
    // TODO(ajohnsen): Allow IPv6 results.
    hints.ai_family = AF_INET;
    Struct result = new Struct(1);
    int status = _retry(() => _getaddrinfo.icall$4(node,
                                                   Foreign.NULL,
                                                   hints,
                                                   result));
    AddrInfo start = new AddrInfo.fromAddress(result.getField(0));
    AddrInfo info = start;
    var address;
    while (info.value != 0) {
      int length;
      int offset;
      // Loop until we find the right type.
      if (info.ai_family == AF_INET) {
        length = 4;
        offset = 4;
      } else if (info.ai_family == AF_INET6) {
        length = 16;
        offset = 8;
      } else {
        info = info.ai_next;
        continue;
      }
      Foreign addr = info.ai_addr;
      List<int> bytes = new List<int>(length);
      addr.copyBytesToList(bytes, offset, offset + length, 0);
      address = new InternetAddress._internal(bytes);
      break;
    }
    _freeaddrinfo.icall$1(start);
    node.free();
    hints.free();
    result.free();
    if (status != 0) throw "Failed to call 'getaddrinfo': ${errno()}";
    return address;
  }

  int bind(int fd, InternetAddress address, int port) {
    Foreign sockaddr = _createSocketAddress(address, port);
    int status = _retry(() => _bind.icall$3(fd, sockaddr, sockaddr.size));
    sockaddr.free();
    return status;
  }

  int listen(int fd) {
    return _retry(() => _listen.icall$2(fd, 128));
  }

  int accept(int fd) {
    return _retry(() => _accept.icall$3(fd, Foreign.NULL, Foreign.NULL));
  }

  int port(int fd) {
    const int LENGTH = 28;
    var sockaddr = new Foreign.allocated(LENGTH);
    var addrlen = new Foreign.allocated(4);
    addrlen.setInt32(0, LENGTH);
    int status = _retry(() => _getsockname.icall$3(fd, sockaddr, addrlen));
    int port = -1;
    if (status == 0) {
      port = sockaddr.getUint8(2) << 8;
      port |= sockaddr.getUint8(3);
    }
    sockaddr.free();
    addrlen.free();
    return port;
  }

  int connect(int fd, InternetAddress address, int port) {
    Foreign sockaddr = _createSocketAddress(address, port);
    int status = _retry(() => _connect.icall$3(fd, sockaddr, sockaddr.size));
    sockaddr.free();
    return status;
  }

  int setBlocking(int fd, bool blocking) {
    int flags = _retry(() => _fcntl.icall$3(fd, F_GETFL, 0));
    if (flags == -1) return -1;
    if (blocking) {
      flags &= ~O_NONBLOCK;
    } else {
      flags |= O_NONBLOCK;
    }
    return _retry(() => _fcntl.icall$3(fd, F_SETFL, flags));
  }

  int available(int fd) {
    Struct result = new Struct(1);
    int status = _retry(() => _ioctl.icall$3(fd, FIONREAD, result));
    int available = result.getWord(0);
    result.free();
    if (status == -1) return status;
    return available;
  }

  int read(int fd, ByteBuffer buffer, int count) {
    _rangeCheck(buffer, count);
    var address = buffer._foreign.value + buffer.offset;
    return _retry(() => _read.icall$3(fd, address, count));
  }

  int write(int fd, ByteBuffer buffer, int count) {
    _rangeCheck(buffer, count);
    var address = buffer._foreign.value + buffer.offset;
    return _retry(() => _write.icall$3(fd, address, count));
  }

  int close(int fd) {
    return _retry(() => _close.icall$1(fd));
  }

  void sleep(int milliseconds) {
    Timespec timespec = new Timespec();
    timespec.tv_sec = milliseconds ~/ 1000;
    timespec.tv_nsec = (milliseconds % 1000) * 1000000;
    int result = _retry(() => _nanosleep.icall$2(timespec, timespec));
    timespec.free();
    if (result != 0) throw "Failed to call 'nanosleep': ${errno()}";
  }

  Errno errno() {
    return Errno.from(Foreign._errno());
  }

  void _rangeCheck(ByteBuffer buffer, int length) {
    if (buffer.length < length) throw new IndexError(length, buffer);
  }

  Foreign _createSocketAddress(InternetAddress address, int port) {
    var bytes = address._bytes;
    Foreign sockaddr;
    int length;
    if (bytes.length == 4) {
      length = 16;
      sockaddr = new Foreign.allocated(length);
      sockaddr.setUint16(0, AF_INET);
      sockaddr.copyBytesFromList(bytes, 4, 8, 0);
    } else if (bytes.length == 16) {
      length = 28;
      sockaddr = new Foreign.allocated(length);
      sockaddr.setUint16(0, AF_INET6);
      sockaddr.copyBytesFromList(bytes, 8, 24, 0);
    } else {
      throw "Invalid InternetAddress";
    }
    // Set port in Network Byte Order.
    sockaddr.setUint8(2, port >> 8);
    sockaddr.setUint8(3, port & 0xFF);
    return sockaddr;
  }

  int _retry(Function f) {
    int value;
    while ((value = f()) == -1) {
      if (Foreign._errno() != Errno.EINTR) break;
    }
    return value;
  }
}
