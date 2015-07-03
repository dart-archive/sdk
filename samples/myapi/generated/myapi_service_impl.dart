// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart/myapi_service.dart';
import '../myapi_impl.dart' as impl;

class ApiService {
  final Map<int, List> objects = {};

  int create() {
    int api = objects.length;
    objects[api] = new List();
    return api;
  }

  void destroy(int api) {
    objects[api].clear();
  }

  int register(int api, Object o) {
    List list = objects[api];
    int index = list.indexOf(o);
    if (index >= 0) return index;
    index = list.length;
    list.add(o);
    return index;
  }
}

class MyApiServiceImpl extends ApiService implements MyApiService {
  int foo(int api) {
    impl.MyObject result = impl.foo();
    return register(api, result);
  }

  void MyObject_funk(int api, int id, int o) {
    impl.MyObject object = objects[api][id];
    object.funk(objects[api][o]);
  }
}

void main() {
  var impl = new MyApiServiceImpl();
  MyApiService.initialize(impl);
  while (MyApiService.hasNextEvent()) {
    MyApiService.handleNextEvent();
  }
}
