// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Accessor classes to read and write networking related structures.

part of os;

class AndroidAddrInfo extends AddrInfo {
  AndroidAddrInfo() : super._();
  AndroidAddrInfo.fromAddress(int address) : super._fromAddress(address);

  get canonname {
    int offset = _addrlenOffset + wordSize;
    return getWord(offset);
  }

  ForeignMemory get addr {
    int offset = _addrlenOffset + wordSize * 2;
    return new ForeignMemory.fromAddress(getWord(offset), addrlen);
  }

  AddrInfo get next {
    int offset = _addrlenOffset + wordSize * 3;
    return new AndroidAddrInfo.fromAddress(getWord(offset));
  }
}
