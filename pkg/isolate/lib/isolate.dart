// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library isolate;

Function bind(Function fn, argument) {
  return new _BoundFunction(fn, argument);
}

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
   * Spawn a top-level function as a new isolate.
   */
  static Isolate spawn(Function fn) {
    Channel channel = new Channel();
    Process.spawn(_entry, new Port(channel));
    Port port = channel.receive();

    // TODO(kasperl): Once we can send immutable bound functions
    // we should just send 'fn' here.
    if (fn is _BoundFunction) {
      List arguments = [];
      port.send(fn._collect(arguments));
      port.sendMultiple(arguments);
    } else {
      port.send(fn);
      port.send(const []);
    }

    return new Isolate._internal(channel);
  }

  static void _entry(Port port) {
    Channel channel = new Channel();
    port.send(new Port(channel));
    var fn = channel.receive();

    // TODO(kasperl): Once we can send immutable bound functions
    // we should be able to simply call 'fn' here.
    var arguments = channel.receive();
    var result = Function.apply(fn, arguments);

    Process.exit(value: result, to: port);
  }
}

class _BoundFunction implements Function {
  final Function _fn;
  final _argument;
  _BoundFunction(this._fn, this._argument);

  call() {
    List arguments = [];
    Function fn = _collect(arguments);
    return Function.apply(fn, arguments);
  }

  Function _collect(List arguments) {
    Function result = (_fn is _BoundFunction)
        ? _fn._collect(arguments)
        : _fn;
    arguments.add(_argument);
    return result;
  }
}
