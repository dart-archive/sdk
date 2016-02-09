// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of os;

const String notSupported = "Not supported on FreeRTOS";

class FreeRTOSSystem implements System {
  int get AF_INET => throw new UnsupportedError(notSupported);
  int get AF_INET6 => throw new UnsupportedError(notSupported);

  int get SOCK_STREAM => throw new UnsupportedError(notSupported);
  int get SOCK_DGRAM => throw new UnsupportedError(notSupported);

  int get O_RDONLY => throw new UnsupportedError(notSupported);
  int get O_WRONLY => throw new UnsupportedError(notSupported);
  int get O_RDWR => throw new UnsupportedError(notSupported);
  int get O_CREAT => throw new UnsupportedError(notSupported);
  int get O_TRUNC => throw new UnsupportedError(notSupported);
  int get O_APPEND => throw new UnsupportedError(notSupported);
  int get O_CLOEXEC => throw new UnsupportedError(notSupported);
  int get O_NONBLOCK => throw new UnsupportedError(notSupported);

  int get SOL_SOCKET => throw new UnsupportedError(notSupported);

  int get SO_REUSEADDR => throw new UnsupportedError(notSupported);

  int get ADDR_INFO_SIZE => throw new UnsupportedError(notSupported);

  int get SOCKADDR_STORAGE_SIZE => throw new UnsupportedError(notSupported);

  int socket(int domain, int type, int protocol) {
    throw new UnsupportedError(notSupported);
  }

  InternetAddress lookup(String host) {
    throw new UnsupportedError(notSupported);
  }

  int open(String path, bool read, bool write, bool append) {
    throw new UnsupportedError(notSupported);
  }

  int lseek(int fd, int offset, int whence) {
    throw new UnsupportedError(notSupported);
  }

  TempFile mkstemp(String path) {
    throw new UnsupportedError(notSupported);
  }

  int access(String path) {
    throw new UnsupportedError(notSupported);
  }

  int unlink(String path) {
    throw new UnsupportedError(notSupported);
  }

  int bind(int fd, _InternetAddress address, int port) {
    throw new UnsupportedError(notSupported);
  }

  int listen(int fd) {
    throw new UnsupportedError(notSupported);
  }

  int setsockopt(int fd, int level, int optname, ForeignMemory value) {
    throw new UnsupportedError(notSupported);
  }

  int accept(int fd) {
    throw new UnsupportedError(notSupported);
  }

  int port(int fd) {
    throw new UnsupportedError(notSupported);
  }

  int connect(int fd, _InternetAddress address, int port) {
    throw new UnsupportedError(notSupported);
  }

  int setBlocking(int fd, bool blocking) {
    throw new UnsupportedError(notSupported);
  }

  int setCloseOnExec(int fd, bool closeOnExec) {
    throw new UnsupportedError(notSupported);
  }

  int available(int fd) {
    throw new UnsupportedError(notSupported);
  }

  int read(int fd, ByteBuffer buffer, int offset, int length) {
    throw new UnsupportedError(notSupported);
  }

  int write(int fd, ByteBuffer buffer, int offset, int length) {
    throw new UnsupportedError(notSupported);
  }

  int sendto(int fd, ByteBuffer buffer, InternetAddress target, int port) {
    throw new UnsupportedError(notSupported);
  }

  int recvfrom(int fd, ByteBuffer buffer, ForeignMemory sockaddr) {
    throw new UnsupportedError(notSupported);
  }

  void memcpy(var dest,
              int destOffset,
              var src,
              int srcOffset,
              int length) {
    throw new UnsupportedError(notSupported);
  }

  int shutdown(int fd, int how) {
    throw new UnsupportedError(notSupported);
  }

  int close(int fd) {
    throw new UnsupportedError(notSupported);
  }

  void sleep(int milliseconds) {
    throw new UnsupportedError(notSupported);
  }

  int errno() {
    throw new UnsupportedError(notSupported);
  }

  String strerror(int errno) {
    throw new UnsupportedError(notSupported);
  }

  PosixSockAddrIn allocateSockAddrIn() {
    throw new UnsupportedError(notSupported);
  }

  PosixSockAddrIn6 allocateSockAddrIn6() {
    throw new UnsupportedError(notSupported);
  }

  SystemInformation info() {
    return new SystemInformation('FreeRTOS', '', '', '8.2.1', '');
  }
}
