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
      case Foreign.ANDROID: return new AndroidAddrInfo();
      default:
        throw "Unsupported platform for dart:io";
    }
  }

  factory AddrInfo.fromAddress(int address) {
    switch (Foreign.platform) {
      case Foreign.LINUX: return new LinuxAddrInfo.fromAddress(address);
      case Foreign.MACOS: return new MacOSAddrInfo.fromAddress(address);
      case Foreign.ANDROID: return new AndroidAddrInfo.fromAddress(address);
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

  ForeignMemory get ai_addr;
  get ai_canonname;
  AddrInfo get ai_next;
}

abstract class PosixSystem implements System {
  static final ForeignFunction _accept =
      ForeignLibrary.main.lookup("accept");
  static final ForeignFunction _access =
      ForeignLibrary.main.lookup("access");
  static final ForeignFunction _bind =
      ForeignLibrary.main.lookup("bind");
  static final ForeignFunction _close =
      ForeignLibrary.main.lookup("close");
  static final ForeignFunction _connect =
      ForeignLibrary.main.lookup("connect");
  static final ForeignFunction _fcntl =
      ForeignLibrary.main.lookup("fcntl");
  static final ForeignFunction _freeaddrinfo =
      ForeignLibrary.main.lookup("freeaddrinfo");
  static final ForeignFunction _getaddrinfo =
      ForeignLibrary.main.lookup("getaddrinfo");
  static final ForeignFunction _getsockname =
      ForeignLibrary.main.lookup("getsockname");
  static final ForeignFunction _ioctl =
      ForeignLibrary.main.lookup("ioctl");
  static final ForeignFunction _listen =
      ForeignLibrary.main.lookup("listen");
  static final ForeignFunction _memcpy =
      ForeignLibrary.main.lookup("memcpy");
  static final ForeignFunction _mkstemp =
      ForeignLibrary.main.lookup("mkstemp");
  static final ForeignFunction _nanosleep =
      ForeignLibrary.main.lookup("nanosleep");
  static final ForeignFunction _read =
      ForeignLibrary.main.lookup("read");
  static final ForeignFunction _setsockopt =
      ForeignLibrary.main.lookup("setsockopt");
  static final ForeignFunction _shutdown =
      ForeignLibrary.main.lookup("shutdown");
  static final ForeignFunction _socket =
      ForeignLibrary.main.lookup("socket");
  static final ForeignFunction _unlink =
      ForeignLibrary.main.lookup("unlink");
  static final ForeignFunction _write =
      ForeignLibrary.main.lookup("write");

  int get FIONREAD;

  int get SOL_SOCKET;

  int get SO_REUSEADDR;

  ForeignFunction get _open;
  ForeignFunction get _lseek;

  int socket() {
    return _retry(() => _socket.icall$3(AF_INET, SOCK_STREAM, 0));
  }

  InternetAddress lookup(String host) {
    ForeignMemory node = new ForeignMemory.fromString(host);
    // TODO(ajohnsen): Actually apply hints.
    AddrInfo hints = new AddrInfo();
    // TODO(ajohnsen): Allow IPv6 results.
    hints.ai_family = AF_INET;
    Struct result = new Struct(1);
    int status = _retry(() => _getaddrinfo.icall$4(node,
                                                   ForeignPointer.NULL,
                                                   hints,
                                                   result));
    AddrInfo start = new AddrInfo.fromAddress(result.getField(0));
    AddrInfo info = start;
    var address;
    while (info.address != 0) {
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
      ForeignMemory addr = info.ai_addr;
      List<int> bytes = new List<int>(length);
      addr.copyBytesToList(bytes, offset, offset + length, 0);
      address = new _InternetAddress(bytes);
      break;
    }
    _freeaddrinfo.icall$1(start);
    node.free();
    hints.free();
    result.free();
    if (status != 0) throw "Failed to call 'getaddrinfo': ${errno()}";
    return address;
  }

  int open(String path, bool read, bool write, bool append) {
    int flags = 0;
    if (read && !write) {
      flags = O_RDONLY;
    } else if (!read && write) {
      flags = O_WRONLY;
    } else if (read && write) {
      flags = O_RDWR;
    } else {
      throw "Neither 'read' nor 'write' was specified";
    }
    if (write || append) {
      flags |= O_CREAT;
      if (!append) flags = flags | O_TRUNC;
    }
    flags |= O_CLOEXEC;
    ForeignMemory cPath = new ForeignMemory.fromString(path);
    int fd = _retry(() => _open.icall$2(cPath, flags));
    cPath.free();
    return fd;
  }

  int lseek(int fd, int offset, int whence) {
    return _retry(() => _lseek.Lcall$wLw(fd, offset, whence));
  }

  TempFile mkstemp(String path) {
    ForeignMemory cPath = new ForeignMemory.fromString(path + "XXXXXX");
    int result = _retry(() => _mkstemp.icall$1(cPath));
    if (result != -1) {
      var bytes = new List(cPath.length - 1);
      cPath.copyBytesToList(bytes, 0, cPath.length - 1, 0);
      path = new String.fromCharCodes(bytes);
    }
    cPath.free();
    return new TempFile(result, path);
  }

  int access(String path) {
    ForeignMemory cPath = new ForeignMemory.fromString(path);
    int result = _retry(() => _access.icall$2(cPath, 0));
    cPath.free();
    return result;
  }

  int unlink(String path) {
    ForeignMemory cPath = new ForeignMemory.fromString(path);
    int result = _retry(() => _unlink.icall$1(cPath));
    cPath.free();
    return result;
  }

  int bind(int fd, _InternetAddress address, int port) {
    ForeignMemory sockaddr = _createSocketAddress(address, port);
    int status = _retry(() => _bind.icall$3(fd, sockaddr, sockaddr.length));
    sockaddr.free();
    return status;
  }

  int listen(int fd) {
    return _retry(() => _listen.icall$2(fd, 128));
  }

  int setsockopt(int fd, int level, int optname, int value) {
    Struct32 opt = new Struct32(1);
    opt.setField(0, value);
    int result = _retry(() => _setsockopt.icall$5(fd,
                                                  level,
                                                  optname,
                                                  opt,
                                                  opt.length));
    opt.free();
    return result;
  }

  int accept(int fd) {
    return _retry(() => _accept.icall$3(fd, ForeignPointer.NULL,
                                        ForeignPointer.NULL));
  }

  int port(int fd) {
    const int LENGTH = 28;
    var sockaddr = new ForeignMemory.allocated(LENGTH);
    var addrlen = new ForeignMemory.allocated(4);
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

  int connect(int fd, _InternetAddress address, int port) {
    ForeignMemory sockaddr = _createSocketAddress(address, port);
    int status = _retry(() => _connect.icall$3(fd, sockaddr, sockaddr.length));
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

  int setReuseaddr(int fd) {
    return setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, 1);
  }

  int available(int fd) {
    Struct result = new Struct(1);
    int status = _retry(() => _ioctl.icall$3(fd, FIONREAD, result));
    int available = result.getWord(0);
    result.free();
    if (status == -1) return status;
    return available;
  }

  int read(int fd, var buffer, int offset, int length) {
    _rangeCheck(buffer, offset, length);
    var address = buffer.getForeign().address + offset;
    return _retry(() => _read.icall$3(fd, address, length));
  }

  int write(int fd, var buffer, int offset, int length) {
    _rangeCheck(buffer, offset, length);
    var address = buffer.getForeign().address + offset;
    return _retry(() => _write.icall$3(fd, address, length));
  }

  void memcpy(var dest,
              int destOffset,
              var src,
              int srcOffset,
              int length) {
    var destAddress = dest.getForeign().address + destOffset;
    var srcAddress = src.getForeign().address + srcOffset;
    _memcpy.icall$3(destAddress, srcAddress, length);
  }

  int shutdown(int fd, int how) {
    return _retry(() => _shutdown.icall$2(fd, how));
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
    return Errno.from(Foreign.errno);
  }

  static void _rangeCheck(ByteBuffer buffer, int offset, int length) {
    if (buffer.lengthInBytes < offset + length) {
      throw new IndexError(length, buffer);
    }
  }

  ForeignMemory _createSocketAddress(_InternetAddress address, int port) {
    var bytes = address._bytes;
    ForeignMemory sockaddr;
    int length;
    if (bytes.length == 4) {
      length = 16;
      sockaddr = new ForeignMemory.allocated(length);
      sockaddr.setUint16(0, AF_INET);
      sockaddr.copyBytesFromList(bytes, 4, 8, 0);
    } else if (bytes.length == 16) {
      length = 28;
      sockaddr = new ForeignMemory.allocated(length);
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
      if (Foreign.errno != Errno.EINTR) break;
    }
    return value;
  }
}
