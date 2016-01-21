// Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32f746g.uart;

import 'dart:fletch.ffi';
import 'dart:typed_data';

final _uart_write = ForeignLibrary.main.lookup('uart_write');
final _uart_read = ForeignLibrary.main.lookup('uart_read');

class Uart {
  ForeignMemory _getForeign(ByteBuffer buffer) {
    var b = buffer;
    return b.getForeign();
  }

  ByteBuffer readNext() {
    var mem = new ForeignMemory.allocated(10);
    try {
      var read = _uart_read.icall$2(mem, 10);
      assert(read > 0);
      var result = new Uint8List(read);
      mem.copyBytesToList(result, 0, read, 0);
      return result.buffer;
    } finally {
      mem.free();
    }
  }

  void write(ByteBuffer data) {
    var bytes = data.lengthInBytes;
    _uart_write.icall$2(_getForeign(data), bytes);
  }

  void writeByte(int byte) {
    var mem = new ForeignMemory.allocated(1);
    mem.setUint8(0, byte);
    try {
      _uart_write.icall$2(mem, 1);
    } finally {
      mem.free();
    }
  }

  int writeString(String message) {
    var mem = new ForeignMemory.fromStringAsUTF8(message);
    try {
      // Don't write the terminating \0.
      _uart_write.icall$2(mem, mem.length - 1);
    } finally {
      mem.free();
    }
  }
}

