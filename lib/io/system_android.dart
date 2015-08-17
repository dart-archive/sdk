// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of system;

class AndroidAddrInfo extends AddrInfo {
  AndroidAddrInfo() : super._();
  AndroidAddrInfo.fromAddress(int address) : super._fromAddress(address);

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
    return new AndroidAddrInfo.fromAddress(getWord(offset));
  }
}
