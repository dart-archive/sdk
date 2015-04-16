// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library isolate;

class Isolate {

  final Channel _channel;
  bool _isDone;
  var _result;

  Isolate._internal(this._channel);

  /**
   * Join an isolate by waiting for the result of
   * calling the spawned function.
   */
  join() {
    if (!_isDone) {
      _result = _channel.receive();
      _isDone = true;
    }
    return _result;
  }

  /**
   * Spawn a top-level function as a new isolate.
   */
  static Isolate spawn(Function fn, [argument]) {
    Channel channel = new Channel();
    Process.spawn(_entry, new Port(channel));
    Port port = channel.receive();
    port.send(fn);
    port.send(argument);
    return new Isolate._internal(channel);
  }

  static void _entry(Port port) {
    Channel channel = new Channel();
    port.send(new Port(channel));
    var fn = channel.receive();
    var argument = channel.receive();
    var result = (argument == null) ? fn() : fn(argument);
    Process.exit(value: result, to: port);
  }

}
