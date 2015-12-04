// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Accessor classes to read and write networking related structures.

part of os;

class MacOSAddrInfo extends AddrInfo {
  MacOSAddrInfo() : super._();
  MacOSAddrInfo.fromAddress(int address) : super._fromAddress(address);

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
    return new MacOSAddrInfo.fromAddress(getWord(offset));
  }
}

/// On MacOS, the [family] field is only 8 bits and there is an additional field
/// [len].
abstract class MacOSSockAddrStorageMixin {
  ForeignMemory get buffer;
  int get offset;
  int adr(int relative);

  int get len => buffer.getUint8(adr(0));
  set len(int len) {
    buffer.setUint8(adr(0), len);
  }

  int get family => buffer.getUint8(adr(1));
  set family(int family) {
    buffer.setUint8(adr(1), family);
  }
}

class MacOSSockAddrIn = PosixSockAddrIn with MacOSSockAddrStorageMixin;

class MacOSSockAddrIn6 = PosixSockAddrIn6 with MacOSSockAddrStorageMixin;
