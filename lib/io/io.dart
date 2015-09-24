// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.fletch.io;

import 'dart:fletch';
import 'dart:fletch.ffi';
import 'dart:fletch.os';
import 'dart:typed_data';

// The fletch.os library exposes a static 'sys' object for all system calls.

int socket() => sys.socket();
InternetAddress lookup(String host) => sys.lookup(host);
int bind(int fd, InternetAddress address, int port) {
  return sys.bind(fd, address, port);
}
int listen(int fd) => sys.listen(fd);
int setsockopt(int fd, int level, int optname, int value) {
  return sys.setsockopt(fd, level, optname, value);
}
int accept(int fd) => sys.accept(fd);
int port(int fd) => sys.port(fd);
int connect(int fd, InternetAddress address, int port) {
  return sys.connect(fd, address, port);
}
int available(int fd) => sys.available(fd);
int read(int fd, ByteBuffer buffer, int offset, int length) {
  return sys.read(fd, buffer, offset, length);
}
int write(int fd, ByteBuffer buffer, int offset, int length) {
  return sys.write(fd, buffer, offset, length);
}
int close(int fd) => sys.close(fd);
int setBlocking(int fd, bool blocking) => sys.setBlocking(fd, blocking);
// TODO(ajohnsen): Take a Duration?
void sleep(int milliseconds) => sys.sleep(milliseconds);
Errno errno() => sys.errno();
