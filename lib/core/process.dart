// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

class Process {
  /**
   * Spawn a top-level function.
   */
  static spawn(Function fn, [argument]) => _spawn(_entry, fn, argument);

  // Low-level entry for spawned processes.
  static void _entry(fn, argument) {
    if (argument == null) {
      _runToEnd(fn);
    } else {
      _runToEnd(() => fn(argument));
    }
  }

  // Low-level helper function for spawning.
  static _spawn(Function entry, Function fn, argument) native catch (error) {
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
