// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of os;

class MacOSAddrInfo extends AddrInfo {
  MacOSAddrInfo() : super._();
  MacOSAddrInfo.fromAddress(int address) : super._fromAddress(address);

  get ai_canonname {
    int offset = _addrlenOffset + wordSize;
    return getWord(offset);
  }

  ForeignMemory get ai_addr {
    int offset = _addrlenOffset + wordSize * 2;
    return new ForeignMemory.fromAddress(getWord(offset), ai_addrlen);
  }

  AddrInfo get ai_next {
    int offset = _addrlenOffset + wordSize * 3;
    return new MacOSAddrInfo.fromAddress(getWord(offset));
  }
}

class MacOSSystem extends PosixSystem {
  static final ForeignFunction _lseekMac = ForeignLibrary.main.lookup("lseek");
  static final ForeignFunction _openMac = ForeignLibrary.main.lookup("open");

  int get FIONREAD => 0x4004667f;

  int get SOL_SOCKET => 0xffff;

  int get SO_REUSEADDR => 0x4;

  // The size of fields and the struct used by uname.
  // From /usr/include/sys/utsname.h
  int get UTSNAME_LENGTH => 256;
  int get SIZEOF_UTSNAME => 5 * UTSNAME_LENGTH;

  ForeignFunction get _lseek => _lseekMac;
  ForeignFunction get _open => _openMac;
}
