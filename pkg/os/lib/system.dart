// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of os;

const int O_RDONLY  = 0;
const int O_WRONLY  = 1;
const int O_RDWR    = 2;
const int O_CREAT   = 64;
const int O_TRUNC   = 512;
const int O_APPEND  = 1024;
const int O_CLOEXEC = 524288;

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
  int shutdown(int fd, int how);
  int close(int fd);
  int lseek(int fd, int offset, int whence);
  void sleep(int milliseconds);
  void memcpy(var dest, int destOffset, var src, int srcOffset, int length);
  Errno errno();
  int setBlocking(int fd, bool blocking);
  int setReuseaddr(int fd);
  int setCloseOnExec(int fd, bool closeOnExec);
  SystemInformation info();
  int get SOL_SOCKET;
  int get SO_RESUSEADDR;
}

class _InternetAddress extends InternetAddress {
  final List<int> _bytes;
  _InternetAddress(this._bytes);
}
