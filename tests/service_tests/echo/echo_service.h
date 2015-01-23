// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#ifndef ECHO_SERVICE_H
#define ECHO_SERVICE_H

#include "include/service_api.h"

class EchoService {
 public:
  static void Setup();
  static void TearDown();
  static ServiceApiValueType Echo(ServiceApiValueType arg);
  static void EchoAsync(ServiceApiValueType arg, ServiceApiCallback callback);
};

#endif  // ECHO_SERVICE_H
