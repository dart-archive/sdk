// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.fletch.os;

const int READ_EVENT        = 1 << 0;
const int WRITE_EVENT       = 1 << 1;
const int CLOSE_EVENT       = 1 << 2;
const int ERROR_EVENT       = 1 << 3;

abstract class EventHandler {
  int addToEventHandler(int fd);
  int removeFromEventHandler(int fd);
  int setPortForNextEvent(int fd, Port port, int mask);

  static int eventHandler = _getEventHandler();
  @fletch.native static int _getEventHandler() {
    throw new UnsupportedError('_getEventHandler');
  }
  @fletch.native static int _incrementPortRef(Port port) {
    throw new ArgumentError();
  }
}

final EventHandler eventHandler = getEventHandler();

EventHandler getEventHandler() {
  switch (Foreign.platform) {
    case Foreign.ANDROID:
    case Foreign.LINUX:
      return new LinuxEventHandler();
    case Foreign.MACOS:
      return new MacOSEventHandler();
    default:
      throw "Event handler not supported for ${Foreign.platform}";
  }
}
