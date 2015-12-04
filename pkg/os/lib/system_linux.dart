// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of os;

class LinuxSystem extends PosixSystem {
  static final ForeignFunction _lseekLinux =
      ForeignLibrary.main.lookup("lseek64");
  static final ForeignFunction _openLinux =
      ForeignLibrary.main.lookup("open64");

  int get AF_INET6 => 10;

  int get O_CREAT => 64;
  int get O_TRUNC => 512;
  int get O_APPEND => 1024;
  int get O_NONBLOCK => 2048;
  int get O_CLOEXEC => 524288;

  int get FIONREAD => 0x541B;

  int get SOL_SOCKET => 1;

  int get SO_REUSEADDR => 2;

  // The size of fields and the struct used by uname.
  // From /usr/include/sys/utsname.h
  int get UTSNAME_LENGTH => 65;
  int get SIZEOF_UTSNAME => 6 * UTSNAME_LENGTH;

  ForeignFunction get _lseek => _lseekLinux;
  ForeignFunction get _open => _openLinux;
}
