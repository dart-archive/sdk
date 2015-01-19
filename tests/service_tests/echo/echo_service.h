// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// TODO(ager): This file should be auto-generated from something like.
//
// service EchoService {
//   Echo(int32) : int32;
// }

#ifndef _TESTS_SERVICE_TESTS_ECHO_H
#define _TESTS_SERVICE_TESTS_ECHO_H

#include "include/service_api.h"

class EchoService {
 public:
  static void Setup();
  static void TearDown();
  static ServiceApiValueType Echo(ServiceApiValueType arg);
  static void EchoAsync(int arg, ServiceApiCallback callback);
};

#endif  // _TESTS_SERVICE_TESTS_ECHO_H
