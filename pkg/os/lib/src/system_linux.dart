// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of os;

class LinuxSystem extends PosixSystem {
  static final ForeignFunction _lseekLinux =
      ForeignLibrary.main.lookup("lseek64");
  static final ForeignFunction _openLinux =
      ForeignLibrary.main.lookup("open64");

  static final bool isMips = sys.info().machine == 'mips';

  int get AF_INET6 => 10;

  int get O_CREAT => isMips ? 256 : 64;
  int get O_TRUNC => 512;
  int get O_APPEND => isMips ? 8 : 1024;
  int get O_NONBLOCK => isMips ? 128 : 2048;
  int get O_CLOEXEC => 524288;

  int get FIONREAD => isMips ? 0x467f : 0x541b;

  int get SOL_SOCKET => isMips ? 65535 : 1;

  int get SO_REUSEADDR => isMips ? 4 : 2;

  // The size of fields and the struct used by uname.
  // From /usr/include/sys/utsname.h
  int get UTSNAME_LENGTH => 65;
  int get SIZEOF_UTSNAME => 6 * UTSNAME_LENGTH;

  ForeignFunction get _lseek => _lseekLinux;
  ForeignFunction get _open => _openLinux;
}
