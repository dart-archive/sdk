// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.dartino.os;

// The event source is ready for reading.
const int READ_EVENT        = 1 << 0;
// The event source is ready for writing.
const int WRITE_EVENT       = 1 << 1;
// The event source has been closed.
const int CLOSE_EVENT       = 1 << 2;
// The event source signaled an error.
const int ERROR_EVENT       = 1 << 3;

class EventHandler {
  EventHandler._internal() {
    // The actual initialization is done in the VM.
  }

  /**
   * Register the port [port] to be notified when the event source [id] is
   * triggered the next time. [event_kinds] specifies a bit-mask to select
   * the kinds of events that should trigger a notification.
   *
   * Registration is one-shot, i.e., after [port] has been notified, it has
   * to be registered again to receive further notifications.
   * Registration is single-subscriber, i.e., only one [port] object may be
   * registered for an event source at any given point.
   *
   * Currently supported event kinds are [READ_EVENT], [WRITE_EVENT],
   * [CLOSE_EVENT] and [ERROR_EVENT];
   *
   * The supported types of event sources is platform dependent.
   * The supported types of event kinds is event source dependent.
   *
   * An [ArgumentError] is thrown if the event source is not supported.
   * A [StateError] is thrown if the port could not be registered.
   */
  void registerPortForNextEvent(Object id, Port port, int mask) {
    if (port is! Port) throw new ArgumentError(port);
    if (mask is! int) throw new ArgumentError(mask);
    _eventHandlerAdd(id, port, mask);
  }

  @dartino.native static void _eventHandlerAdd(Object id, Port port,
      int event_kinds) {
    switch (dartino.nativeError) {
      case dartino.wrongArgumentType:
        // We check the other arguments in [registerPortForNextEvent], so it
        // must be the id that is wrong.
        throw new ArgumentError(id);
      case dartino.indexOutOfBounds:
        // We get index out of bounds when we could not register the port.
        throw new StateError("The port could not be registered.");
      case dartino.illegalState:
        // We get an illegal state when the flags were not supported.
        throw new StateError("Operation not supported.");
      default:
        throw dartino.nativeError;
    }
  }
}

final EventHandler eventHandler = new EventHandler._internal();
