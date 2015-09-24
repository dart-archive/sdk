// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of os;

class LinuxAddrInfo extends AddrInfo {
  LinuxAddrInfo() : super._();
  LinuxAddrInfo.fromAddress(int address) : super._fromAddress(address);

  ForeignMemory get ai_addr {
    int offset = _addrlenOffset + wordSize;
    return new ForeignMemory.fromAddress(getWord(offset), ai_addrlen);
  }

  get ai_canonname {
    int offset = _addrlenOffset + wordSize * 2;
    return getWord(offset);
  }

  AddrInfo get ai_next {
    int offset = _addrlenOffset + wordSize * 3;
    return new LinuxAddrInfo.fromAddress(getWord(offset));
  }
}

class LinuxSystem extends PosixSystem {
  static final ForeignFunction _lseekLinux =
      ForeignLibrary.main.lookup("lseek64");
  static final ForeignFunction _openLinux =
      ForeignLibrary.main.lookup("open64");

  int get FIONREAD => 0x541B;

  int get SOL_SOCKET => 1;

  int get SO_REUSEADDR => 2;

  ForeignFunction get _lseek => _lseekLinux;
  ForeignFunction get _open => _openLinux;
}
