// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "include/service_api.h"
#include "include/fletch_api.h"

#include "src/shared/assert.h"
#include "src/vm/platform.h"
#include "src/vm/thread_pool.h"

#include "cc/performance_service.h"

#include <cstdio>
#include <pthread.h>
#include <sys/time.h>

static pthread_mutex_t mutex;
static pthread_cond_t cond;
static int status = 0;

static const int kDone = 1;
static const int kCallCount = 10000;

static fletch::Monitor* echo_monitor = fletch::Platform::CreateMonitor();
static bool echo_async_done = false;

static uint64_t GetMicroseconds() {
  struct timeval tv;
  if (gettimeofday(&tv, NULL) < 0) return -1;
  uint64_t result = tv.tv_sec * 1000000LL;
  result += tv.tv_usec;
  return result;
}

static void EchoCallback(int result) {
  if (result < kCallCount) {
    PerformanceService::echoAsync(result + 1, EchoCallback);
  } else {
    echo_monitor->Lock();
    echo_async_done = true;
    echo_monitor->Notify();
    echo_monitor->Unlock();
  }
}

static void RunEchoTests() {
  uint64_t start = GetMicroseconds();
  for (int i = 0; i < kCallCount; i++) {
    int result = PerformanceService::echo(i);
    ASSERT(result == i);
  }
  uint64_t end = GetMicroseconds();
  int sync_us = static_cast<int>(end - start);
  printf("Sync call took %.2f us.\n",
         static_cast<double>(sync_us) / kCallCount);
  printf("    - %.2f calls/s\n", (1000000.0 / sync_us) * kCallCount);

  start = GetMicroseconds();
  PerformanceService::echoAsync(0, EchoCallback);
  echo_monitor->Lock();
  while (!echo_async_done) echo_monitor->Wait();
  echo_monitor->Unlock();
  end = GetMicroseconds();
  int async_us = static_cast<int>(end - start);
  printf("Async call took %.2f us.\n",
         static_cast<double>(async_us) / kCallCount);
  printf("    - %.2f calls/s\n", (1000000.0 / async_us) * kCallCount);
}

static int CountTreeNodes(TreeNode node) {
  int sum = 1;
  List<TreeNode> children = node.getChildren();
  for (int i = 0; i < children.length(); i++) {
    sum += CountTreeNodes(children[i]);
  }
  return sum;
}

static void BuildTree(int n, TreeNodeBuilder node) {
  if (n > 1) {
    List<TreeNodeBuilder> children = node.initChildren(2);
    BuildTree(n - 1, children[0]);
    BuildTree(n - 1, children[1]);
  }
}

static void RunTreeTests() {
  const int kTreeDepth = 7;
  MessageBuilder builder(8192);

  uint64_t start = GetMicroseconds();
  TreeNodeBuilder built = builder.initRoot<TreeNodeBuilder>();
  BuildTree(kTreeDepth, built);
  uint64_t end = GetMicroseconds();
  printf("Building (C++) took %d us.\n", static_cast<int>(end - start));

  start = GetMicroseconds();
  PerformanceService::countTreeNodes(built);
  end = GetMicroseconds();
  printf("Counting (Dart) took %d us.\n", static_cast<int>(end - start));

  start = GetMicroseconds();
  TreeNode generated = PerformanceService::buildTree(kTreeDepth);
  end = GetMicroseconds();
  printf("Building (Dart) took %d us.\n", static_cast<int>(end - start));

  start = GetMicroseconds();
  CountTreeNodes(generated);
  end = GetMicroseconds();
  printf("Counting (C++) took %d us.\n", static_cast<int>(end - start));

  generated.Delete();
}

void EchoInThread(void* data) {
  word value = reinterpret_cast<word>(data);
  for (int i = 0; i < 64; i++) {
    int result = PerformanceService::echo(value + i);
    ASSERT(result == value + i);
  }
}

static void RunThreadTests() {
  const int kThreadCount = 32;
  fletch::ThreadPool thread_pool(kThreadCount);
  for (int i = 0; i < kThreadCount; i++) {
    while (!thread_pool.TryStartThread(EchoInThread,
                                       reinterpret_cast<void*>(i),
                                       kThreadCount)) {
    }
  }
  thread_pool.JoinAll();
}

static void ChangeStatusAndNotify(int new_status) {
  pthread_mutex_lock(&mutex);
  status = new_status;
  pthread_cond_signal(&cond);
  pthread_mutex_unlock(&mutex);
}

static void WaitForStatus(int expected) {
  pthread_mutex_lock(&mutex);
  while (expected != status) pthread_cond_wait(&cond, &mutex);
  pthread_mutex_unlock(&mutex);
}

static void* DartThreadEntry(void* arg) {
  const char* path = static_cast<char*>(arg);
  FletchSetup();
  FletchRunSnapshotFromFile(path);
  FletchTearDown();
  ChangeStatusAndNotify(kDone);
  return NULL;
}

static void RunSnapshotInNewThread(char* path) {
  pthread_t thread;
  int result = pthread_create(&thread, NULL, DartThreadEntry, path);
  if (result != 0) {
    perror("Failed to start thread");
    exit(1);
  }
}

static void SetupPerformanceTest(int argc, char** argv) {
  pthread_mutex_init(&mutex, NULL);
  pthread_cond_init(&cond, NULL);
  ServiceApiSetup();
  RunSnapshotInNewThread(argv[1]);
  PerformanceService::setup();
}

static void TearDownPerformanceTest() {
  PerformanceService::tearDown();
  WaitForStatus(kDone);
  ServiceApiTearDown();
}

int main(int argc, char** argv) {
  if (argc < 2) {
    printf("Usage: %s <snapshot>\n", argv[0]);
    return 1;
  }
  SetupPerformanceTest(argc, argv);
  RunEchoTests();
  RunTreeTests();
  RunThreadTests();
  TearDownPerformanceTest();
  return 0;
}
