// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.button;

import 'dart:dartino.ffi';
import 'dart:dartino.os';
import 'dart:dartino' hide sleep;

final _buttonOpen = ForeignLibrary.main.lookup('button_open');
final _buttonNotifyRead = ForeignLibrary.main.lookup('button_notify_read');

class Button {
  int _handle;
  Port _port;
  Channel _channel;

  Button() {
    _handle = _buttonOpen.icall$0();
    _channel = new Channel();
    _port = new Port(_channel);
  }

  void waitForPress() {
    eventHandler.registerPortForNextEvent(_handle, _port, 1);
    int event = _channel.receive();
    _buttonNotifyRead.vcall$1(_handle);
    if (event & 1 == 0) {
      print("Faulty event from button");
    }
  }
}
