// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

library myapi_service;

import "dart:fletch";
import "dart:fletch.ffi";
import "dart:service" as service;

final Channel _channel = new Channel();
final Port _port = new Port(_channel);
final Foreign _postResult = Foreign.lookup("PostResultToService");

bool _terminated = false;
MyApiService _impl;

abstract class MyApiService {
  int create();
  void destroy(int api);
  int foo(int api);
  void MyObject_funk(int api, int id, int o);

  static void initialize(MyApiService impl) {
    if (_impl != null) {
      throw new UnsupportedError("Cannot re-initialize");
    }
    _impl = impl;
    _terminated = false;
    service.register("MyApiService", _port);
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
      case _CREATE_METHOD_ID:
        var result = _impl.create();
        request.setInt32(56, result);
        _postResult.vcall$1(request);
        break;
      case _DESTROY_METHOD_ID:
        _impl.destroy(request.getInt32(56));
        _postResult.vcall$1(request);
        break;
      case _FOO_METHOD_ID:
        var result = _impl.foo(request.getInt32(56));
        request.setInt32(56, result);
        _postResult.vcall$1(request);
        break;
      case _MY_OBJECT_FUNK_METHOD_ID:
        _impl.MyObject_funk(request.getInt32(56), request.getInt32(60), request.getInt32(64));
        _postResult.vcall$1(request);
        break;
      default:
        throw new UnsupportedError("Unknown method");
    }
  }

  static const int _TERMINATE_METHOD_ID = 0;
  static const int _CREATE_METHOD_ID = 1;
  static const int _DESTROY_METHOD_ID = 2;
  static const int _FOO_METHOD_ID = 3;
  static const int _MY_OBJECT_FUNK_METHOD_ID = 4;
}
