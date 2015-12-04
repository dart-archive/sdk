// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of os;

const int SHUT_RD   = 0;
const int SHUT_WR   = 1;
const int SHUT_RDWR = 2;

const int SEEK_SET = 0;
const int SEEK_CUR = 1;
const int SEEK_END = 2;

final System sys = getSystem();

System getSystem() {
  switch (Foreign.platform) {
    case Foreign.ANDROID:
    case Foreign.LINUX:
      return new LinuxSystem();
    case Foreign.MACOS:
      return new MacOSSystem();
    default:
      throw "Unsupported system ${Foreign.platform}";
  }
}

// The result of opening a temporary file is both the file descriptor and the
// path.
class TempFile {
  final int fd;
  final String path;
  TempFile(this.fd, this.path);
}

class SystemInformation {
  /// Operating system name (e.g., "Linux").
  final String operatingSystemName;
  /// Name within "some implementation-defined network".
  final String nodeName;
  /// Operating system release (e.g., "2.6.28")
  final String release;
  /// Operating system version.
  final String version;
  /// Hardware identifier.
  final String machine;

  const SystemInformation(this.operatingSystemName, this.nodeName, this.release,
                          this.version, this.machine);

  toString() => '$operatingSystemName $release $version $machine $nodeName';
}

abstract class System {
  int socket(int domain, int type, int protocol);
  InternetAddress lookup(String host);
  int open(String path, bool read, bool write, bool append);
  TempFile mkstemp(String path);
  int access(String path);
  int unlink(String path);
  int bind(int fd, InternetAddress address, int port);
  int listen(int fd);
  int setsockopt(int fd, int level, int optname, ForeignMemory value);
  int accept(int fd);
  int port(int fd);
  int connect(int fd, InternetAddress address, int port);
  int available(int fd);
  int read(int fd, ByteBuffer buffer, int offset, int length);
  int write(int fd, ByteBuffer buffer, int offset, int length);
  int sendto(int fd, ByteBuffer buffer, InternetAddress target, int port);
  int recvfrom(int fd, ByteBuffer buffer, ForeignMemory sockaddr);
  int shutdown(int fd, int how);
  int close(int fd);
  int lseek(int fd, int offset, int whence);
  void sleep(int milliseconds);
  void memcpy(var dest, int destOffset, var src, int srcOffset, int length);
  Errno errno();
  int setBlocking(int fd, bool blocking);
  int setCloseOnExec(int fd, bool closeOnExec);
  SystemInformation info();
  int get AF_INET;
  int get AF_INET6;
  int get SOCK_STREAM;
  int get SOCK_DGRAM;
  int get O_RDONLY;
  int get O_WRONLY;
  int get O_RDWR;
  int get O_CREAT;
  int get O_TRUNC;
  int get O_APPEND;
  int get O_CLOEXEC;
  int get O_NONBLOCK;
  int get SOL_SOCKET;
  int get SO_REUSEADDR;
  int get ADDR_INFO_SIZE;
  int get SOCKADDR_STORAGE_SIZE;
  SockAddrIn allocateSockAddrIn();
  SockAddrIn6 allocateSockAddrIn6();
}

class _InternetAddress implements InternetAddress {
  final List<int> _bytes;

  _InternetAddress(this._bytes) {
    assert(_bytes.length == 4 || _bytes.length == 16);
  }

  int get family => isIP4 ? sys.AF_INET : sys.AF_INET6;

  bool get isIP4 => _bytes.length == 4;

  String toString() {
    if (isIP4) {
      return _bytes.join('.');
    } else {
      List<String> parts = new List<String>(8);
      for (int i = 0; i < 8; i++) {
        String first = _bytes[i * 2].toRadixString(16);
        String second = _bytes[i * 2 + 1].toRadixString(16);
        if (second.length == 1) {
          second = "0$second";
        }
        parts[i] = "$first$second";
      }
      return parts.join(":");
    }
  }
}
