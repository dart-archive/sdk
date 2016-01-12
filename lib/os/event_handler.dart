// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.fletch.os;

const int READ_EVENT        = 1 << 0;
const int WRITE_EVENT       = 1 << 1;
const int CLOSE_EVENT       = 1 << 2;
const int ERROR_EVENT       = 1 << 3;

class EventHandler {
  EventHandler._internal() {
    // The actual initialization is done in the VM.
  }

  void registerPortForNextEvent(Object id, Port port, int mask) {
    if (port is! Port) throw new ArgumentError(port);
    if (mask is! int) throw new ArgumentError(mask);
    _eventHandlerAdd(id, port, mask);
  }

  @fletch.native static void _eventHandlerAdd(Object id, Port port,
      int flags) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        // We check the other arguments in [registerPortForNextEvent], so it
        // must be the id that is wrong.
        throw new ArgumentError(id);
      case fletch.indexOutOfBounds:
        // We get index out of bounds when we could not register the port.
        throw new StateError("The port could not be registered.");
      case fletch.illegalState:
        // We get an illegal state when the flags were not supported.
        throw new StateError("Operation not supported.");
      default:
        throw fletch.nativeError;
    }
  }
}

final EventHandler eventHandler = new EventHandler._internal();
