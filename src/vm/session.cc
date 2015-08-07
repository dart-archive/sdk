// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/session.h"

#include "src/shared/bytecodes.h"
#include "src/shared/connection.h"
#include "src/shared/flags.h"
#include "src/shared/platform.h"

#include "src/vm/object_map.h"
#include "src/vm/process.h"
#include "src/vm/scheduler.h"
#include "src/vm/snapshot.h"
#include "src/vm/stack_walker.h"
#include "src/vm/thread.h"

#define GC_AND_RETRY_ON_ALLOCATION_FAILURE(var, exp)                    \
  Object* var = (exp);                                                  \
  if (var == Failure::retry_after_gc()) {                               \
    program()->CollectGarbage();                                        \
    var = (exp);                                                        \
    ASSERT(!var->IsFailure());                                          \
  }                                                                     \

namespace fletch {

class ConnectionPrintInterceptor : public PrintInterceptor {
 public:
  explicit ConnectionPrintInterceptor(Connection* connection)
      : connection_(connection) {}
  virtual ~ConnectionPrintInterceptor() {}

  virtual void Out(char* message) {
    WriteBuffer buffer;
    buffer.WriteString(message);
    connection_->Send(Connection::kStdoutData, buffer);
  }

  virtual void Error(char* message) {
    WriteBuffer buffer;
    buffer.WriteString(message);
    connection_->Send(Connection::kStderrData, buffer);
  }

 private:
  Connection* connection_;
};

Session::Session(Connection* connection)
    : connection_(connection),
      program_(NULL),
      process_(NULL),
      execution_paused_(false),
      debugging_(false),
      method_map_id_(-1),
      class_map_id_(-1),
      fibers_map_id_(-1),
      stack_(0),
      changes_(0),
      main_thread_monitor_(Platform::CreateMonitor()),
      main_thread_resume_kind_(kUnknown) {
  ConnectionPrintInterceptor* interceptor =
      new ConnectionPrintInterceptor(connection_);
  Print::RegisterPrintInterceptor(interceptor);
}

Session::~Session() {
  Print::UnregisterPrintInterceptors();

  delete connection_;
  delete program_;
  delete main_thread_monitor_;
  for (int i = 0; i < maps_.length(); ++i) delete maps_[i];
  maps_.Delete();
}

void Session::Initialize() {
  program_ = new Program();
  program()->Initialize();
  program()->AddSession(this);
}

static void* MessageProcessingThread(void* data) {
  Session* session = reinterpret_cast<Session*>(data);
  session->ProcessMessages();
  return NULL;
}

void Session::StartMessageProcessingThread() {
  message_handling_thread_ = Thread::Run(MessageProcessingThread, this);
}

void Session::JoinMessageProcessingThread() {
  message_handling_thread_.Join();
}

int64_t Session::PopInteger() {
  Object* top = Pop();
  if (top->IsLargeInteger()) {
    return LargeInteger::cast(top)->value();
  }
  return Smi::cast(top)->value();
}

void Session::SignalMainThread(MainThreadResumeKind kind) {
  main_thread_monitor_->Lock();
  while (main_thread_resume_kind_ != kUnknown) main_thread_monitor_->Wait();
  main_thread_resume_kind_ = kind;
  main_thread_monitor_->Notify();
  main_thread_monitor_->Unlock();
}

void Session::SendDartValue(Object* value) {
  WriteBuffer buffer;
  if (value->IsSmi() || value->IsLargeInteger()) {
    int64_t int_value = value->IsSmi()
        ? Smi::cast(value)->value()
        : LargeInteger::cast(value)->value();
    buffer.WriteInt64(int_value);
    connection_->Send(Connection::kInteger, buffer);
  } else if (value->IsTrue() || value->IsFalse()) {
    buffer.WriteBoolean(value->IsTrue());
    connection_->Send(Connection::kBoolean, buffer);
  } else if (value->IsNull()) {
    connection_->Send(Connection::kNull, buffer);
  } else if (value->IsDouble()) {
    buffer.WriteDouble(Double::cast(value)->value());
    connection_->Send(Connection::kDouble, buffer);
  } else if (value->IsString()) {
    // TODO(ager): We should send the character data as 16-bit values
    // instead of 32-bit values.
    String* str = String::cast(value);
    for (int i = 0; i < str->length(); i++) {
      buffer.WriteInt(str->get_code_unit(i));
    }
    connection_->Send(Connection::kString, buffer);
  } else {
    Push(HeapObject::cast(value)->get_class());
    buffer.WriteInt64(MapLookupByObject(class_map_id_, Top()));
    connection_->Send(Connection::kInstance, buffer);
  }
}

void Session::SendInstanceStructure(Instance* instance) {
  WriteBuffer buffer;
  Class* klass = instance->get_class();
  Push(klass);
  buffer.WriteInt64(MapLookupByObject(class_map_id_, Top()));
  int fields = klass->NumberOfInstanceFields();
  buffer.WriteInt(fields);
  connection_->Send(Connection::kInstanceStructure, buffer);
  for (int i = 0; i < fields; i++) {
    SendDartValue(instance->GetInstanceField(i));
  }
}

void Session::ProcessContinue(Process* process) {
  execution_paused_ = false;
  process->program()->scheduler()->ProcessContinue(process);
}

void Session::SendStackTrace(Stack* stack) {
  int frames = StackWalker::ComputeStackTrace(process_, stack, this);
  WriteBuffer buffer;
  buffer.WriteInt(frames);
  for (int i = 0; i < frames; i++) {
    // Lookup method in method map and send id.
    buffer.WriteInt64(MapLookupByObject(method_map_id_, Pop()));
    // Pop bytecode index from session stack and send it.
    buffer.WriteInt64(PopInteger());
  }
  connection_->Send(Connection::kProcessBacktrace, buffer);
}

void Session::ProcessMessages() {
  while (true) {
    Connection::Opcode opcode = connection_->Receive();

    switch (opcode) {
      case Connection::kConnectionError: {
        Print::UnregisterPrintInterceptors();
        FATAL("Compiler crashed. So do we.");
      }

      case Connection::kCompilerError: {
        debugging_ = false;
        SignalMainThread(kError);
        return;
      }

      case Connection::kDisableStandardOutput: {
        Print::DisableStandardOutput();
        break;
      }

      case Connection::kProcessSpawnForMain: {
        // Setup entry point for main thread.
        program()->set_entry(Function::cast(Pop()));
        program()->set_main_arity(Smi::cast(Pop())->value());
        ProgramFolder::FoldProgramByDefault(program());
        process_ = program()->ProcessSpawnForMain();
        break;
      }

      case Connection::kProcessRun: {
        SignalMainThread(kProcessRun);
        // If we are debugging we continue processing messages. If we are
        // connected to the compiler directly we terminate the message
        // processing thread.
        if (!is_debugging()) return;
        break;
      }

      case Connection::kProcessSetBreakpoint: {
        WriteBuffer buffer;
        if (process_->debug_info() == NULL) {
          process_->AttachDebugger();
        }
        int bytecode_index = connection_->ReadInt();
        Function* function = Function::cast(Pop());
        DebugInfo* debug_info = process_->debug_info();
        int id = debug_info->SetBreakpoint(function, bytecode_index);
        buffer.WriteInt(id);
        connection_->Send(Connection::kProcessSetBreakpoint, buffer);
        break;
      }

      case Connection::kProcessDeleteBreakpoint: {
        WriteBuffer buffer;
        ASSERT(process_->debug_info() != NULL);
        int id = connection_->ReadInt();
        bool deleted = process_->debug_info()->DeleteBreakpoint(id);
        ASSERT(deleted);
        buffer.WriteInt(id);
        connection_->Send(Connection::kProcessDeleteBreakpoint, buffer);
        break;
      }

      case Connection::kProcessStep: {
        process_->debug_info()->set_is_stepping(true);
        ProcessContinue(process_);
        break;
      }

      case Connection::kProcessStepOver: {
        int breakpoint_id = process_->PrepareStepOver();
        WriteBuffer buffer;
        buffer.WriteInt(breakpoint_id);
        connection_->Send(Connection::kProcessSetBreakpoint, buffer);
        ProcessContinue(process_);
        break;
      }

      case Connection::kProcessStepOut: {
        int breakpoint_id = process_->PrepareStepOut();
        WriteBuffer buffer;
        buffer.WriteInt(breakpoint_id);
        connection_->Send(Connection::kProcessSetBreakpoint, buffer);
        ProcessContinue(process_);
        break;
      }

      case Connection::kProcessStepTo: {
        int64 id = connection_->ReadInt64();
        int bcp = connection_->ReadInt();
        Function* function =
            Function::cast(maps_[method_map_id_]->LookupById(id));
        DebugInfo* debug_info = process_->debug_info();
        debug_info->SetBreakpoint(function, bcp, true);
        ProcessContinue(process_);
        break;
      }

      case Connection::kProcessContinue: {
        ProcessContinue(process_);
        break;
      }

      case Connection::kProcessBacktraceRequest: {
        Stack* stack = process_->stack();
        SendStackTrace(stack);
        break;
      }

      case Connection::kProcessFiberBacktraceRequest: {
        int64 fiber_id = connection_->ReadInt64();
        Stack* stack = Stack::cast(MapLookupById(fibers_map_id_, fiber_id));
        SendStackTrace(stack);
        break;
      }

      case Connection::kProcessLocal:
      case Connection::kProcessLocalStructure: {
        int frame = connection_->ReadInt();
        int slot = connection_->ReadInt();
        Object* local = StackWalker::ComputeLocal(process_, frame, slot);
        if (opcode == Connection::kProcessLocalStructure &&
            local->IsInstance()) {
          SendInstanceStructure(Instance::cast(local));
        } else {
          SendDartValue(local);
        }
        break;
      }

      case Connection::kProcessRestartFrame: {
        int frame = connection_->ReadInt();
        StackWalker::RestartFrame(process_, frame);
        ProcessContinue(process_);
        break;
      }

      case Connection::kSessionEnd: {
        debugging_ = false;
        // If execution is paused we delete the process to allow the
        // VM to terminate.
        if (execution_paused_) {
          Scheduler* scheduler = program()->scheduler();
          switch (process_->state()) {
            case Process::kBreakPoint:
              scheduler->ExitAtBreakpoint(process_);
              break;
            case Process::kCompileTimeError:
              scheduler->ExitAtCompileTimeError(process_);
              break;
            case Process::kUncaughtException:
              scheduler->ExitAtUncaughtException(process_);
              break;
            default:
              UNREACHABLE();
              break;
          }
        }
        SignalMainThread(kSessionEnd);
        return;
      }

      case Connection::kDebugging: {
        method_map_id_ = connection_->ReadInt();
        class_map_id_ = connection_->ReadInt();
        fibers_map_id_ = connection_->ReadInt();
        debugging_ = true;
        break;
      }

      case Connection::kProcessAddFibersToMap: {
        // TODO(ager): Potentially optimize this to not require a full
        // process GC to locate the live stacks?
        int number_of_stacks = process_->CollectGarbageAndChainStacks();
        Object* current = process_->stack();
        for (int i = 0; i < number_of_stacks; i++) {
          Stack* stack = Stack::cast(current);
          AddToMap(fibers_map_id_, i, stack);
          current = stack->next();
          // Unchain stacks.
          stack->set_next(Smi::FromWord(0));
        }
        ASSERT(current == NULL);
        WriteBuffer buffer;
        buffer.WriteInt(number_of_stacks);
        connection_->Send(Connection::kProcessNumberOfStacks, buffer);
        break;
      }

      case Connection::kWriteSnapshot: {
        int length;
        uint8* data = connection_->ReadBytes(&length);
        const char* path = reinterpret_cast<const char*>(data);
        ASSERT(static_cast<int>(strlen(path)) == length - 1);
        bool success = WriteSnapshot(path);
        free(data);
        SignalMainThread(success ? kSnapshotDone : kError);
        return;
      }

      case Connection::kCollectGarbage: {
        program()->CollectGarbage();
        break;
      }

      case Connection::kNewMap: {
        NewMap(connection_->ReadInt());
        break;
      }

      case Connection::kDeleteMap: {
        DeleteMap(connection_->ReadInt());
        break;
      }

      case Connection::kPushFromMap: {
        int index = connection_->ReadInt();
        int64 id = connection_->ReadInt64();
        PushFromMap(index, id);
        break;
      }

      case Connection::kPopToMap: {
        int index = connection_->ReadInt();
        int64 id = connection_->ReadInt64();
        PopToMap(index, id);
        break;
      }

      case Connection::kRemoveFromMap: {
        int index = connection_->ReadInt();
        int64 id = connection_->ReadInt64();
        RemoveFromMap(index, id);
        break;
      }

      case Connection::kDup: {
        Dup();
        break;
      }

      case Connection::kDrop: {
        Drop(connection_->ReadInt());
        break;
      }

      case Connection::kPushNull: {
        PushNull();
        break;
      }

      case Connection::kPushBoolean: {
        PushBoolean(connection_->ReadBoolean());
        break;
      }

      case Connection::kPushNewInteger: {
        PushNewInteger(connection_->ReadInt64());
        break;
      }

      case Connection::kPushNewDouble: {
        PushNewDouble(connection_->ReadDouble());
        break;
      }

      case Connection::kPushNewString: {
        int length;
        uint8* bytes = connection_->ReadBytes(&length);
        ASSERT((length & 1) == 0);
        List<uint16> contents(reinterpret_cast<uint16*>(bytes), length >> 1);
        PushNewString(contents);
        contents.Delete();
        break;
      }

      case Connection::kPushNewInstance: {
        PushNewInstance();
        break;
      }

      case Connection::kPushNewArray: {
        PushNewArray(connection_->ReadInt());
        break;
      }

      case Connection::kPushNewFunction: {
        int arity = connection_->ReadInt();
        int literals = connection_->ReadInt();
        int length;
        uint8* bytes = connection_->ReadBytes(&length);
        List<uint8> bytecodes(bytes, length);
        PushNewFunction(arity, literals, bytecodes);
        bytecodes.Delete();
        break;
      }

      case Connection::kPushNewInitializer: {
        PushNewInitializer();
        break;
      }

      case Connection::kPushNewClass: {
        PushNewClass(connection_->ReadInt());
        break;
      }

      case Connection::kPushBuiltinClass: {
        Names::Id name = static_cast<Names::Id>(connection_->ReadInt());
        int fields = connection_->ReadInt();
        PushBuiltinClass(name, fields);
        break;
      }

      case Connection::kPushConstantList: {
        int length = connection_->ReadInt();
        PushConstantList(length);
        break;
      }

      case Connection::kPushConstantMap: {
        int length = connection_->ReadInt();
        PushConstantMap(length);
        break;
      }

      case Connection::kChangeSuperClass: {
        ChangeSuperClass();
        break;
      }

      case Connection::kChangeMethodTable: {
        ChangeMethodTable(connection_->ReadInt());
        break;
      }

      case Connection::kChangeMethodLiteral: {
        ChangeMethodLiteral(connection_->ReadInt());
        break;
      }

      case Connection::kChangeStatics: {
        ChangeStatics(connection_->ReadInt());
        break;
      }

      case Connection::kChangeSchemas: {
        int count = connection_->ReadInt();
        int delta = connection_->ReadInt();
        ChangeSchemas(count, delta);
        break;
      }

      case Connection::kPrepareForChanges: {
        PrepareForChanges();
        break;
      }

      case Connection::kCommitChanges: {
        bool success = CommitChanges(connection_->ReadInt());
        WriteBuffer buffer;
        buffer.WriteBoolean(success);
        if (success) {
          buffer.WriteString("Successfully applied program changes.");
        } else {
          buffer.WriteString("Could not apply program changes.");
        }
        connection_->Send(Connection::kCommitChangesResult, buffer);
        break;
      }

      case Connection::kDiscardChanges: {
        DiscardChanges();
        break;
      }

      case Connection::kMapLookup: {
        int map_index = connection_->ReadInt();
        WriteBuffer buffer;
        buffer.WriteInt64(MapLookupByObject(map_index, Top()));
        connection_->Send(Connection::kObjectId, buffer);
        break;
      }

      default: {
        FATAL1("Unknown message opcode %d", opcode);
      }
    }
  }
}

void Session::IteratePointers(PointerVisitor* visitor) {
  stack_.IteratePointers(visitor);
  changes_.IteratePointers(visitor);
  for (int i = 0; i < maps_.length(); ++i) {
    ObjectMap* map = maps_[i];
    if (map != NULL) {
      // TODO(kasperl): Move the table clearing to a GC pre-phase.
      map->ClearTableByObject();
      map->IteratePointers(visitor);
    }
  }
}

bool Session::ProcessRun() {
  bool process_started = false;
  bool has_result = false;
  bool result = false;
  while (true) {
    MainThreadResumeKind resume_kind;
    main_thread_monitor_->Lock();
    while (main_thread_resume_kind_ == kUnknown) main_thread_monitor_->Wait();
    resume_kind = main_thread_resume_kind_;
    main_thread_resume_kind_ = kUnknown;
    main_thread_monitor_->Notify();
    main_thread_monitor_->Unlock();
    switch (resume_kind) {
      case kError:
        ASSERT(!debugging_);
        return false;
      case kSnapshotDone:
        ASSERT(!debugging_);
        return true;
      case kProcessRun:
        process_started = true;

        {
          Scheduler scheduler;
          scheduler.ScheduleProgram(program_, process_);
          result = scheduler.Run();
          scheduler.UnscheduleProgram(program_);
        }

        has_result = true;
        if (!debugging_) return result;
        break;
      case kSessionEnd:
        ASSERT(!debugging_);
        if (!process_started && process_ != NULL) {
          // If the process was spawned but not started, the scheduler does not
          // know about it and we are therefore responsible for deleting it.
          program()->DeleteProcess(process_);
        }
        Print::UnregisterPrintInterceptors();
        if (!process_started) return true;
        if (has_result) return result;
        break;
      case kUnknown:
        UNREACHABLE();
        break;
    }
  }
  return result;
}

bool Session::WriteSnapshot(const char* path) {
  program()->set_entry(Function::cast(Pop()));
  program()->set_main_arity(Smi::cast(Pop())->value());
  // Make sure that the program is in the compact form before
  // snapshotting.
  if (!program()->is_compact()) {
    ProgramFolder program_folder(program());
    program_folder.Fold();
  }
  SnapshotWriter writer;
  List<uint8> snapshot = writer.WriteProgram(program());
  bool success = Platform::StoreFile(path, snapshot);
  snapshot.Delete();
  return success;
}

void Session::NewMap(int map_index) {
  int length = maps_.length();
  if (map_index >= length) {
    maps_.Reallocate(map_index + 1);
    for (int i = length; i <= map_index; i++) {
      maps_[i] = NULL;
    }
  }
  ObjectMap* existing = maps_[map_index];
  if (existing != NULL) delete existing;
  maps_[map_index] = new ObjectMap(64);
}

void Session::DeleteMap(int map_index) {
  ObjectMap* map = maps_[map_index];
  if (map == NULL) return;
  delete map;
  maps_[map_index] = NULL;
}

void Session::PushFromMap(int map_index, int64 id) {
  Push(maps_[map_index]->LookupById(id));
}

void Session::PopToMap(int map_index, int64 id) {
  maps_[map_index]->Add(id, Pop());
}

void Session::AddToMap(int map_index, int64 id, Object* value) {
  maps_[map_index]->Add(id, value);
}

void Session::RemoveFromMap(int map_index, int64 id) {
  maps_[map_index]->RemoveById(id);
}

int64 Session::MapLookupByObject(int map_index, Object* object) {
  int64 id = -1;
  ObjectMap* map = maps_[map_index];
  if (map != NULL) id = map->LookupByObject(object);
  return id;
}

Object* Session::MapLookupById(int map_index, int64 id) {
  return maps_[map_index]->LookupById(id);
}

void Session::PushNull() {
  Push(program()->null_object());
}

void Session::PushBoolean(bool value) {
  if (value) {
    Push(program()->true_object());
  } else {
    Push(program()->false_object());
  }
}

void Session::PushNewInteger(int64 value) {
  if (Smi::IsValid(value)) {
    Push(Smi::FromWord(value));
  } else {
    GC_AND_RETRY_ON_ALLOCATION_FAILURE(result, program()->CreateInteger(value));
    Push(result);
  }
}

void Session::PushNewDouble(double value) {
  GC_AND_RETRY_ON_ALLOCATION_FAILURE(result, program()->CreateDouble(value));
  Push(result);
}

void Session::PushNewString(List<uint16> contents) {
  GC_AND_RETRY_ON_ALLOCATION_FAILURE(result, program()->CreateString(contents));
  Push(result);
}

void Session::PushNewInstance() {
  GC_AND_RETRY_ON_ALLOCATION_FAILURE(
      result,
      program()->CreateInstance(Class::cast(Top())));
  Class* klass = Class::cast(Pop());
  Instance* instance = Instance::cast(result);
  int fields = klass->NumberOfInstanceFields();
  for (int i = fields - 1; i >= 0; i--) {
    instance->SetInstanceField(i, Pop());
  }
  Push(instance);
}

void Session::PushNewArray(int length) {
  GC_AND_RETRY_ON_ALLOCATION_FAILURE(result, program()->CreateArray(length));
  Array* array = Array::cast(result);
  for (int i = length - 1; i >= 0; i--) {
    array->set(i, Pop());
  }
  Push(array);
}

static void RewriteLiteralIndicesToOffsets(Function* function) {
  uint8_t* bcp = function->bytecode_address_for(0);

  while (true) {
    Opcode opcode = static_cast<Opcode>(*bcp);

    switch (opcode) {
      case kLoadConstUnfold:
      case kInvokeStaticUnfold:
      case kInvokeFactoryUnfold:
      case kAllocateUnfold:
      case kAllocateImmutableUnfold: {
        int literal_index = Utils::ReadInt32(bcp + 1);
        Object** literal_address =
            function->literal_address_for(literal_index);
        int offset = reinterpret_cast<uint8_t*>(literal_address) - bcp;
        Utils::WriteInt32(bcp + 1, offset);
        break;
      }
      case kMethodEnd:
        return;
      case kLoadConst:
      case kInvokeStatic:
      case kInvokeFactory:
      case kAllocate:
      case kAllocateImmutable:
        // We should only be creating unfolded functions via a
        // session.
        UNREACHABLE();
      default:
        ASSERT(opcode < Bytecode::kNumBytecodes);
        break;
    }

    bcp += Bytecode::Size(opcode);
  }

  UNREACHABLE();
}

void Session::PushNewFunction(int arity, int literals, List<uint8> bytecodes) {
  ASSERT(!program()->is_compact());

  GC_AND_RETRY_ON_ALLOCATION_FAILURE(
      result,
      program()->CreateFunction(arity, bytecodes, literals));
  Function* function = Function::cast(result);
  for (int i = literals - 1; i >= 0; --i) {
    function->set_literal_at(i, Pop());
  }
  RewriteLiteralIndicesToOffsets(function);
  Push(function);

  if (Flags::log_decoder) {
    Print::Out("Method:\n");
    uint8* bytes = function->bytecode_address_for(0);
    Opcode opcode;
    int i = 0;
    do {
      opcode = static_cast<Opcode>(bytes[i]);
      Print::Out("  %04d: ", i);
      i += Bytecode::Print(bytes + i);
      Print::Out("\n");
    } while (opcode != kMethodEnd);
  }
}

void Session::PushNewInitializer() {
  GC_AND_RETRY_ON_ALLOCATION_FAILURE(
      result,
      program()->CreateInitializer(Function::cast(Top())));
  Pop();
  Push(result);
}

void Session::PushNewClass(int fields) {
  GC_AND_RETRY_ON_ALLOCATION_FAILURE(result, program()->CreateClass(fields));
  Push(result);
}

void Session::PushBuiltinClass(Names::Id name, int fields) {
  Class* klass = NULL;
  if (name == Names::kObject) {
    klass = program()->object_class();
  } else if (name == Names::kBool) {
    klass = program()->bool_class();
  } else if (name == Names::kNull) {
    klass = program()->null_object()->get_class();
  } else if (name == Names::kDouble) {
    klass = program()->double_class();
  } else if (name == Names::kSmi) {
    klass = program()->smi_class();
  } else if (name == Names::kInt) {
    klass = program()->int_class();
  } else if (name == Names::kMint) {
    klass = program()->large_integer_class();
  } else if (name == Names::kConstantList) {
    klass = program()->constant_list_class();
  } else if (name == Names::kConstantMap) {
    klass = program()->constant_map_class();
  } else if (name == Names::kNum) {
    klass = program()->num_class();
  } else if (name == Names::kString) {
    klass = program()->string_class();
  } else if (name == Names::kCoroutine) {
    klass = program()->coroutine_class();
  } else if (name == Names::kPort) {
    klass = program()->port_class();
  } else if (name == Names::kForeignMemory) {
    klass = program()->foreign_memory_class();
  } else if (name == Names::kForeignFunction) {
    klass = program()->foreign_function_class();
  } else {
    UNREACHABLE();
  }

  ASSERT(klass->instance_format().type() != InstanceFormat::INSTANCE_TYPE ||
         klass->NumberOfInstanceFields() == fields);

  Push(klass);
}

void Session::PushConstantList(int length) {
  PushNewArray(length);
  GC_AND_RETRY_ON_ALLOCATION_FAILURE(
      result,
      program()->CreateInstance(program()->constant_list_class()));
  Instance* list = Instance::cast(result);
  ASSERT(list->get_class()->NumberOfInstanceFields() == 1);
  list->SetInstanceField(0, Pop());
  Push(list);
}

void Session::PushConstantMap(int length) {
  GC_AND_RETRY_ON_ALLOCATION_FAILURE(
      result,
      program()->CreateInstance(program()->constant_map_class()));
  Instance* map = Instance::cast(result);
  ASSERT(map->get_class()->NumberOfInstanceFields() == 2);
  // Values.
  map->SetInstanceField(1, Pop());
  // Keys.
  map->SetInstanceField(0, Pop());
  Push(map);
}

void Session::PrepareForChanges() {
  if (program()->is_compact()) {
    Scheduler* scheduler = program()->scheduler();
    if (scheduler != NULL) {
      scheduler->StopProgram(program());
    }
    {
      ProgramFolder program_folder(program());
      program_folder.Unfold();
    }
    if (scheduler != NULL) {
      scheduler->ResumeProgram(program());
    }
  }
}

void Session::ChangeSuperClass() {
  PostponeChange(kChangeSuperClass, 2);
}

void Session::CommitChangeSuperClass(Array* change) {
  Class* klass = Class::cast(change->get(1));
  Class* super = Class::cast(change->get(2));
  klass->set_super_class(super);
}

void Session::ChangeMethodTable(int length) {
  PushNewArray(length * 2);
  PostponeChange(kChangeMethodTable, 2);
}

void Session::CommitChangeMethodTable(Array* change) {
  Class* clazz = Class::cast(change->get(1));
  Array* methods = Array::cast(change->get(2));
  clazz->set_methods(methods);
}

void Session::ChangeMethodLiteral(int index) {
  Push(Smi::FromWord(index));
  PostponeChange(kChangeMethodLiteral, 3);
}

void Session::CommitChangeMethodLiteral(Array* change) {
  Function* function = Function::cast(change->get(1));
  Object* literal = change->get(2);
  int index = Smi::cast(change->get(3))->value();
  function->set_literal_at(index, literal);
}

void Session::ChangeStatics(int count) {
  PushNewArray(count);
  PostponeChange(kChangeStatics, 1);
}

void Session::CommitChangeStatics(Array* change) {
  program()->set_static_fields(Array::cast(change->get(1)));
}

void Session::ChangeSchemas(int count, int delta) {
  // Stack: <count> classes + transformation array
  Push(Smi::FromWord(delta));
  PostponeChange(kChangeSchemas, count + 2);
}

void Session::CommitChangeSchemas(Array* change) {
  // TODO(kasperl): Rework this so we can allow allocation failures
  // as part of allocating the new classes.
  Space* space = program()->heap()->space();
  NoAllocationFailureScope scope(space);

  int length = change->length();
  Array* transformation = Array::cast(change->get(length - 2));
  int delta = Smi::cast(change->get(length - 1))->value();
  for (int i = 1; i < length - 2; i++) {
    Class* original = Class::cast(change->get(i));
    int fields = original->NumberOfInstanceFields() + delta;
    Class* target = Class::cast(program()->CreateClass(fields));
    target->set_super_class(original->super_class());
    target->set_methods(original->methods());
    original->Transform(target, transformation);
  }
}

bool Session::CommitChanges(int count) {
  Scheduler* scheduler = program()->scheduler();
  if (scheduler != NULL) {
    scheduler->StopProgram(program());
  }

  ASSERT(!program()->is_compact());

  ASSERT(count == changes_.length());

  // TODO(kustermann): Sanity check all changes the compiler gave us.
  // If we are unable to apply a change, we should continue the program
  // and "return false".

  bool schemas_changed = false;
  for (int i = 0; i < count; i++) {
    Array* array = Array::cast(changes_[i]);
    Change change = static_cast<Change>(Smi::cast(array->get(0))->value());
    switch (change) {
      case kChangeSuperClass:
        ASSERT(!schemas_changed);
        CommitChangeSuperClass(array);
        break;
      case kChangeMethodTable:
        ASSERT(!schemas_changed);
        CommitChangeMethodTable(array);
        break;
      case kChangeMethodLiteral:
        CommitChangeMethodLiteral(array);
        break;
      case kChangeStatics:
        CommitChangeStatics(array);
        break;
      case kChangeSchemas:
        CommitChangeSchemas(array);
        schemas_changed = true;
        break;
      default:
        UNREACHABLE();
        break;
    }
  }
  changes_.Clear();

  if (schemas_changed) TransformInstances();

  // Fold the program after applying changes to continue running in the
  // optimized compact form.
  //
  // NOTE: We disable heap validation always if we changed any objects in the
  // heaps, because [TransformInstances] will install a forwarding pointer and
  // thereby destroy the class pointer. The heap verification code will traverse
  // all heaps and doing so requires a valid class pointer.
  {
    ProgramFolder program_folder(program());
    program_folder.Fold(schemas_changed);
  }

  if (scheduler != NULL) {
    scheduler->ResumeProgram(program());
  }

  return true;
}

void Session::DiscardChanges() {
  changes_.Clear();
}

void Session::PostponeChange(Change change, int count) {
  GC_AND_RETRY_ON_ALLOCATION_FAILURE(result,
      program()->CreateArray(count + 1));
  Array* array = Array::cast(result);
  array->set(0, Smi::FromWord(change));
  for (int i = count; i >= 1; i--) {
    array->set(i, Pop());
  }
  changes_.Add(array);
}

bool Session::UncaughtException(Process* process) {
  if (process_ == process) {
    execution_paused_ = true;
    WriteBuffer buffer;
    connection_->Send(Connection::kUncaughtException, buffer);
    return true;
  }
  return false;
}

bool Session::BreakPoint(Process* process) {
  if (process_ == process) {
    execution_paused_ = true;
    DebugInfo* debug_info = process->debug_info();
    debug_info->set_is_stepping(false);
    WriteBuffer buffer;
    buffer.WriteInt(debug_info->current_breakpoint_id());
    StackWalker::ComputeTopStackFrame(process, this);
    buffer.WriteInt64(MapLookupByObject(method_map_id_, Top()));
    // Drop function from session stack.
    Drop(1);
    // Pop bytecode index from session stack and send it.
    buffer.WriteInt64(PopInteger());
    connection_->Send(Connection::kProcessBreakpoint, buffer);
    return true;
  }
  return false;
}

bool Session::ProcessTerminated(Process* process) {
  if (process_ == process) {
    WriteBuffer buffer;
    connection_->Send(Connection::kProcessTerminated, buffer);
    process_ = NULL;
    program_->scheduler()->ExitAtTermination(process);
    return true;
  }
  return false;
}

bool Session::CompileTimeError(Process* process) {
  if (process_ == process) {
    execution_paused_ = true;
    WriteBuffer buffer;
    connection_->Send(Connection::kProcessCompileTimeError, buffer);
    return true;
  }
  return false;
}

class TransformInstancesPointerVisitor : public PointerVisitor {
 public:
  explicit TransformInstancesPointerVisitor(Heap* heap, Heap* immutable_heap)
      : heap_(heap), immutable_heap_(immutable_heap) { }

  virtual void VisitClass(Object** p) {
    // The class pointer in the header of an object should not
    // be updated even if it points to a transformed class. If we
    // updated the pointer, the new class would have the wrong
    // instance format for the non-transformed, old instance.
  }

  virtual void VisitBlock(Object** start, Object** end) {
    for (Object** p = start; p < end; p++) {
      Object* object = *p;
      if (!object->IsHeapObject()) continue;
      HeapObject* heap_object = HeapObject::cast(object);
      HeapObject* forward = heap_object->forwarding_address();
      if (forward != NULL) {
        *p = forward;
      } else if (heap_object->IsInstance()) {
        Instance* instance = Instance::cast(heap_object);
        if (instance->get_class()->IsTransformed()) {
          Instance* clone;

          if (heap_->space()->Includes(instance->address())) {
            clone = instance->CloneTransformed(heap_);
          } else {
            ASSERT(immutable_heap_->space()->Includes(instance->address()));
            clone = instance->CloneTransformed(immutable_heap_);
          }

          instance->set_forwarding_address(clone);
          *p = clone;
        }
      } else if (heap_object->IsClass()) {
        Class* clazz = Class::cast(heap_object);
        if (clazz->IsTransformed()) {
          *p = clazz->TransformationTarget();
        }
      }
    }
  }

 private:
  Heap* const heap_;
  Heap* const immutable_heap_;
};

class TransformInstancesProcessVisitor : public ProcessVisitor {
 public:
  virtual void VisitProcess(Process* process) {
    // NOTE: We need to take all spaces which are getting merged into the
    // process heap, because otherwise we'll not update the pointers it has to
    // the program space / to the process heap objects which were transformed.
    process->TakeChildHeaps();

    Heap* heap = process->heap();
    Heap* immutable_heap = process->immutable_heap();

    Space* space = heap->space();
    Space* immutable_space = immutable_heap->space();

    NoAllocationFailureScope scope(space);
    NoAllocationFailureScope scope2(immutable_space);

    TransformInstancesPointerVisitor pointer_visitor(heap, immutable_heap);

    process->IterateRoots(&pointer_visitor);

    ASSERT(!space->is_empty());
    space->CompleteTransformations(&pointer_visitor, process);
    immutable_space->CompleteTransformations(&pointer_visitor, process);
  }
};

void Session::TransformInstances() {
  // Make sure we don't have any mappings that rely on the addresses
  // of objects *not* changing as we transform instances.
  for (int i = 0; i < maps_.length(); ++i) {
    ObjectMap* map = maps_[i];
    ASSERT(!map->HasTableByObject());
  }

  // Deal with program space before the process spaces. This allows
  // the [TransformInstancesProcessVisitor] to use the already installed
  // forwarding pointers in program space.

  Space* space = program()->heap()->space();
  NoAllocationFailureScope scope(space);
  TransformInstancesPointerVisitor pointer_visitor(program()->heap(), NULL);
  program()->IterateRoots(&pointer_visitor);
  ASSERT(!space->is_empty());
  space->CompleteTransformations(&pointer_visitor, NULL);

  TransformInstancesProcessVisitor process_visitor;
  program()->VisitProcesses(&process_visitor);
}

}  // namespace fletch
