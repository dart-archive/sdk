// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/vm/platform.h"
#include "echo_shared.h"
#include "cc/echo_service.h"

#include <cstdio>
#include <sys/time.h>

const int kCallCount = 10000;

static fletch::Monitor* monitor = fletch::Platform::CreateMonitor();

static bool async_done = false;

static void EchoCallback(int result) {
  if (result < kCallCount) {
    EchoService::echoAsync(result + 1, EchoCallback);
  } else {
    monitor->Lock();
    async_done = true;
    monitor->Notify();
    monitor->Unlock();
  }
}

static void PingCallback(int result) {
  printf("Ping async result: %d\n", result);
}

static uint64_t GetMicroseconds() {
  struct timeval tv;
  if (gettimeofday(&tv, NULL) < 0) return -1;
  uint64_t result = tv.tv_sec * 1000000LL;
  result += tv.tv_usec;
  return result;
}

static void InteractWithService() {
  EchoService::setup();
  uint64_t start = GetMicroseconds();
  for (int i = 0; i < kCallCount; i++) {
    int result = EchoService::echo(i);
    ASSERT(result == i);
  }
  uint64_t end = GetMicroseconds();
  int sync_us = static_cast<int>(end - start);
  printf("Sync call took %.2f us.\n",
         static_cast<double>(sync_us) / kCallCount);
  printf("    - %.2f calls/s\n", (1000000.0 / sync_us) * kCallCount);

  start = GetMicroseconds();
  EchoService::echoAsync(0, EchoCallback);
  monitor->Lock();
  while (!async_done) monitor->Wait();
  monitor->Unlock();
  end = GetMicroseconds();
  int async_us = static_cast<int>(end - start);
  printf("Async call took %.2f us.\n",
         static_cast<double>(async_us) / kCallCount);
  printf("    - %.2f calls/s\n", (1000000.0 / async_us) * kCallCount);

  int result = EchoService::ping();
  printf("Ping result: %d\n", result);
  printf("Async ping call\n");
  EchoService::pingAsync(PingCallback);

  EchoService::tearDown();
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
