// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/fletch_api_impl.h"

#include "src/shared/assert.h"
#ifdef FLETCH_ENABLE_LIVE_CODING
#include "src/shared/connection.h"
#endif
#include "src/shared/fletch.h"
#include "src/shared/list.h"

#include "src/vm/android_print_interceptor.h"
#include "src/vm/ffi.h"
#include "src/vm/program.h"
#include "src/vm/program_folder.h"
#include "src/vm/scheduler.h"
#include "src/vm/session.h"
#include "src/vm/snapshot.h"

namespace fletch {

static bool IsSnapshot(List<uint8> snapshot) {
  return snapshot.length() > 2 && snapshot[0] == 0xbe && snapshot[1] == 0xef;
}

static Program* LoadSnapshot(List<uint8> bytes) {
  if (IsSnapshot(bytes)) {
#if defined(__ANDROID__)
    // TODO(zerny): Consider making print interceptors part of the public API.
    Print::RegisterPrintInterceptor(new AndroidPrintInterceptor());
#endif
    SnapshotReader reader(bytes);
    return reader.ReadProgram();
  }
  return NULL;
}

static void EnqueueProgramInScheduler(Program* program, Scheduler* scheduler) {
#ifdef FLETCH_ENABLE_LIVE_CODING
  ProgramFolder::FoldProgramByDefault(program);
#endif  // FLETCH_ENABLE_LIVE_CODING
  Process* process = program->ProcessSpawnForMain();
  scheduler->ScheduleProgram(program, process);
}

static int RunScheduler(Scheduler* scheduler) {
#if defined(__ANDROID__)
  // TODO(zerny): Consider making print interceptors part of the public API.
  Print::RegisterPrintInterceptor(new AndroidPrintInterceptor());
#endif
  int result = scheduler->Run();
#if defined(__ANDROID__)
  Print::UnregisterPrintInterceptors();
#endif
  return result;
}

static int RunProgram(Program* program) {
  Scheduler scheduler;
  EnqueueProgramInScheduler(program, &scheduler);
  return RunScheduler(&scheduler);
}

static void RunSnapshotFromFile(const char* path) {
  List<uint8> bytes = Platform::LoadFile(path);
  Program* program = LoadSnapshot(bytes);
  bytes.Delete();
  int result = RunProgram(program);
  delete program;
  if (result != 0) FATAL1("Failed to run snapshot: %s\n", path);
}

static void WaitForDebuggerConnection(int port) {
#ifdef FLETCH_ENABLE_LIVE_CODING
  ConnectionListener listener("127.0.0.1", port);
  Connection* connection = listener.Accept();
  Session session(connection);
  session.Initialize();
  session.StartMessageProcessingThread();
  bool success = session.ProcessRun();
  if (!success) FATAL("Failed to run via debugger connection");
#else
  FATAL("fletch was built without live coding support.");
#endif
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

FletchProgram FletchLoadSnapshot(unsigned char* snapshot, int length) {
  fletch::List<uint8> bytes(snapshot, length);
  fletch::Program* program = fletch::LoadSnapshot(bytes);
  if (program == NULL) FATAL("Failed to load snapshot.\n");
  return reinterpret_cast<FletchProgram>(program);
}

int FletchRunMain(FletchProgram raw_program) {
  fletch::Program* program = reinterpret_cast<fletch::Program*>(raw_program);
  return fletch::RunProgram(program);
}

int FletchRunMultipleMain(int count, FletchProgram* programs) {
  fletch::Scheduler scheduler;
  for (int i = 0; i < count; i++) {
    fletch::EnqueueProgramInScheduler(
        reinterpret_cast<fletch::Program*>(programs[i]), &scheduler);
  }
  return fletch::RunScheduler(&scheduler);
}

void FletchDeleteProgram(FletchProgram raw_program) {
  fletch::Program* program = reinterpret_cast<fletch::Program*>(raw_program);
  delete program;
}

void FletchRunSnapshotFromFile(const char* path) {
  fletch::RunSnapshotFromFile(path);
}

void FletchAddDefaultSharedLibrary(const char* library) {
  fletch::ForeignFunctionInterface::AddDefaultSharedLibrary(library);
}
