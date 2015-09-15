// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

library service_one;

import "dart:fletch";
import "dart:fletch.ffi";
import "dart:service" as service;

final Channel _channel = new Channel();
final Port _port = new Port(_channel);
final ForeignFunction _postResult = ForeignLibrary.main.lookup("PostResultToService");

bool _terminated = false;
ServiceOne _impl;

abstract class ServiceOne {
  int echo(int arg);

  static void initialize(ServiceOne impl) {
    if (_impl != null) {
      throw new UnsupportedError("Cannot re-initialize");
    }
    _impl = impl;
    _terminated = false;
    service.register("ServiceOne", _port);
  }

  static bool hasNextEvent() {
    return !_terminated;
  }

  static void handleNextEvent() {
    var request = _channel.receive();
    switch (request.getInt32(0)) {
      case _TERMINATE_METHOD_ID:
        _terminated = true;
        _postResult.vcall$1(request);
        break;
      case _ECHO_METHOD_ID:
        var result = _impl.echo(request.getInt32(56));
        request.setInt32(56, result);
        _postResult.vcall$1(request);
        break;
      default:
        throw new UnsupportedError("Unknown method");
    }
  }

  static const int _TERMINATE_METHOD_ID = 0;
  static const int _ECHO_METHOD_ID = 1;
}
