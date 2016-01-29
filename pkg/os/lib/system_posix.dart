// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of os;

const int F_GETFD = 1;
const int F_SETFD = 2;
const int F_GETFL = 3;
const int F_SETFL = 4;

const int FD_CLOEXEC = 0x1;

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
  static final ForeignFunction _read =
      ForeignLibrary.main.lookup("read");
  static final ForeignFunction _setsockopt =
      ForeignLibrary.main.lookup("setsockopt");
  static final ForeignFunction _shutdown =
      ForeignLibrary.main.lookup("shutdown");
  static final ForeignFunction _socket =
      ForeignLibrary.main.lookup("socket");
  static final ForeignFunction _strerror_r =
      ForeignLibrary.main.lookup("strerror_r");
  static final ForeignFunction _unlink =
      ForeignLibrary.main.lookup("unlink");
  static final ForeignFunction _write =
      ForeignLibrary.main.lookup("write");
  static final ForeignFunction _sendto =
      ForeignLibrary.main.lookup("sendto");
  static final ForeignFunction _recvfrom =
      ForeignLibrary.main.lookup("recvfrom");
  static final ForeignFunction _uname =
      ForeignLibrary.main.lookup("uname");

  int get AF_INET => 2;
  int get AF_INET6;

  int get SOCK_STREAM => 1;
  int get SOCK_DGRAM => 2;

  int get O_RDONLY => 0;
  int get O_WRONLY => 1;
  int get O_RDWR => 2;
  int get O_CREAT;
  int get O_TRUNC;
  int get O_APPEND;
  int get O_CLOEXEC;
  int get O_NONBLOCK;

  int get FIONREAD;

  int get SOL_SOCKET;

  int get SO_REUSEADDR;

  int get ADDR_INFO_SIZE => 8;

  int get SOCKADDR_STORAGE_SIZE => 128;

  int get UTSNAME_LENGTH;
  int get SIZEOF_UTSNAME;

  ForeignFunction get _open;
  ForeignFunction get _lseek;

  int socket(int domain, int type, int protocol) {
    return _socket.icall$3Retry(domain, type, protocol);
  }

  InternetAddress lookup(String host) {
    ForeignMemory node = new ForeignMemory.fromStringAsUTF8(host);
    // TODO(ajohnsen): Actually apply hints.
    AddrInfo hints = new AddrInfo();
    // TODO(ajohnsen): Allow IPv6 results.
    hints.family = AF_INET;
    Struct result = new Struct(1);
    int status = _getaddrinfo.icall$4Retry(
        node, ForeignPointer.NULL, hints, result);
    AddrInfo start = new AddrInfo.fromAddress(result.getField(0));
    AddrInfo info = start;
    var address;
    while (info.address != 0) {
      int length;
      int offset;
      // Loop until we find the right type.
      if (info.family == AF_INET) {
        length = 4;
        offset = 4;
      } else if (info.family == AF_INET6) {
        length = 16;
        offset = 8;
      } else {
        info = info.next;
        continue;
      }
      ForeignMemory addr = info.addr;
      List<int> bytes = new List<int>(length);
      addr.copyBytesToList(bytes, offset, offset + length, 0);
      address = new _InternetAddress(bytes);
      break;
    }
    _freeaddrinfo.icall$1Retry(start);
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
      if (append) {
        flags = flags | O_APPEND;
      } else {
        flags = flags | O_TRUNC;
      }
    }
    flags |= O_CLOEXEC;
    ForeignMemory cPath = new ForeignMemory.fromStringAsUTF8(path);
    int mode = 6 << 6 | 6 << 3 | 6; // octal 0666
    int fd = _open.icall$3Retry(cPath, flags, mode);
    cPath.free();
    return fd;
  }

  int lseek(int fd, int offset, int whence) {
    return _lseek.Lcall$wLwRetry(fd, offset, whence);
  }

  TempFile mkstemp(String path) {
    ForeignMemory cPath = new ForeignMemory.fromStringAsUTF8(path + "XXXXXX");
    int result = _mkstemp.icall$1Retry(cPath);
    if (result != -1) {
      var bytes = new List(cPath.length - 1);
      cPath.copyBytesToList(bytes, 0, cPath.length - 1, 0);
      path = new String.fromCharCodes(bytes);
    }
    cPath.free();
    return new TempFile(result, path);
  }

  int access(String path) {
    ForeignMemory cPath = new ForeignMemory.fromStringAsUTF8(path);
    int result = _access.icall$2Retry(cPath, 0);
    cPath.free();
    return result;
  }

  int unlink(String path) {
    ForeignMemory cPath = new ForeignMemory.fromStringAsUTF8(path);
    int result = _unlink.icall$1Retry(cPath);
    cPath.free();
    return result;
  }

  int bind(int fd, _InternetAddress address, int port) {
    ForeignMemory sockaddr = _createSocketAddress(address, port);
    int status = _bind.icall$3Retry(fd, sockaddr, sockaddr.length);
    sockaddr.free();
    return status;
  }

  int listen(int fd) {
    return _listen.icall$2Retry(fd, 128);
  }

  int setsockopt(int fd, int level, int optname, ForeignMemory value) {
    return _setsockopt.icall$5Retry(fd, level, optname, value, value.length);
  }

  int accept(int fd) {
    return _accept.icall$3Retry(fd, ForeignPointer.NULL, ForeignPointer.NULL);
  }

  int port(int fd) {
    const int LENGTH = 28;
    var sockaddr = new ForeignMemory.allocated(LENGTH);
    var addrlen = new ForeignMemory.allocated(4);
    addrlen.setInt32(0, LENGTH);
    int status = _getsockname.icall$3Retry(fd, sockaddr, addrlen);
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
    int status = _connect.icall$3Retry(fd, sockaddr, sockaddr.length);
    sockaddr.free();
    return status;
  }

  int setBlocking(int fd, bool blocking) {
    int flags = _fcntl.icall$3Retry(fd, F_GETFL, 0);
    if (flags == -1) return -1;
    if (blocking) {
      flags &= ~O_NONBLOCK;
    } else {
      flags |= O_NONBLOCK;
    }
    return _fcntl.icall$3Retry(fd, F_SETFL, flags);
  }

  int setCloseOnExec(int fd, bool closeOnExec) {
    int flags = _fcntl.icall$3Retry(fd, F_GETFD, 0);
    if (flags == -1) return -1;
    if (closeOnExec) {
      flags |= FD_CLOEXEC;
    } else {
      flags &= ~FD_CLOEXEC;
    }
    return _fcntl.icall$3Retry(fd, F_SETFD, flags);
  }

  int available(int fd) {
    Struct result = new Struct(1);
    int status = _ioctl.icall$3Retry(fd, FIONREAD, result);
    int available = result.getWord(0);
    result.free();
    if (status == -1) return status;
    return available;
  }

  ForeignMemory getForeign(ByteBuffer buffer) {
    var b = buffer;
    return b.getForeign();
  }

  int read(int fd, ByteBuffer buffer, int offset, int length) {
    _rangeCheck(buffer, offset, length);
    var address = getForeign(buffer).address + offset;
    return _read.icall$3Retry(fd, address, length);
  }

  int write(int fd, ByteBuffer buffer, int offset, int length) {
    _rangeCheck(buffer, offset, length);
    var address = getForeign(buffer).address + offset;
    return _write.icall$3Retry(fd, address, length);
  }

  int sendto(int fd, ByteBuffer buffer, InternetAddress target, int port) {
    ForeignMemory sockAddr = _createSocketAddress(target, port);
    ForeignMemory memory = getForeign(buffer);
    try {
      return _sendto.icall$6Retry(fd, memory, memory.length, 0,
          sockAddr, sockAddr.length);
    } finally {
      sockAddr.free();
    }
  }

  int recvfrom(int fd, ByteBuffer buffer, ForeignMemory sockaddr) {
    Struct32 len = new Struct32(1);
    len.setUint32(0, sockaddr.length);
    ForeignMemory memory = getForeign(buffer);
    try {
      return _recvfrom.icall$6Retry(fd, memory, memory.length, 0, sockaddr,
          len);
    } finally {
      len.free();
    }
  }

  void memcpy(var dest,
              int destOffset,
              var src,
              int srcOffset,
              int length) {
    var destAddress = dest.getForeign().address + destOffset;
    var srcAddress = src.getForeign().address + srcOffset;
    _memcpy.icall$3Retry(destAddress, srcAddress, length);
  }

  int shutdown(int fd, int how) {
    return _shutdown.icall$2Retry(fd, how);
  }

  int close(int fd) {
    return _close.icall$1Retry(fd);
  }

  void sleep(int milliseconds) => os.sleep(milliseconds);

  int errno() => Foreign.errno;

  String strerror(int errno) {
    var buffer = new ForeignMemory.allocated(256);
    try {
      // strerror_r might not return a pointer to buffer.
      return cStringToString(_strerror_r.pcall$3(errno, buffer, 256));
    } finally {
      buffer.free();
    }
  }

  static void _rangeCheck(ByteBuffer buffer, int offset, int length) {
    if (buffer.lengthInBytes < offset + length) {
      throw new IndexError(length, buffer);
    }
  }

  PosixSockAddrIn allocateSockAddrIn() {
    return new PosixSockAddrIn(allocateSockAddrStorageMemory(), 0);
  }

  PosixSockAddrIn6 allocateSockAddrIn6() {
    return new PosixSockAddrIn6(allocateSockAddrStorageMemory(), 0);
  }

  ForeignMemory allocateSockAddrStorageMemory() {
    return new ForeignMemory.allocated(SOCKADDR_STORAGE_SIZE);
  }

  ForeignMemory _createSocketAddress(_InternetAddress address, int port) {
    PosixSockAddrIn sockAddr;
    if (address.family == AF_INET) {
      sockAddr = allocateSockAddrIn();
    } else if (address.family == AF_INET6) {
      sockAddr = allocateSockAddrIn6();
    } else {
      throw "Invalid InternetAddress";
    }
    sockAddr.family = address.family;
    sockAddr.address = address;
    sockAddr.port = port;
    return sockAddr.buffer;
  }

  SystemInformation info() {
    if (SIZEOF_UTSNAME == 0) {
      throw new UnsupportedError(
          'System information is not supported on this platform');
    }
    var utsname = new ForeignMemory.allocated(SIZEOF_UTSNAME);
    try {
      int status = _uname.icall$1Retry(utsname);
      if (status < 0) throw "Failed calling uname";
      int address = utsname.address;
      var fp = new ForeignPointer(address);
      var operatingSystemName = cStringToString(fp);
      address += UTSNAME_LENGTH;
      fp = new ForeignPointer(address);
      var nodeName = cStringToString(fp);
      address += UTSNAME_LENGTH;
      fp = new ForeignPointer(address);
      var release = cStringToString(fp);
      address += UTSNAME_LENGTH;
      fp = new ForeignPointer(address);
      var version = cStringToString(fp);
      address += UTSNAME_LENGTH;
      fp = new ForeignPointer(address);
      var machine = cStringToString(fp);
      return new SystemInformation(operatingSystemName, nodeName, release,
                                   version, machine);
    } finally {
      utsname.free();
    }
  }
}
