// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "tests/service_tests/echo/echo_shared.h"
#include "tests/service_tests/echo/echo_service.h"

#include <cstdio>

static void Callback(ServiceApiValueType result, void* data) {
  printf("C: async result %d\n", result);
}

static void InteractWithService() {
  EchoService::Setup();
  int result = EchoService::Echo(1);
  printf("C: result %d\n", result);
  result = EchoService::Echo(2);
  printf("C: result %d\n", result);
  EchoService::EchoAsync(3, Callback);
  printf("C: async call with argument 3\n");
  EchoService::EchoAsync(4, Callback);
  printf("C: async call with argument 4\n");
  result = EchoService::Echo(5);
  printf("C: result %d\n", result);
  EchoService::TearDown();
}

int main(int argc, char** argv) {
  if (argc < 2) {
    printf("Usage: %s <snapshot>\n", argv[0]);
    return 1;
  }
  SetupEchoTest(argc, argv);
  InteractWithService();
  TearDownEchoTest();
  return 0;
}
