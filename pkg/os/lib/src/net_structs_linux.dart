// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Accessor classes to read and write networking related structures.

part of os;

class LinuxAddrInfo extends AddrInfo {
  LinuxAddrInfo() : super._();
  LinuxAddrInfo.fromAddress(int address) : super._fromAddress(address);

  ForeignMemory get addr {
    int offset = _addrlenOffset + wordSize;
    return new ForeignMemory.fromAddress(getWord(offset), addrlen);
  }

  get canonname {
    int offset = _addrlenOffset + wordSize * 2;
    return getWord(offset);
  }

  AddrInfo get next {
    int offset = _addrlenOffset + wordSize * 3;
    return new LinuxAddrInfo.fromAddress(getWord(offset));
  }
}
