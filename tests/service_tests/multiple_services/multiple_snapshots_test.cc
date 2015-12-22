// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#define TESTING

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>

#include "include/fletch_api.h"
#include "include/service_api.h"

#include "src/shared/assert.h"  // NOLINT(build/include)
#include "cc/service_one.h"     // NOLINT(build/include)
#include "cc/service_two.h"     // NOLINT(build/include)

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

static void* DartThreadEntry(void* argv) {
  const char** paths = static_cast<const char**>(argv);
  FletchSetup();
  FletchProgram programs[2];
  int exitcodes[2];
  programs[0] = FletchLoadSnapshotFromFile(paths[1]);
  programs[1] = FletchLoadSnapshotFromFile(paths[2]);
  FletchRunMultipleMain(2, programs, exitcodes);
  FletchDeleteProgram(programs[0]);
  FletchDeleteProgram(programs[1]);
  FletchTearDown();
  ChangeStatusAndNotify(kDone);
  return NULL;
}

static void SetupMultipleSnapshotsTest(int argc, char** argv) {
  pthread_mutex_init(&mutex, NULL);
  pthread_cond_init(&cond, NULL);
  ServiceApiSetup();
  pthread_t thread;
  int result = pthread_create(&thread, NULL, DartThreadEntry, argv);
  if (result != 0) {
    perror("Failed to start thread");
    exit(1);
  }
}

static void TearDownMultipleSnapshotsTest() {
  WaitForStatus(kDone);
  ServiceApiTearDown();
}

static void InteractWithServices() {
  ServiceOne::setup();
  ServiceTwo::setup();

  EXPECT_EQ(10, ServiceOne::echo(5));
  EXPECT_EQ(25, ServiceTwo::echo(5));

  ServiceTwo::tearDown();
  ServiceOne::tearDown();
}

int main(int argc, char** argv) {
  if (argc < 3) {
    printf("Usage: %s <snapshot_one> <snapshot_two>\n", argv[0]);
    return 1;
  }
  SetupMultipleSnapshotsTest(argc, argv);
  InteractWithServices();
  TearDownMultipleSnapshotsTest();
}
