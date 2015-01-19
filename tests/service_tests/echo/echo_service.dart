// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// TODO(ager): This file should be auto-generated from something like.
//
// service EchoService {
//   Echo(int32) : int32;
// }

library echo_service;

import 'dart:ffi';
import 'dart:service' as Service;

final const int _TERMINATE_METHOD_ID = 0;
final const int _ECHO_METHOD_ID = 1;

final Channel _channel = new Channel();
final Port _port = new Port(_channel);
final Foreign _postResult = Foreign.lookup("PostResultToService");

bool _terminated = false;
EchoServiceInterface _implementation;

abstract class EchoService {
  static void initialize(EchoServiceInterface impl) {
    if (_implementation != null) throw new UnsupportedError();
    _implementation = impl;
    _terminated = false;
    Service.register('Echo', _port);
  }

  static void handleNextEvent() {
    var request = _channel.receive();
    switch (request.getInt32(0)) {
      case _TERMINATE_METHOD_ID:
        _terminated = true;
        _postResult.icall$1(request);
        break;
      case _ECHO_METHOD_ID:
        var result = _implementation.Echo(request.getInt32(4));
        request.setInt32(4, result);
        _postResult.icall$1(request);
        break;
      default:
        throw UnsupportedError();
    }
  }

  static bool hasNextEvent() {
    return !_terminated;
  }

  int Echo(int argument);
}
