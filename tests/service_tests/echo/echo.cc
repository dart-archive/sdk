// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "echo_shared.h"
#include "cc/echo_service.h"

#include <cstdio>

static void EchoCallback(int result) {
  printf("C: echo async result %d\n", result);
}

static void SumCallback(int result) {
  printf("C: sum async result %d\n", result);
}

static void InteractWithService() {
  EchoService::Setup();
  int result = EchoService::Echo(1);
  printf("C: result %d\n", result);
  result = EchoService::Echo(2);
  printf("C: result %d\n", result);
  EchoService::EchoAsync(3, EchoCallback);
  printf("C: async call with argument 3\n");
  EchoService::EchoAsync(4, EchoCallback);
  printf("C: async call with argument 4\n");
  result = EchoService::Echo(5);
  printf("C: result %d\n", result);
  EchoService::SumAsync(5, 8, SumCallback);
  result = EchoService::Sum(3, 4);
  printf("C: result of sum(3, 4) is %d\n", result);
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
