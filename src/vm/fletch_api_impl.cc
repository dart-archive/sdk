// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/fletch_api_impl.h"

#include "src/shared/assert.h"
#include "src/shared/connection.h"
#include "src/shared/fletch.h"
#include "src/shared/list.h"

#include "src/vm/ffi.h"
#include "src/vm/program.h"
#include "src/vm/scheduler.h"
#include "src/vm/session.h"
#include "src/vm/snapshot.h"

namespace fletch {

static bool IsSnapshot(List<uint8> snapshot) {
  return snapshot.length() > 2 && snapshot[0] == 0xbe && snapshot[1] == 0xef;
}

static bool RunSnapshot(List<uint8> bytes) {
  if (IsSnapshot(bytes)) {
    SnapshotReader reader(bytes);
    Program* program = reader.ReadProgram();
    Scheduler scheduler;
    Process* process = program->ProcessSpawnForMain();
    scheduler.ScheduleProgram(program, process);
    bool success = scheduler.Run();
    scheduler.UnscheduleProgram(program);
    delete program;
    return success;
  }
  return false;
}

static void RunShapshotFromFile(const char* path) {
  List<uint8> bytes = Platform::LoadFile(path);
  bool success = RunSnapshot(bytes);
  if (!success) FATAL1("Failed to run snapshot: %s\n", path);
  bytes.Delete();
}

static void WaitForDebuggerConnection(int port) {
  ConnectionListener listener("127.0.0.1", port);
  Connection* connection = listener.Accept();
  Session session(connection);
  session.Initialize();
  session.StartMessageProcessingThread();
  bool success = session.ProcessRun();
  if (!success) FATAL("Failed to run via debugger connection");
}

}  // namespace fletch

void FletchSetup() {
  fletch::Fletch::Setup();
}

void FletchTearDown() {
  fletch::Fletch::TearDown();
}

void FletchWaitForDebuggerConnection(int port) {
  fletch::WaitForDebuggerConnection(port);
}

void FletchRunSnapshot(unsigned char* snapshot, int length) {
  fletch::List<uint8> bytes(snapshot, length);
  bool success = fletch::RunSnapshot(bytes);
  if (!success) FATAL("Failed to run snapshot.\n");
}

void FletchRunSnapshotFromFile(const char* path) {
  fletch::RunShapshotFromFile(path);
}

void FletchAddDefaultSharedLibrary(const char* library) {
  fletch::ForeignFunctionInterface::AddDefaultSharedLibrary(library);
}
