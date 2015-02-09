// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

library echo_service;

import "dart:ffi";
import "dart:service" as service;

final Channel _channel = new Channel();
final Port _port = new Port(_channel);
final Foreign _postResult = Foreign.lookup("PostResultToService");

bool _terminated = false;
EchoService _impl;

abstract class EchoService {
  int echo(int n);
  int sum(int x, int y);

  static void initialize(EchoService impl) {
    if (_impl != null) {
      throw new UnsupportedError();
    }
    _impl = impl;
    _terminated = false;
    service.register("EchoService", _port);
  }

  static bool hasNextEvent() {
    return !_terminated;
  }

  static void handleNextEvent() {
    var request = _channel.receive();
    switch (request.getInt32(0)) {
      case _TERMINATE_METHOD_ID:
        _terminated = true;
        _postResult.icall$1(request);
        break;
      case _ECHO_METHOD_ID:
        var result = _impl.echo(request.getInt32(32));
        request.setInt32(32, result);
        _postResult.icall$1(request);
        break;
      case _SUM_METHOD_ID:
        var result = _impl.sum(request.getInt16(32), request.getInt32(36));
        request.setInt32(32, result);
        _postResult.icall$1(request);
        break;
      default:
        throw UnsupportedError();
    }
  }

  const int _TERMINATE_METHOD_ID = 0;
  const int _ECHO_METHOD_ID = 1;
  const int _SUM_METHOD_ID = 2;
}
