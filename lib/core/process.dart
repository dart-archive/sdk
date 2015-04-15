// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

class Process {
  /**
   * Spawn a top-level function.
   */
  static void spawn(Function fn, [argument]) {
    _spawn(_entry, fn, argument);
  }

  // Low-level entry for spawned processes.
  static void _entry(fn, argument) {
    if (argument == null) {
      _runToEnd(fn);
    } else {
      _runToEnd(() => fn(argument));
    }
  }

  /**
   * Exit the current process. If a non-null [to] port is provided,
   * the process will send the provided [value] to the [to] port as
   * its final action.
   */
  static void exit({value, Port to}) {
    try {
      if (to != null) to._sendExit(value);
    } finally {
      fletch.yield(true);
    }
  }

  // Low-level helper function for spawning.
  static void _spawn(Function entry, Function fn, argument)
      native catch (error) {
    throw new ArgumentError();
  }

  static void _handleMessages() {
    Channel channel;
    while ((channel = _queueGetChannel()) != null) {
      var message = _queueGetMessage();
      channel.send(message);
    }
  }

  static _queueGetMessage() native;
  static int _queueGetChannel() native;
}
