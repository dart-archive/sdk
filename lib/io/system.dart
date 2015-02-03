// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library system;

import 'dart:ffi';
import 'dart:io';

part 'system_linux.dart';
part 'system_macos.dart';
part 'system_posix.dart';

const int READ_EVENT        = 1 << 0;
const int WRITE_EVENT       = 1 << 1;
const int CLOSE_EVENT       = 1 << 2;
const int ERROR_EVENT       = 1 << 3;

const int O_RDONLY  = 0;
const int O_RDWR    = 2;
const int O_CREAT   = 64;
const int O_TRUNC   = 512;
const int O_CLOEXEC = 524288;

const int SHUT_RD   = 0;
const int SHUT_WR   = 1;
const int SHUT_RDWR = 2;

final System sys = getSystem();

System getSystem() {
  switch (Foreign.platform) {
    case Foreign.LINUX: return new LinuxSystem();
    case Foreign.MACOS: return new MacOSSystem();
    default:
      throw "Unsupported system for dart:io";
  }
}

// The result of opening a temporary file is both the file descriptor and the
// path.
class TempFile {
  final int fd;
  final String path;
  TempFile(this.fd, this.path);
}

abstract class System {
  int socket();
  InternetAddress lookup(String host);
  int open(String path, bool write, bool append);
  TempFile mkstemp(String path);
  int access(String path);
  int unlink(String path);
  int bind(int fd, InternetAddress address, int port);
  int listen(int fd);
  int setsockopt(int fd, int level, int optname, int value);
  int accept(int fd);
  int port(int fd);
  int connect(int fd, InternetAddress address, int port);
  int available(int fd);
  int read(int fd, ByteBuffer buffer, int offset, int length);
  int write(int fd, ByteBuffer buffer, int offset, int length);
  int shutdown(int fd, int how);
  int close(int fd);
  void sleep(int milliseconds);
  Errno errno();

  int setBlocking(int fd, bool blocking);
  int setReuseaddr(int fd);

  static int eventHandler = _getEventHandler();
  static int _getEventHandler() native;
}

final int hostWordSize = Foreign.bitsPerMachineWord ~/ 8;

class Struct extends Foreign {
  final wordSize;

  Struct(int fields)
      : this.wordSize = hostWordSize,
        super.allocated(fields * hostWordSize);

  Struct.finalize(int fields)
      : this.wordSize = hostWordSize,
        super.allocatedFinalize(fields * hostWordSize);

  Struct.fromAddress(int address, int fields)
      : this.wordSize = hostWordSize,
        super.fromAddress(address, fields * hostWordSize);

  Struct.withWordSize(int fields, wordSize)
      : this.wordSize = wordSize,
        super.allocated(fields * wordSize);

  Struct.withWordSizeFinalize(int fields, wordSize)
      : this.wordSize = wordSize,
        super.allocatedFinalize(fields * wordSize);

  int getWord(int byteOffset) {
    switch (wordSize) {
      case 4: return getInt32(byteOffset);
      case 8: return getInt64(byteOffset);
      default: throw "Unsupported machine word size.";
    }
  }

  int setWord(int byteOffset, int value) {
    switch (wordSize) {
      case 4: return setInt32(byteOffset, value);
      case 8: return setInt64(byteOffset, value);
      default: throw "Unsupported machine word size.";
    }
  }

  int getField(int fieldOffset) => getWord(fieldOffset * wordSize);

  void setField(int fieldOffset, int value) {
    setWord(fieldOffset * wordSize, value);
  }
}

class Struct32 extends Struct {
  Struct32(int fields) : super.withWordSize(fields, 4);
}

class Struct64 extends Struct {
  Struct64(int fields) : super.withWordSize(fields, 8);
  Struct64.finalize(int fields) : super.withWordSizeFinalize(fields, 8);
}
