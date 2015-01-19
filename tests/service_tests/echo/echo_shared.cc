// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "include/service_api.h"

#include "src/shared/flags.h"
#include "src/shared/fletch.h"

#include "src/vm/platform.h"
#include "src/vm/program.h"
#include "src/vm/snapshot.h"
#include "src/vm/thread.h"

#include "tests/service_tests/echo/echo_service.h"

// -----------------------------------------------------------------------------
// TODO(ager): We should have a public include/fletch_api.h and the
// functionality to run a snapshot should be accessed through that
// api. The code in this section should be removed in favor of that API.
// -----------------------------------------------------------------------------

static bool IsSnapshot(fletch::List<uint8> snapshot) {
  return snapshot.length() > 2 && snapshot[0] == 0xbe && snapshot[1] == 0xef;
}

static void StartDartSnapshot(char* snapshot) {
  fletch::Fletch::Setup();
  bool success = true;
  fletch::List<uint8> bytes = fletch::Platform::LoadFile(snapshot);
  if (IsSnapshot(bytes)) {
    fletch::SnapshotReader reader(bytes);
    fletch::Program* program = reader.ReadProgram();
    success = program->RunMainInNewProcess();
  } else {
    FATAL1("Not a snapshot: %s\n", snapshot);
  }
  bytes.Delete();
  ASSERT(success);
  fletch::Fletch::TearDown();
}

// -----------------------------------------------------------------------------

static const int kDone = 1;

static fletch::Monitor* monitor = NULL;
static int status = 0;

static void ChangeStatusAndNotify(int new_status) {
  monitor->Lock();
  status = new_status;
  monitor->Notify();
  monitor->Unlock();
}

static void WaitForStatus(int expected) {
  monitor->Lock();
  while (expected != status) monitor->Wait();
  monitor->Unlock();
}

static void* DartThreadEntry(void* data) {
  char* snapshot = reinterpret_cast<char*>(data);
  StartDartSnapshot(snapshot);
  ChangeStatusAndNotify(kDone);
  return NULL;
}

void SetupEchoTest(int argc, char** argv) {
  fletch::Flags::ExtractFromCommandLine(&argc, argv);
  monitor = fletch::Platform::CreateMonitor();
  // TODO(ager): For convenience we use fletch thread abstractions
  // here. We really shouldn't be able to access them through the api,
  // so this should be reworked when we have a library with an api
  // instead.
  ServiceApiSetup();
  fletch::Thread::Run(DartThreadEntry, reinterpret_cast<void*>(argv[1]));
}

void TearDownEchoTest() {
  WaitForStatus(kDone);
  ServiceApiTearDown();
}
