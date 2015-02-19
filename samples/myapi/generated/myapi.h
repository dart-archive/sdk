// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef MYAPI_H_
#define MYAPI_H_

#include "cc/myapi_service.h"

class MyObject;

class MyApi {
 public:
  static MyApi create() {
    MyApiService::setup();
    int api = MyApiService::create();
    return MyApi(api);
  }

  void destroy() {
    MyApiService::destroy(api_);
    MyApiService::tearDown();
  }

  inline MyObject foo();

 private:
  int api_;

  explicit MyApi(int api) : api_(api) { }
};

class MyObject {
 public:
  void funk(MyObject o) {
    // TODO(kasperl): Assert that o is from same api as 'this'.
    MyApiService::MyObject_funk(api_, id_, o.id_);
  }

 private:
  int api_;
  int id_;

  MyObject(int api, int id) : api_(api), id_(id) { }

  friend class MyApi;
};

inline MyObject MyApi::foo() {
  int id = MyApiService::foo(api_);
  return MyObject(api_, id);
}

#endif  // MYAPI_H_