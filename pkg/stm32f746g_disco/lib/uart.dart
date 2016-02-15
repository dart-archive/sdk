// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32f746g.uart;

import 'dart:dartino.ffi';
import 'dart:typed_data';
import 'dart:dartino.os';
import 'dart:dartino' hide sleep;

final _uartOpen = ForeignLibrary.main.lookup('uart_open');
final _uartRead = ForeignLibrary.main.lookup('uart_read');
final _uartWrite = ForeignLibrary.main.lookup('uart_write');
final _uartGetError = ForeignLibrary.main.lookup('uart_get_error');

class Uart {
  int _handle;
  Port _port;
  Channel _channel;

  Uart() {
    _handle = _uartOpen.icall$0();
    _channel = new Channel();
    _port = new Port(_channel);
  }

  ForeignMemory _getForeign(ByteBuffer buffer) {
    var b = buffer;
    return b.getForeign();
  }

  ByteBuffer readNext() {
    int event = 0;
    while (event & READ_EVENT == 0) {
      eventHandler.registerPortForNextEvent(
          _handle, _port, READ_EVENT | ERROR_EVENT);
      event = _channel.receive();
      if (event & ERROR_EVENT != 0) {
        // TODO(sigurdm): Find the right way of handling errors.
        print("Error ${_uartGetError.icall$1(_handle)}.");
      }
    }

    var mem = new ForeignMemory.allocated(10);
    try {
      var read = _uartRead.icall$3(_handle, mem, 10);
      var result = new Uint8List(read);
      mem.copyBytesToList(result, 0, read, 0);
      return result.buffer;
    } finally {
      mem.free();
    }
  }

  void write(ByteBuffer data, [int offset = 0, int length]) {
    _write(_getForeign(data), offset, length ?? (data.lengthInBytes - offset));
  }

  void writeString(String message) {
    var mem = new ForeignMemory.fromStringAsUTF8(message);
    try {
      // Don't write the terminating \0.
      _write(mem, 0, mem.length - 1);
    } finally {
      mem.free();
    }
  }

  void _write(ForeignMemory mem, int offset, int size) {
    int written = 0;
    while (written < size) {
      written += _uartWrite.icall$4(_handle, mem, offset, size);
      if (written == size) break;
      // We do not listen for errors here, because writing cannot fail.
      eventHandler.registerPortForNextEvent(_handle, _port, WRITE_EVENT);
      _channel.receive();
    }
  }
}