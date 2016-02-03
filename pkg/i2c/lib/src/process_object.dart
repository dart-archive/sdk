// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Support for instantiating an object is a separate process and run
/// funtions in that process opeating on that object.
library process_object;

import 'dart:dartino';

/// Instantiate an object in a process.
///
/// ```
/// class Adder {
///   add(a, b) => return a + b;
/// }
///
/// main() {
///   // Create a ProcessObject with an instance of Adder.
///   var adder = new ProcessObject((_) => new Adder());
///
///   while(true) {
///     // Run the closure in the separate process to invoke the add method.
///     var result = adder.run((o) => o.add(1, 2));
///     print('Result: $r');
///   }
/// }
/// ```
///
/// As the closures for both creating the object instance and for running
/// functions are passed to another process they must be immutable.
class ProcessObject {
  final Port _port;

  const ProcessObject._(this._port);

  /// Create an object in a separate process.
  ///
  /// In a new process the function [fn] will be invoked with one argument, the
  /// passed [argument].
  ///
  /// The return value of calling [fn] is the object hosted by the process.
  factory ProcessObject(Function fn, [argument]) {
    var channel = new Channel();
    var tempPort = new Port(channel);
    Process.spawn(() => _spawn(tempPort, fn, argument));
    var port = channel.receive();
    if (port is! Port) throw port;
    return new ProcessObject._(port);
  }

  /// Run the function [fn] in the process where the object was instantiated.
  ///
  /// The function must take one argument, which will be the object.
  dynamic run(Function fn) {
    if (!isImmutable(fn)) {
      throw new ArgumentError('Passed function is not immutable');
    }

    // Send closure together with result port.
    var channel = new Channel();
    var port = new Port(channel);
    _port.send((object) {
      try {
        var result = fn(object);
        port.send(result);
      } catch (e) {
        port.send(new _ProcessObjectException(e));
      }
    });

    // receive and process the result.
    var result = channel.receive();
    if (result is _ProcessObjectException) throw result.exception;
    return result;
  }

  // TODO: Add support for shutting down.
}

// Internal class to signal exceptions when running a function in the process.
class _ProcessObjectException {
  final exception;
  const _ProcessObjectException(this.exception);
}

// Internal function to create the new process and run the instantiation there.
void _spawn(port, fn, argument) {
  var channel;
  var object;
  try {
    object = fn(argument);
    channel = new Channel();
    port.send(new Port(channel));
  } catch (e) {
    port.send(e);
  }

  // Invoke the received closures.
  while (true) {
    // No need for try/catch here. All closures received here are from
    // calls to `run`, which will catch all exceptions.
    var fn = channel.receive();
    fn(object);
  }
}
