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
#include "src/vm/object.h"
#include "src/vm/object_memory.h"
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

static int RunProgram(Program* program) {
#ifdef FLETCH_ENABLE_LIVE_CODING
  ProgramFolder::FoldProgramByDefault(program);
#endif  // FLETCH_ENABLE_LIVE_CODING

  SimpleProgramRunner runner;

  int exitcodes[1] = { -1 };
  Program* programs[1] = { program };
  runner.Run(1, exitcodes, programs);

  return exitcodes[0];
}

static void StartProgram(Program* program,
                         ProgramExitListener listener,
                         void* data) {
#ifdef FLETCH_ENABLE_LIVE_CODING
  ProgramFolder::FoldProgramByDefault(program);
#endif  // FLETCH_ENABLE_LIVE_CODING

  program->SetProgramExitListener(listener, data);
  Process* process = program->ProcessSpawnForMain();
  Scheduler::GlobalInstance()->ScheduleProgram(program, process);
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
  bool success = session.ProcessRun() == 0;
  if (!success) FATAL("Failed to run via debugger connection");
#else
  FATAL("fletch was built without live coding support.");
#endif
}
}  // namespace fletch

void FletchSetup() { fletch::Fletch::Setup(); }

void FletchTearDown() { fletch::Fletch::TearDown(); }

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

namespace fletch {

class DumpVisitor : public HeapObjectVisitor {
 public:
  virtual int Visit(HeapObject* object) {
    printf("O%08x:\n", object->address());
    DumpReference(object->get_class());
    if (object->IsClass()) {
      DumpClass(Class::cast(object));
    } else if (object->IsFunction()) {
      DumpFunction(Function::cast(object));
    } else if (object->IsInstance()) {
      DumpInstance(Instance::cast(object));
    } else if (object->IsOneByteString()) {
      DumpOneByteString(OneByteString::cast(object));
    } else if (object->IsArray()) {
      DumpArray(Array::cast(object));
    } else if (object->IsLargeInteger()) {
      DumpLargeInteger(LargeInteger::cast(object));
    } else if (object->IsInitializer()) {
      DumpInitializer(Initializer::cast(object));
    } else {
      printf("\t// not handled yet %d!\n", object->format().type());
    }

    return object->Size();
  }

  void DumpReference(Object* object) {
    if (object->IsHeapObject()) {
      printf("\t.long O%08x + 1\n", HeapObject::cast(object)->address());
    } else {
      printf("\t.long 0x%08x\n", object);
    }
  }

 private:
  void DumpClass(Class* clazz) {
    int size = clazz->AllocationSize();
    for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
      DumpReference(clazz->at(offset));
    }
  }

  void DumpFunction(Function* function) {
    int size = Function::kSize;
    for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
      DumpReference(function->at(offset));
    }

    for (int o = 0; o < function->bytecode_size(); o += kPointerSize) {
      printf("\t.long 0x%08x\n", *reinterpret_cast<uword*>(function->bytecode_address_for(o)));
    }
  }

  void DumpInstance(Instance* instance) {
    int size = instance->Size();
    for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
      DumpReference(instance->at(offset));
    }
  }

  void DumpOneByteString(OneByteString* string) {
    int size = OneByteString::kSize;
    for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
      DumpReference(string->at(offset));
    }

    for (int o = size; o < string->StringSize(); o += kPointerSize) {
      printf("\t.long 0x%08x\n", *reinterpret_cast<uword*>(string->byte_address_for(o - size)));
    }
  }

  void DumpArray(Array* array) {
    int size = array->Size();
    for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
      DumpReference(array->at(offset));
    }
  }

  void DumpLargeInteger(LargeInteger* large) {
    uword* ptr = reinterpret_cast<uword*>(large->address() + LargeInteger::kValueOffset);
    printf("\t.long 0x%08x\n", ptr[0]);
    printf("\t.long 0x%08x\n", ptr[1]);
  }

  void DumpInitializer(Initializer* initializer) {
    int size = initializer->Size();
    for (int offset = HeapObject::kSize; offset < size; offset += kPointerSize) {
      DumpReference(initializer->at(offset));
    }
  }
};

}

void FletchDumpProgram(FletchProgram raw_program, const char* path) {
  fletch::Program* program = reinterpret_cast<fletch::Program*>(raw_program);
  fletch::DumpVisitor visitor;

  printf("\t// Program space = %d bytes\n", program->heap()->space()->Used());
  printf("\t.text\n\n");

  printf("\t.global program_start\n");
  printf("\t.p2align 12\n");
  printf("program_start:\n");

  program->heap()->space()->IterateObjects(&visitor);

  printf("\t.global program_end\n");
  printf("\t.p2align 12\n");
  printf("program_end:\n\n\n");

  fletch::ProgramInfoBlock* block = new fletch::ProgramInfoBlock();
  block->PopulateFromProgram(program);
  printf("\t.global program_info_block\n");
  printf("program_info_block:\n");

  for (fletch::Object** r = block->roots(); r < block->end_of_roots(); r++) {
    visitor.DumpReference(*r);
  }
  printf("\t.long 0x%08x\n", block->main_arity());

  delete block;
}

int FletchRunMain(FletchProgram raw_program) {
  fletch::Program* program = reinterpret_cast<fletch::Program*>(raw_program);
  return fletch::RunProgram(program);
}

void FletchRunMultipleMain(int count,
                           FletchProgram* fletch_programs,
                           int* exitcodes) {
  fletch::SimpleProgramRunner runner;

  auto programs = reinterpret_cast<fletch::Program**>(fletch_programs);
  for (int i = 0; i < count; i++) {
    exitcodes[i] = -1;
#ifdef FLETCH_ENABLE_LIVE_CODING
    fletch::ProgramFolder::FoldProgramByDefault(programs[i]);
#endif  // FLETCH_ENABLE_LIVE_CODING
  }

  runner.Run(count, exitcodes, programs);
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

  program->heap()->space()->Append(memory);
  program->heap()->space()->SetReadOnly();
  return reinterpret_cast<FletchProgram>(program);
}

FLETCH_EXPORT void FletchStartMain(FletchProgram raw_program,
                                   ProgramExitCallback callback,
                                   void* callback_data) {
  fletch::Program* program = reinterpret_cast<fletch::Program*>(raw_program);
  fletch::ProgramExitListener listener =
      reinterpret_cast<fletch::ProgramExitListener>(callback);
  fletch::StartProgram(program, listener, callback_data);
}

void FletchDeleteProgram(FletchProgram raw_program) {
  fletch::Program* program = reinterpret_cast<fletch::Program*>(raw_program);
  delete program;
}

void FletchRunSnapshotFromFile(const char* path) {
  fletch::RunSnapshotFromFile(path);
}

bool FletchAddDefaultSharedLibrary(const char* library) {
  return fletch::ForeignFunctionInterface::AddDefaultSharedLibrary(library);
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
