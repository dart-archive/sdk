// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library isolate;

import 'dart:fletch';

class Isolate {
  final Channel _channel;
  bool _isJoined = false;

  Isolate._internal(this._channel);

  /**
   * Join an isolate by waiting for the result of
   * calling the spawned function.
   */
  join() {
    if (_isJoined) {
      throw new Exception('Cannot join an isolate multiple times.');
    }
    _isJoined = true;

    var result = _channel.receive();
    if (result is _IsolateResult) {
      return result.value;
    } else {
      throw new Exception('Isolate finished without value.');
    }
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
    Process.spawnDetached(() {
      Process.exit(value: new _IsolateResult(function()), to: port);
    }, monitor: port);
    return new Isolate._internal(channel);
  }
}

// Used to distinguish between the result of executing an isolate and it's
// termination signal (we reuse the same Port at the moment).
class _IsolateResult {
  final Object value;

  const _IsolateResult(this.value);
}
