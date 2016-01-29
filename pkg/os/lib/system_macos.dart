// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of os;

class MacOSSystem extends PosixSystem {
  static final ForeignFunction _lseekMac = ForeignLibrary.main.lookup("lseek");
  static final ForeignFunction _openMac = ForeignLibrary.main.lookup("open");

  int get AF_INET6 => 30;

  int get O_NONBLOCK => 4;
  int get O_APPEND => 8;
  int get O_CREAT => 512;
  int get O_TRUNC => 1024;
  int get O_CLOEXEC => 16777216;

  int get FIONREAD => 0x4004667f;

  int get SOL_SOCKET => 0xffff;

  int get SO_REUSEADDR => 0x4;

  // The size of fields and the struct used by uname.
  // From /usr/include/sys/utsname.h
  int get UTSNAME_LENGTH => 256;
  int get SIZEOF_UTSNAME => 5 * UTSNAME_LENGTH;

  ForeignFunction get _lseek => _lseekMac;
  ForeignFunction get _open => _openMac;

  int SOCKADDR_IN_SIZE = 16;
  int SOCKADDR_IN6_SIZE = 28;

  MacOSSockAddrIn allocateSockAddrIn() {
    ForeignMemory buffer = new ForeignMemory.allocated(SOCKADDR_IN_SIZE);
    return new MacOSSockAddrIn(buffer, 0);
  }

  MacOSSockAddrIn6 allocateSockAddrIn6() {
    ForeignMemory buffer = new ForeignMemory.allocated(SOCKADDR_IN6_SIZE);
    return new MacOSSockAddrIn6(allocateSockAddrStorageMemory(), 0);
  }
}
