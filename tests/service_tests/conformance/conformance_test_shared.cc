// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "conformance_test_shared.h"  // NOLINT(build/include)

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>

#include "include/dartino_api.h"
#include "include/service_api.h"

static const int kDone = 1;

static pthread_mutex_t mutex;
static pthread_cond_t cond;
static int status = 0;

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
  DartinoSetup();
  DartinoRunSnapshotFromFile(path);
  DartinoTearDown();
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

void SetupConformanceTest(int argc, char** argv) {
  pthread_mutex_init(&mutex, NULL);
  pthread_cond_init(&cond, NULL);
  ServiceApiSetup();
  RunSnapshotInNewThread(argv[1]);
}

void TearDownConformanceTest() {
  WaitForStatus(kDone);
  ServiceApiTearDown();
}
