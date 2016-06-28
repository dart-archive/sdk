// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Accessor classes to read and write networking related structures.

part of os;

abstract class PosixSockAddrStorage extends Accessor
  implements SockAddrStorage {
  PosixSockAddrStorage(ForeignMemory buffer, int offset)
    : super(buffer, offset);

  int get family => buffer.getUint16(adr(0));

  set family(int family) {
    buffer.setUint16(adr(0), family);
  }
}

class PosixSockAddrIn extends PosixSockAddrStorage implements SockAddrIn {
  PosixSockAddrIn(ForeignMemory buffer, int offset) : super(buffer, offset);

  int get port => buffer.getUint8(adr(2)) * 256 + buffer.getUint8(adr(3));

  set port(int port) {
    buffer.setUint8(adr(2), port >> 8);
    buffer.setUint8(adr(3), port & 0xFF);
  }

  InternetAddress get address {
    List<int> digits = new Uint8List(4);
    buffer.copyBytesToList(digits, adr(4), adr(4 + 4), 0);
    return new InternetAddress(digits);
  }

  set address(_InternetAddress address) {
    buffer.copyBytesFromList(address._bytes, adr(4), adr(4 + 4), 0);
  }
}

class PosixSockAddrIn6 extends PosixSockAddrIn implements SockAddrIn6 {
  PosixSockAddrIn6(ForeignMemory buffer, int offset) : super(buffer, offset);

  int get flowId => buffer.getUint32(adr(4));

  set flowId(int flowId) {
    buffer.setUint32(adr(4), flowId);
  }

  InternetAddress get address {
    List<int> digits = new Uint8List(16);
    buffer.copyBytesToList(digits, adr(8), adr(8 + 16), 0);
    return new InternetAddress(digits);
  }

  set address(_InternetAddress address) {
    buffer.copyBytesFromList(address._bytes, adr(8), adr(8 + 16), 0);
  }

  int get scopeId => buffer.getUint32(adr(24));

  set scopeId(int scopeId) {
    buffer.setUint32(adr(24));
  }
}
