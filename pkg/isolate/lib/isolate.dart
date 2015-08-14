// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library isolate;

import 'dart:fletch';

class Isolate {
  final Channel _channel;
  bool _isDone = false;
  var _result;

  Isolate._internal(this._channel);

  /**
   * Join an isolate by waiting for the result of
   * calling the spawned function.
   */
  join() {
    if (!_isDone) {
      // TODO(kasperl): This doesn't really work if multiple
      // fibers join the same isolate. Please fix.
      _result = _channel.receive();
      _isDone = true;
    }
    return _result;
  }

  /**
   * Spawn an immutable function as a new isolate.
   */
  static Isolate spawn(Function function) {
    if (!isImmutable(function)) {
      throw new ArgumentError(
          'The function passed to Isolate.spawn() must be immutable.');
    }
    final Channel channel = new Channel();
    final Port port = new Port(channel);
    Process.spawn(() {
      Process.exit(value: function(), to: port);
    });
    return new Isolate._internal(channel);
  }
}
