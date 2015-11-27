// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>

#include "src/vm/fletch_api_impl.h"

#include "src/shared/assert.h"
#ifdef FLETCH_ENABLE_LIVE_CODING
#include "src/shared/connection.h"
#endif
#include "src/shared/fletch.h"
#include "src/shared/list.h"

#include "src/vm/ffi.h"
#include "src/vm/program.h"
#include "src/vm/program_folder.h"
#include "src/vm/program_info_block.h"
#include "src/vm/scheduler.h"
#include "src/vm/session.h"
#include "src/vm/snapshot.h"

namespace fletch {

class PrintInterceptorImpl : public PrintInterceptor {
 public:
  typedef void (*PrintFunction)(const char* message, int out, void* data);

  PrintInterceptorImpl(PrintFunction fn, void* data)
      : fn_(fn), data_(data) {}

  virtual void Out(char* message) { fn_(message, 2, data_); }
  virtual void Error(char* message) { fn_(message, 3, data_); }

 private:
  PrintFunction fn_;
  void* data_;
};

static bool IsSnapshot(List<uint8> snapshot) {
  return snapshot.length() > 2 && snapshot[0] == 0xbe && snapshot[1] == 0xef;
}

static Program* LoadSnapshot(List<uint8> bytes) {
  if (IsSnapshot(bytes)) {
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
  return scheduler->Run();
}

static int RunProgram(Program* program) {
  Scheduler scheduler;
  EnqueueProgramInScheduler(program, &scheduler);
  return RunScheduler(&scheduler);
}

static Program* LoadSnapshotFromFile(const char* path) {
  List<uint8> bytes = Platform::LoadFile(path);
  Program* program = LoadSnapshot(bytes);
  bytes.Delete();
  return program;
}

static void RunSnapshotFromFile(const char* path) {
  Program* program = LoadSnapshotFromFile(path);
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

FletchProgram FletchLoadSnapshotFromFile(const char* path) {
  fletch::Program* program = fletch::LoadSnapshotFromFile(path);
  if (program == NULL) FATAL("Failed to load snapshot from file.\n");
  return reinterpret_cast<FletchProgram>(program);
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

FletchProgram FletchLoadProgramFromFlash(void* heap, size_t size) {
  fletch::Program* program =
      new fletch::Program(fletch::Program::kLoadedFromSnapshot);
  uword address = reinterpret_cast<uword>(heap);
  // The info block is appended at the end of the image.
  size_t heap_size = size - sizeof(fletch::ProgramInfoBlock);
  uword block_address = address + heap_size;
  fletch::ProgramInfoBlock* program_info =
      reinterpret_cast<fletch::ProgramInfoBlock*>(block_address);
  program_info->WriteToProgram(program);
  fletch::Chunk* memory = fletch::ObjectMemory::CreateFlashChunk(
      program->heap()->space(), heap, heap_size);
  program->heap()->space()->AppendProgramChunk(memory, memory->base());
  program->set_is_compact(true);
  return reinterpret_cast<FletchProgram>(program);
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

FletchPrintInterceptor FletchRegisterPrintInterceptor(
    PrintInterceptionFunction function, void* data) {
  fletch::PrintInterceptorImpl* impl =
      new fletch::PrintInterceptorImpl(function, data);
  fletch::Print::RegisterPrintInterceptor(impl);
  return reinterpret_cast<void*>(impl);
}

void FletchUnregisterPrintInterceptor(FletchPrintInterceptor raw_interceptor) {
  fletch::PrintInterceptorImpl* impl =
      reinterpret_cast<fletch::PrintInterceptorImpl*>(raw_interceptor);
  fletch::Print::UnregisterPrintInterceptor(impl);
  delete impl;
}
