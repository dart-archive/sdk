// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>

#include "src/vm/dartino_api_impl.h"

#include "src/shared/assert.h"
#ifdef DARTINO_ENABLE_DEBUGGING
#include "src/shared/connection.h"
#endif
#include "src/shared/dartino.h"
#include "src/shared/list.h"

#include "src/vm/ffi.h"
#include "src/vm/program.h"
#include "src/vm/program_folder.h"
#include "src/vm/program_info_block.h"
#include "src/vm/scheduler.h"
#include "src/vm/session.h"
#include "src/vm/snapshot.h"

namespace dartino {

class PrintInterceptorImpl : public PrintInterceptor {
 public:
  typedef void (*PrintFunction)(const char* message, int out, void* data);

  PrintInterceptorImpl(PrintFunction fn, void* data) : fn_(fn), data_(data) {}

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

static int RunProgram(Program* program, int argc, char** argv) {
#ifdef DARTINO_ENABLE_LIVE_CODING
  ProgramFolder::FoldProgramByDefault(program);
#endif  // DARTINO_ENABLE_LIVE_CODING

  SimpleProgramRunner runner;

  int exitcodes[1] = { -1 };
  Program* programs[1] = { program };
  runner.Run(1, exitcodes, programs, argc, argv);

  return exitcodes[0];
}

static void StartProgram(Program* program,
                         ProgramExitListener listener,
                         void* data,
                         int argc,
                         char** argv) {
#ifdef DARTINO_ENABLE_LIVE_CODING
  ProgramFolder::FoldProgramByDefault(program);
#endif  // DARTINO_ENABLE_LIVE_CODING

  program->SetProgramExitListener(listener, data);
  List<List<uint8>> arguments = List<List<uint8>>::New(argc);
  for (int i = 0; i < argc; i++) {
    uint8* utf8 = reinterpret_cast<uint8*>(strdup(argv[i]));
    arguments[i] = List<uint8>(utf8, strlen(argv[i]));
  }
  Process* process = program->ProcessSpawnForMain(arguments);
  Scheduler::GlobalInstance()->ScheduleProgram(program, process);
}

static Program* LoadSnapshotFromFile(const char* path) {
  List<uint8> bytes = Platform::LoadFile(path);
  Program* program = LoadSnapshot(bytes);
  bytes.Delete();
  return program;
}

static int RunWithDebuggerConnection(
    Program* program,
    ConnectionListenerCallback connection_listener_callback,
    void* listener_data,
    bool wait_for_connection) {
  Session session(
      program,
      connection_listener_callback,
      listener_data,
      wait_for_connection);
  session.StartMessageProcessingThread();
  int result = session.ProcessRun();
  session.JoinMessageProcessingThread();
  return result;
}
}  // namespace dartino

void DartinoSetup() { dartino::Dartino::Setup(); }

void DartinoTearDown() { dartino::Dartino::TearDown(); }

int DartinoRunWithDebuggerConnection(
    DartinoProgram program,
    DartinoConnectionListenerCallback connection_listener_callback,
    void* listener_data,
    bool wait_for_connection) {
  return dartino::RunWithDebuggerConnection(
      reinterpret_cast<dartino::Program*>(program),
      reinterpret_cast<dartino::ConnectionListenerCallback>(
          connection_listener_callback),
      listener_data,
      wait_for_connection);
}

DartinoProgram DartinoLoadSnapshotFromFile(const char* path) {
  dartino::Program* program = dartino::LoadSnapshotFromFile(path);
  return reinterpret_cast<DartinoProgram>(program);
}

DartinoProgram DartinoLoadSnapshot(unsigned char* snapshot, int length) {
  dartino::List<uint8> bytes(snapshot, length);
  dartino::Program* program = dartino::LoadSnapshot(bytes);
  return reinterpret_cast<DartinoProgram>(program);
}

int DartinoRunMain(DartinoProgram raw_program, int argc, char** argv) {
  dartino::Program* program = reinterpret_cast<dartino::Program*>(raw_program);
  return dartino::RunProgram(program, argc, argv);
}

void DartinoRunMultipleMain(int count,
                            DartinoProgram* dartino_programs,
                            int* exitcodes,
                            int argc,
                            char** argv) {
  dartino::SimpleProgramRunner runner;

  auto programs = reinterpret_cast<dartino::Program**>(dartino_programs);
  for (int i = 0; i < count; i++) {
    exitcodes[i] = -1;
#ifdef DARTINO_ENABLE_LIVE_CODING
    dartino::ProgramFolder::FoldProgramByDefault(programs[i]);
#endif  // DARTINO_ENABLE_LIVE_CODING
  }

  runner.Run(count, exitcodes, programs, argc, argv);
}

DartinoProgram DartinoLoadProgramFromFlash(void* heap, size_t size) {
  dartino::Program* program =
      new dartino::Program(dartino::Program::kLoadedFromSnapshot);
  uword address = reinterpret_cast<uword>(heap);
  // The info block is appended at the end of the image.
  size_t heap_size = size - sizeof(dartino::ProgramInfoBlock);
  uword block_address = address + heap_size;
  dartino::ProgramInfoBlock* program_info =
      reinterpret_cast<dartino::ProgramInfoBlock*>(block_address);
  if (!dartino::ProgramInfoBlock::MightBeProgramInfoBlock(program_info)) {
    return NULL;
  }
  program_info->WriteToProgram(program);
  dartino::Chunk* memory = dartino::ObjectMemory::CreateFlashChunk(
      program->heap()->space(), heap, heap_size);

  program->heap()->space()->Append(memory);
  program->heap()->space()->SetReadOnly();
  return reinterpret_cast<DartinoProgram>(program);
}

DARTINO_EXPORT void DartinoStartMain(DartinoProgram raw_program,
                                   ProgramExitCallback callback,
                                   void* callback_data,
                                   int argc,
                                   char** argv) {
  dartino::Program* program = reinterpret_cast<dartino::Program*>(raw_program);
  dartino::ProgramExitListener listener =
      reinterpret_cast<dartino::ProgramExitListener>(callback);
  dartino::StartProgram(program, listener, callback_data, argc, argv);
}

void DartinoDeleteProgram(DartinoProgram raw_program) {
  dartino::Program* program = reinterpret_cast<dartino::Program*>(raw_program);
  dartino::ProgramState* state = program->program_state();
  if (state->state() == dartino::ProgramState::kDone) {
    // Either the program is
    //   * done running
    //   * the embedder got the exitcode
    //   * the embedder wants to unschedule & delete it
    dartino::Scheduler::GlobalInstance()->UnscheduleProgram(program);
    ASSERT(state->state() == dartino::ProgramState::kPendingDeletion);
  } else {
    // Or
    //   * the program has never been scheduled
    //   * the embedder wants to delete it (already unscheduled)
    ASSERT(state->state() == dartino::ProgramState::kInitialized ||
           state->state() == dartino::ProgramState::kPendingDeletion);
  }
  delete program;
}

bool DartinoAddDefaultSharedLibrary(const char* library) {
  return dartino::ForeignFunctionInterface::AddDefaultSharedLibrary(library);
}

DartinoPrintInterceptor DartinoRegisterPrintInterceptor(
    PrintInterceptionFunction function, void* data) {
  dartino::PrintInterceptorImpl* impl =
      new dartino::PrintInterceptorImpl(function, data);
  dartino::Print::RegisterPrintInterceptor(impl);
  return reinterpret_cast<void*>(impl);
}

void DartinoUnregisterPrintInterceptor(
    DartinoPrintInterceptor raw_interceptor) {
  dartino::PrintInterceptorImpl* impl =
      reinterpret_cast<dartino::PrintInterceptorImpl*>(raw_interceptor);
  dartino::Print::UnregisterPrintInterceptor(impl);
  delete impl;
}

DartinoProgramGroup DartinoCreateProgramGroup(const char *name) {
  auto dgroup = dartino::Scheduler::GlobalInstance()->CreateProgramGroup(name);
  return reinterpret_cast<DartinoProgramGroup>(dgroup);
}

void DartinoDeleteProgramGroup(DartinoProgramGroup group) {
  dartino::Scheduler::GlobalInstance()->DeleteProgramGroup(
      reinterpret_cast<dartino::ProgramGroup>(group));
}

void DartinoAddProgramToGroup(DartinoProgramGroup group,
                              DartinoProgram program) {
  auto dgroup = reinterpret_cast<dartino::ProgramGroup>(group);
  auto dprogram = reinterpret_cast<dartino::Program*>(program);
  dartino::Scheduler::GlobalInstance()->AddProgramToGroup(
      dgroup, dprogram);
}

void DartinoRemoveProgramFromGroup(DartinoProgramGroup group,
                                   DartinoProgram program) {
  auto dgroup = reinterpret_cast<dartino::ProgramGroup>(group);
  auto dprogram = reinterpret_cast<dartino::Program*>(program);
  dartino::Scheduler::GlobalInstance()->RemoveProgramFromGroup(
      dgroup, dprogram);
}

void DartinoFreezeProgramGroup(DartinoProgramGroup group) {
  auto dgroup = reinterpret_cast<dartino::ProgramGroup>(group);
  dartino::Scheduler::GlobalInstance()->FreezeProgramGroup(dgroup);
}

void DartinoUnfreezeProgramGroup(DartinoProgramGroup group) {
  auto dgroup = reinterpret_cast<dartino::ProgramGroup>(group);
  dartino::Scheduler::GlobalInstance()->UnFreezeProgramGroup(dgroup);
}
