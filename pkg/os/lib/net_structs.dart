// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Accessor classes to read and write networking related structures.

part of os;

/// The AddrInfo class wraps the native struct `addrinfo`.
///
/// This structure is platform specific (the name and address fields are swapped
/// on MacOS compared to Linux).
abstract class AddrInfo extends Struct {
  factory AddrInfo() {
    switch (Foreign.platform) {
      case Foreign.LINUX: return new LinuxAddrInfo();
      case Foreign.MACOS: return new MacOSAddrInfo();
      case Foreign.ANDROID: return new AndroidAddrInfo();
      default:
        throw "Unsupported platform for dart:io";
    }
  }

  factory AddrInfo.fromAddress(int address) {
    switch (Foreign.platform) {
      case Foreign.LINUX: return new LinuxAddrInfo.fromAddress(address);
      case Foreign.MACOS: return new MacOSAddrInfo.fromAddress(address);
      case Foreign.ANDROID: return new AndroidAddrInfo.fromAddress(address);
      default:
        throw "Unsupported platform for dart:io";
    }
  }

  AddrInfo._() : super(sys.ADDR_INFO_SIZE);
  AddrInfo._fromAddress(int address) : super.fromAddress(address, 8);

  int get _addrlenOffset => 16;

  int get flags => getInt32(0);
  int get family => getInt32(4);
  void set family(int value) { setInt32(4, value); }
  int get socktype => getInt32(8);
  int get protocol => getInt32(12);

  int get addrlen => getInt32(_addrlenOffset);

  ForeignMemory get addr;
  get canonname;
  AddrInfo get next;
}

class Accessor {
  final ForeignMemory buffer;
  final int offset;

  Accessor(this.buffer, this.offset);

  /// Calculate the absolute address in [buffer].
  int adr(int relative) => relative + offset;

  void free() => buffer.free();
}

abstract class SockAddrStorage {
  int get family;
  set family(int family);
}

abstract class SockAddrIn extends SockAddrStorage {
  int get port;
  set port(int port);
  InternetAddress get address;
  set address(InternetAddress address);
}

abstract class SockAddrIn6 extends SockAddrIn {
  int get flowId;
  set flowId(int flowId);
  int get scopeId;
  set scopeId(int scopeId);
}
