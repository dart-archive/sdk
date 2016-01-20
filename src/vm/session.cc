// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifdef FLETCH_ENABLE_LIVE_CODING

#include "src/vm/session.h"

#include "src/shared/bytecodes.h"
#include "src/shared/connection.h"
#include "src/shared/flags.h"
#include "src/shared/platform.h"
#include "src/shared/version.h"

#include "src/vm/frame.h"
#include "src/vm/heap_validator.h"
#include "src/vm/native_interpreter.h"
#include "src/vm/links.h"
#include "src/vm/object_map.h"
#include "src/vm/process.h"
#include "src/vm/scheduler.h"
#include "src/vm/snapshot.h"
#include "src/vm/thread.h"

#define GC_AND_RETRY_ON_ALLOCATION_FAILURE(var, exp)    \
  Object* var = (exp);                                  \
  ASSERT(execution_paused_);                            \
  if (var->IsRetryAfterGCFailure()) {                   \
    program()->CollectGarbage();                        \
    var = (exp);                                        \
    ASSERT(!var->IsFailure());                          \
  }

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

class PostponedChange {
 public:
  PostponedChange(Object** description, int size)
      : description_(description), size_(size), next_(NULL) {
    ++number_of_changes_;
  }

  ~PostponedChange() {
    delete[] description_;
    --number_of_changes_;
  }

  PostponedChange* next() const { return next_; }
  void set_next(PostponedChange* change) { next_ = change; }

  Object* get(int i) const { return description_[i]; }
  int size() const { return size_; }

  static int number_of_changes() { return number_of_changes_; }

  void IteratePointers(PointerVisitor* visitor) {
    for (int i = 0; i < size_; i++) {
      visitor->Visit(description_ + i);
    }
  }

 private:
  static int number_of_changes_;
  Object** description_;
  int size_;
  PostponedChange* next_;
};

int PostponedChange::number_of_changes_ = 0;

Session::Session(Connection* connection)
    : connection_(connection),
      program_(NULL),
      process_(NULL),
      next_process_id_(0),
      execution_paused_(true),
      request_execution_pause_(false),
      debugging_(false),
      method_map_id_(-1),
      class_map_id_(-1),
      fibers_map_id_(-1),
      stack_(0),
      first_change_(NULL),
      last_change_(NULL),
      has_program_update_error_(false),
      program_update_error_(NULL),
      main_thread_monitor_(Platform::CreateMonitor()),
      main_thread_resume_kind_(kUnknown) {
#ifdef FLETCH_ENABLE_PRINT_INTERCEPTORS
  ConnectionPrintInterceptor* interceptor =
      new ConnectionPrintInterceptor(connection_);
  Print::RegisterPrintInterceptor(interceptor);
#endif  // FLETCH_ENABLE_PRINT_INTERCEPTORS
}

Session::~Session() {
#ifdef FLETCH_ENABLE_PRINT_INTERCEPTORS
  Print::UnregisterPrintInterceptors();
#endif  // FLETCH_ENABLE_PRINT_INTERCEPTORS

  delete connection_;
  delete program_;
  delete main_thread_monitor_;
  for (int i = 0; i < maps_.length(); ++i) delete maps_[i];
  maps_.Delete();
}

void Session::Initialize() {
  program_ = new Program(Program::kBuiltViaSession);
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

void Session::JoinMessageProcessingThread() { message_handling_thread_.Join(); }

int64_t Session::PopInteger() {
  Object* top = Pop();
  if (top->IsLargeInteger()) {
    return LargeInteger::cast(top)->value();
  }
  return Smi::cast(top)->value();
}

void Session::SignalMainThread(MainThreadResumeKind kind) {
  while (main_thread_resume_kind_ != kUnknown) main_thread_monitor_->Wait();
  main_thread_resume_kind_ = kind;
  main_thread_monitor_->NotifyAll();
}

void Session::SendDartValue(Object* value) {
  WriteBuffer buffer;
  if (value->IsSmi() || value->IsLargeInteger()) {
    int64_t int_value = value->IsSmi() ? Smi::cast(value)->value()
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
  } else if (value->IsOneByteString()) {
    // TODO(ager): We should send the character data as 8-bit values
    // instead of 32-bit values.
    OneByteString* str = OneByteString::cast(value);
    for (int i = 0; i < str->length(); i++) {
      buffer.WriteInt(str->get_char_code(i));
    }
    connection_->Send(Connection::kString, buffer);
  } else if (value->IsClass()) {
    Push(HeapObject::cast(value));
    buffer.WriteInt64(MapLookupByObject(class_map_id_, Top()));
    connection_->Send(Connection::kClass, buffer);
  } else if (value->IsTwoByteString()) {
    // TODO(ager): We should send the character data as 16-bit values
    // instead of 32-bit values.
    TwoByteString* str = TwoByteString::cast(value);
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

void Session::SendSnapshotResult(ClassOffsetsType* class_offsets,
                                 FunctionOffsetsType* function_offsets) {
  WriteBuffer buffer;

  // Write the hashtag for the program.
  buffer.WriteInt(program()->hashtag());

  // Class offset table
  buffer.WriteInt(5 * class_offsets->size());
  for (auto it = class_offsets->Begin(); it != class_offsets->End(); ++it) {
    Class* klass = it->first;
    const PortableOffset& offset = it->second;

    buffer.WriteInt(MapLookupByObject(class_map_id_, klass));
    buffer.WriteInt(offset.offset_64bits_double);
    buffer.WriteInt(offset.offset_64bits_float);
    buffer.WriteInt(offset.offset_32bits_double);
    buffer.WriteInt(offset.offset_32bits_float);
  }

  // Function offset table
  buffer.WriteInt(5 * function_offsets->size());
  for (auto it = function_offsets->Begin(); it != function_offsets->End();
       ++it) {
    Function* function = it->first;
    const PortableOffset& offset = it->second;

    buffer.WriteInt(MapLookupByObject(method_map_id_, function));
    buffer.WriteInt(offset.offset_64bits_double);
    buffer.WriteInt(offset.offset_64bits_float);
    buffer.WriteInt(offset.offset_32bits_double);
    buffer.WriteInt(offset.offset_32bits_float);
  }

  connection_->Send(Connection::kWriteSnapshotResult, buffer);
}

void Session::RequestExecutionPause() {
  ScopedMonitorLock scoped_lock(main_thread_monitor_);
  if (!execution_paused_) {
    request_execution_pause_ = true;
  }
}

// Caller thread must have a lock on main_thread_monitor_, ie,
// ProcessContinue should only be called from within ProcessMessage's
// main loop.
void Session::PauseExecution() {
  ASSERT(request_execution_pause_);
  ASSERT(!execution_paused_);
  Scheduler* scheduler = program()->scheduler();
  ASSERT(scheduler != NULL);
  request_execution_pause_ = false;
  execution_paused_ = true;
  scheduler->StopProgram(program());
  scheduler->PauseGcThread();
}

// Caller thread must have a lock on main_thread_monitor_, ie,
// ProcessContinue should only be called from within ProcessMessage's
// main loop.
void Session::ResumeExecution() {
  ASSERT(IsScheduledAndPaused());
  execution_paused_ = false;
  Scheduler* scheduler = program()->scheduler();
  scheduler->ResumeGcThread();
  scheduler->ResumeProgram(program());
}

// Caller thread must have a lock on main_thread_monitor_, ie,
// ProcessContinue should only be called from within ProcessMessage's
// main loop.
void Session::ProcessContinue(Process* process) {
  ResumeExecution();
  process->program()->scheduler()->ContinueProcess(process);
}

void Session::SendStackTrace(Stack* stack) {
  int frames = PushStackFrames(stack);
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

static void MessageProcessingError(const char* message) {
  Print::UnregisterPrintInterceptors();
  Print::Error(message);
  Platform::Exit(-1);
}

void Session::HandShake() {
  Connection::Opcode opcode = connection_->Receive();
  if (opcode != Connection::kHandShake) {
    MessageProcessingError("Error: Invalid handshake message from compiler.\n");
  }
  int compiler_version_length;
  uint8* compiler_version = connection_->ReadBytes(&compiler_version_length);
  const char* version = GetVersion();
  int version_length = strlen(version);
  bool version_match =
      (version_length == compiler_version_length) &&
      (strncmp(version, reinterpret_cast<char*>(compiler_version),
               compiler_version_length) == 0);
  free(compiler_version);
  WriteBuffer buffer;
  buffer.WriteBoolean(version_match);
  buffer.WriteInt(version_length);
  buffer.WriteString(version);
  connection_->Send(Connection::kHandShakeResult, buffer);
  if (!version_match) {
    MessageProcessingError("Error: Different compiler and VM version.\n");
  }
}

void Session::ProcessMessages() {
  // A session always starts with a handshake verifying that the
  // compiler and VM have the same version.
  HandShake();

  while (true) {
    Connection::Opcode opcode = connection_->Receive();

    ScopedMonitorLock scoped_lock(main_thread_monitor_);
    if (request_execution_pause_) PauseExecution();

    switch (opcode) {
      case Connection::kConnectionError: {
        MessageProcessingError("Lost connection to compiler.");
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

      case Connection::kProcessDebugInterrupt: {
        if (process_ == NULL) break;
        process_->DebugInterrupt();
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
        ASSERT(execution_paused_);
        process_->EnsureDebuggerAttached(this);
        WriteBuffer buffer;
        int bytecode_index = connection_->ReadInt();
        Function* function = Function::cast(Pop());
        DebugInfo* debug_info = process_->debug_info();
        int id = debug_info->SetBreakpoint(function, bytecode_index);
        buffer.WriteInt(id);
        connection_->Send(Connection::kProcessSetBreakpoint, buffer);
        break;
      }

      case Connection::kProcessDeleteBreakpoint: {
        ASSERT(execution_paused_);
        process_->EnsureDebuggerAttached(this);
        WriteBuffer buffer;
        int id = connection_->ReadInt();
        bool deleted = process_->debug_info()->DeleteBreakpoint(id);
        ASSERT(deleted);
        buffer.WriteInt(id);
        connection_->Send(Connection::kProcessDeleteBreakpoint, buffer);
        break;
      }

      case Connection::kProcessStep: {
        ASSERT(IsScheduledAndPaused());
        process_->EnsureDebuggerAttached(this);
        process_->debug_info()->SetStepping();
        ProcessContinue(process_);
        break;
      }

      case Connection::kProcessStepOver: {
        ASSERT(IsScheduledAndPaused());
        process_->EnsureDebuggerAttached(this);
        int breakpoint_id = process_->PrepareStepOver();
        WriteBuffer buffer;
        buffer.WriteInt(breakpoint_id);
        connection_->Send(Connection::kProcessSetBreakpoint, buffer);
        ProcessContinue(process_);
        break;
      }

      case Connection::kProcessStepOut: {
        ASSERT(IsScheduledAndPaused());
        process_->EnsureDebuggerAttached(this);
        int breakpoint_id = process_->PrepareStepOut();
        WriteBuffer buffer;
        buffer.WriteInt(breakpoint_id);
        connection_->Send(Connection::kProcessSetBreakpoint, buffer);
        ProcessContinue(process_);
        break;
      }

      case Connection::kProcessStepTo: {
        ASSERT(IsScheduledAndPaused());
        process_->EnsureDebuggerAttached(this);
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
        ASSERT(IsScheduledAndPaused());
        ProcessContinue(process_);
        break;
      }

      case Connection::kProcessBacktraceRequest: {
        ASSERT(IsScheduledAndPaused());
        int process_id = connection_->ReadInt() - 1;
        Process* process = GetProcess(process_id);
        Stack* stack = process->stack();
        SendStackTrace(stack);
        break;
      }

      case Connection::kProcessFiberBacktraceRequest: {
        ASSERT(IsScheduledAndPaused());
        int64 fiber_id = connection_->ReadInt64();
        Stack* stack = Stack::cast(MapLookupById(fibers_map_id_, fiber_id));
        SendStackTrace(stack);
        break;
      }

      case Connection::kProcessUncaughtExceptionRequest: {
        ASSERT(IsScheduledAndPaused());
        Object* exception = process_->exception();
        if (exception->IsInstance()) {
          SendInstanceStructure(Instance::cast(exception));
        } else {
          SendDartValue(exception);
        }
        break;
      }

      case Connection::kProcessLocal:
      case Connection::kProcessLocalStructure: {
        ASSERT(IsScheduledAndPaused());
        int frame_index = connection_->ReadInt();
        int slot = connection_->ReadInt();
        Stack* stack = process_->stack();
        Frame frame(stack);
        for (int i = 0; i <= frame_index; i++) frame.MovePrevious();
        word index = frame.FirstLocalIndex() - slot;
        if (index < frame.LastLocalIndex()) FATAL("Illegal slot offset");
        Object* local = stack->get(index);
        if (opcode == Connection::kProcessLocalStructure &&
            local->IsInstance()) {
          SendInstanceStructure(Instance::cast(local));
        } else {
          SendDartValue(local);
        }
        break;
      }

      case Connection::kProcessRestartFrame: {
        ASSERT(IsScheduledAndPaused());
        int frame_index = connection_->ReadInt();
        RestartFrame(frame_index);
        process_->set_exception(process_->program()->null_object());
        DebugInfo* debug_info = process_->debug_info();
        if (debug_info != NULL) debug_info->ClearBreakpoint();
        ProcessContinue(process_);
        break;
      }

      case Connection::kSessionEnd: {
        debugging_ = false;
        // If execution is paused we delete the process to allow the
        // VM to terminate.
        if (IsScheduledAndPaused()) {
          ResumeExecution();
          Scheduler* scheduler = program()->scheduler();
          switch (process_->state()) {
            case Process::kBreakPoint:
              scheduler->ExitAtBreakpoint(process_);
              break;
            case Process::kCompileTimeError:
              scheduler->ExitAtCompileTimeError(process_);
              break;
            case Process::kUncaughtException:
              scheduler->ExitAtUncaughtException(process_, false);
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
        ASSERT(IsScheduledAndPaused());
        // TODO(ager): Potentially optimize this to not require a full
        // process GC to locate the live stacks?
        int number_of_stacks = program()->CollectMutableGarbageAndChainStacks();
        Object* current = program()->stack_chain();
        for (int i = 0; i < number_of_stacks; i++) {
          Stack* stack = Stack::cast(current);
          AddToMap(fibers_map_id_, i, stack);
          current = stack->next();
          // Unchain stacks.
          stack->set_next(Smi::FromWord(0));
        }
        ASSERT(current == NULL);
        program()->ClearStackChain();
        WriteBuffer buffer;
        buffer.WriteInt(number_of_stacks);
        connection_->Send(Connection::kProcessNumberOfStacks, buffer);
        break;
      }

      case Connection::kProcessGetProcessIds: {
        ASSERT(IsScheduledAndPaused());
        int count = 0;
        for (Process* process = program()->process_list_head();
             process != NULL;
             process = process->process_list_next()) {
          ++count;
        }

        WriteBuffer buffer;
        buffer.WriteInt(count);
        for (Process* process = program()->process_list_head();
             process != NULL;
             process = process->process_list_next()) {
          process->EnsureDebuggerAttached(this);
          buffer.WriteInt(process->debug_info()->process_id());
        }

        connection_->Send(Connection::kProcessGetProcessIdsResult, buffer);
        break;
      }

      case Connection::kWriteSnapshot: {
        int length;
        uint8* data = connection_->ReadBytes(&length);
        const char* path = reinterpret_cast<const char*>(data);
        ASSERT(static_cast<int>(strlen(path)) == length - 1);

        FunctionOffsetsType function_offsets;
        ClassOffsetsType class_offsets;
        bool success = WriteSnapshot(path, &function_offsets, &class_offsets);
        free(data);

        SendSnapshotResult(&class_offsets, &function_offsets);

        SignalMainThread(success ? kSnapshotDone : kError);
        return;
      }

      case Connection::kCollectGarbage: {
        ASSERT(execution_paused_);
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

      case Connection::kPushNewBigInteger: {
        bool negative = connection_->ReadBoolean();
        int used = connection_->ReadInt();
        int class_map = connection_->ReadInt();
        int64 bigint_class_id = connection_->ReadInt64();
        int64 uint32_digits_class_id = connection_->ReadInt64();

        int rounded_used = (used & 1) == 0 ? used : used + 1;

        // First two arguments for _Bigint allocation.
        PushBoolean(negative);
        PushNewInteger(used);

        // Arguments for _Uint32Digits allocation.
        PushNewInteger(rounded_used);
        GC_AND_RETRY_ON_ALLOCATION_FAILURE(
            object, program()->CreateByteArray(rounded_used * 4));
        ByteArray* backing = ByteArray::cast(object);
        for (int i = 0; i < used; i++) {
          uint32 part = static_cast<uint32>(connection_->ReadInt());
          uint8* part_address = backing->byte_address_for(i * 4);
          *(reinterpret_cast<uint32*>(part_address)) = part;
        }
        Push(backing);
        // _Uint32Digits allocation.
        PushFromMap(class_map, uint32_digits_class_id);
        PushNewInstance();

        // _Bigint allocation.
        PushFromMap(class_map, bigint_class_id);
        PushNewInstance();

        break;
      }

      case Connection::kPushNewDouble: {
        PushNewDouble(connection_->ReadDouble());
        break;
      }

      case Connection::kPushNewOneByteString: {
        int length;
        uint8* bytes = connection_->ReadBytes(&length);
        List<uint8> contents(bytes, length);
        PushNewOneByteString(contents);
        contents.Delete();
        break;
      }

      case Connection::kPushNewTwoByteString: {
        int length;
        uint8* bytes = connection_->ReadBytes(&length);
        ASSERT((length & 1) == 0);
        List<uint16> contents(reinterpret_cast<uint16*>(bytes), length >> 1);
        PushNewTwoByteString(contents);
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

      case Connection::kPushConstantByteList: {
        int length = connection_->ReadInt();
        PushConstantByteList(length);
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
          buffer.WriteString("Successfully applied program update.");
        } else {
          if (program_update_error_ != NULL) {
            buffer.WriteString(program_update_error_);
          } else {
            buffer.WriteString(
                "An unknown error occured during program update.");
          }
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

      default: { FATAL1("Unknown message opcode %d", opcode); }
    }
  }
}

void Session::IterateChangesPointers(PointerVisitor* visitor) {
  for (PostponedChange* current = first_change_; current != NULL;
       current = current->next()) {
    current->IteratePointers(visitor);
  }
}

void Session::IteratePointers(PointerVisitor* visitor) {
  stack_.IteratePointers(visitor);
  IterateChangesPointers(visitor);
  for (int i = 0; i < maps_.length(); ++i) {
    ObjectMap* map = maps_[i];
    if (map != NULL) {
      // TODO(kasperl): Move the table clearing to a GC pre-phase.
      map->ClearTableByObject();
      map->IteratePointers(visitor);
    }
  }
}

int Session::ProcessRun() {
  bool process_started = false;
  bool has_result = false;
  int result = 0;
  ScopedMonitorLock scoped_lock(main_thread_monitor_);
  while (true) {
    MainThreadResumeKind resume_kind;
    while (main_thread_resume_kind_ == kUnknown) main_thread_monitor_->Wait();
    resume_kind = main_thread_resume_kind_;
    main_thread_resume_kind_ = kUnknown;
    main_thread_monitor_->NotifyAll();
    switch (resume_kind) {
      case kError:
        ASSERT(!debugging_);
        return kUncaughtExceptionExitCode;
      case kSnapshotDone:
        return 0;
      case kProcessRun:
        process_started = true;

        {
          SimpleProgramRunner runner;

          Program* programs[1] = { program_ };
          Process* processes[1] = { process_ };
          int exitcodes[1] = { -1 };

          execution_paused_ = false;
          ScopedMonitorUnlock scoped_unlock(main_thread_monitor_);
          runner.Run(1, exitcodes, programs, processes);

          result = exitcodes[0];
          ASSERT(result != -1);
        }

        has_result = true;
        if (!debugging_) return result;
        break;
      case kSessionEnd:
        ASSERT(!debugging_);
        if (!process_started && process_ != NULL) {
          // If the process was spawned but not started, the scheduler does not
          // know about it and we are therefore responsible for deleting it.
          process_->ChangeState(Process::kSleeping,
                                Process::kWaitingForChildren);
          program()->ScheduleProcessForDeletion(process_, Signal::kTerminated);
        }
        Print::UnregisterPrintInterceptors();
        if (!process_started) return 0;
        if (has_result) return result;
        break;
      case kUnknown:
        UNREACHABLE();
        break;
    }
  }
  return result;
}

bool Session::WriteSnapshot(const char* path,
                            FunctionOffsetsType* function_offsets,
                            ClassOffsetsType* class_offsets) {
  program()->set_entry(Function::cast(Pop()));
  program()->set_main_arity(Smi::cast(Pop())->value());
  // Make sure that the program is in the compact form before
  // snapshotting.
  if (!program()->is_optimized()) {
    ProgramFolder program_folder(program());
    program_folder.Fold();
  }

  SnapshotWriter writer(function_offsets, class_offsets);
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
  bool entry_exists;
  Object* object = maps_[map_index]->LookupById(id, &entry_exists);
  if (!entry_exists && !has_program_update_error_) {
    has_program_update_error_ = true;
    program_update_error_ =
        "Received PushFromMap command which referes to a "
        "non-existent map entry.";
  }
  Push(object);
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

void Session::PushNull() { Push(program()->null_object()); }

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

void Session::PushNewOneByteString(List<uint8> contents) {
  GC_AND_RETRY_ON_ALLOCATION_FAILURE(result,
                                     program()->CreateOneByteString(contents));
  Push(result);
}

void Session::PushNewTwoByteString(List<uint16> contents) {
  GC_AND_RETRY_ON_ALLOCATION_FAILURE(result,
                                     program()->CreateTwoByteString(contents));
  Push(result);
}

void Session::PushNewInstance() {
  GC_AND_RETRY_ON_ALLOCATION_FAILURE(
      result, program()->CreateInstance(Class::cast(Top())));
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
      case kInvokeStatic:
      case kInvokeFactory:
      case kLoadConst:
      case kAllocate:
      case kAllocateImmutable: {
        int literal_index = Utils::ReadInt32(bcp + 1);
        Object** literal_address = function->literal_address_for(literal_index);
        int offset = reinterpret_cast<uint8_t*>(literal_address) - bcp;
        Utils::WriteInt32(bcp + 1, offset);
        break;
      }
      case kMethodEnd:
        return;
      default:
        ASSERT(opcode < Bytecode::kNumBytecodes);
        break;
    }

    bcp += Bytecode::Size(opcode);
  }

  UNREACHABLE();
}

void Session::PushNewFunction(int arity, int literals, List<uint8> bytecodes) {
  ASSERT(!program()->is_optimized());

  GC_AND_RETRY_ON_ALLOCATION_FAILURE(
      result, program()->CreateFunction(arity, bytecodes, literals));
  Function* function = Function::cast(result);
  for (int i = literals - 1; i >= 0; --i) {
    function->set_literal_at(i, Pop());
  }
  RewriteLiteralIndicesToOffsets(function);
  Push(function);

  if (Flags::log_decoder) {
    uint8* bytes = function->bytecode_address_for(0);
    Print::Out("Method: %p\n", bytes);
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
      result, program()->CreateInitializer(Function::cast(Top())));
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
  } else if (name == Names::kTearOffClosure) {
    klass = program()->closure_class();
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
  } else if (name == Names::kConstantByteList) {
    klass = program()->constant_byte_list_class();
  } else if (name == Names::kConstantMap) {
    klass = program()->constant_map_class();
  } else if (name == Names::kNum) {
    klass = program()->num_class();
  } else if (name == Names::kOneByteString) {
    klass = program()->one_byte_string_class();
  } else if (name == Names::kTwoByteString) {
    klass = program()->two_byte_string_class();
  } else if (name == Names::kCoroutine) {
    klass = program()->coroutine_class();
  } else if (name == Names::kPort) {
    klass = program()->port_class();
  } else if (name == Names::kProcess) {
    klass = program()->process_class();
  } else if (name == Names::kProcessDeath) {
    klass = program()->process_death_class();
  } else if (name == Names::kForeignMemory) {
    klass = program()->foreign_memory_class();
  } else if (name == Names::kStackOverflowError) {
    klass = program()->stack_overflow_error_class();
  } else if (name == Names::kFletchNoSuchMethodError) {
    klass = program()->no_such_method_error_class();
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
      result, program()->CreateInstance(program()->constant_list_class()));
  Instance* list = Instance::cast(result);
  ASSERT(list->get_class()->NumberOfInstanceFields() == 1);
  list->SetInstanceField(0, Pop());
  Push(list);
}

void Session::PushConstantByteList(int length) {
  {
    GC_AND_RETRY_ON_ALLOCATION_FAILURE(result,
                                       program()->CreateByteArray(length));
    ByteArray* array = ByteArray::cast(result);
    for (int i = length - 1; i >= 0; i--) {
      array->set(i, Smi::cast(Pop())->value());
    }
    Push(array);
  }

  {
    GC_AND_RETRY_ON_ALLOCATION_FAILURE(
        result,
        program()->CreateInstance(program()->constant_byte_list_class()));
    Instance* list = Instance::cast(result);
    ASSERT(list->get_class()->NumberOfInstanceFields() == 1);
    list->SetInstanceField(0, Pop());
    Push(list);
  }
}

void Session::PushConstantMap(int length) {
  GC_AND_RETRY_ON_ALLOCATION_FAILURE(
      result, program()->CreateInstance(program()->constant_map_class()));
  Instance* map = Instance::cast(result);
  ASSERT(map->get_class()->NumberOfInstanceFields() == 2);
  // Values.
  map->SetInstanceField(1, Pop());
  // Keys.
  map->SetInstanceField(0, Pop());
  Push(map);
}

void Session::PrepareForChanges() {
  if (program()->is_optimized()) {
    ASSERT(execution_paused_);
    ProgramFolder program_folder(program());
    program_folder.Unfold();
    // Changes could include instance rewriting. Make sure to make the
    // shared heap consistent and clear the TableByObject mappings as
    // objects are moved during instance rewriting.
    program()->shared_heap()->MergeParts();
    for (int i = 0; i < maps_.length(); ++i) {
      ObjectMap* map = maps_[i];
      if (map != NULL) {
        map->ClearTableByObject();
      }
    }
  }
}

void Session::ChangeSuperClass() { PostponeChange(kChangeSuperClass, 2); }

void Session::CommitChangeSuperClass(PostponedChange* change) {
  Class* klass = Class::cast(change->get(1));
  Class* super = Class::cast(change->get(2));
  klass->set_super_class(super);
}

void Session::ChangeMethodTable(int length) {
  PushNewArray(length * 2);
  PostponeChange(kChangeMethodTable, 2);
}

void Session::CommitChangeMethodTable(PostponedChange* change) {
  Class* clazz = Class::cast(change->get(1));
  Array* methods = Array::cast(change->get(2));
  clazz->set_methods(methods);
}

void Session::ChangeMethodLiteral(int index) {
  Push(Smi::FromWord(index));
  PostponeChange(kChangeMethodLiteral, 3);
}

void Session::CommitChangeMethodLiteral(PostponedChange* change) {
  Function* function = Function::cast(change->get(1));
  Object* literal = change->get(2);
  int index = Smi::cast(change->get(3))->value();
  function->set_literal_at(index, literal);
}

void Session::ChangeStatics(int count) {
  PushNewArray(count);
  PostponeChange(kChangeStatics, 1);
}

void Session::CommitChangeStatics(PostponedChange* change) {
  program()->set_static_fields(Array::cast(change->get(1)));
}

void Session::ChangeSchemas(int count, int delta) {
  // Stack: <count> classes + transformation array
  Push(Smi::FromWord(delta));
  PostponeChange(kChangeSchemas, count + 2);
}

void Session::CommitChangeSchemas(PostponedChange* change) {
  // TODO(kasperl): Rework this so we can allow allocation failures
  // as part of allocating the new classes.
  SemiSpace* space = program()->heap()->space();
  NoAllocationFailureScope scope(space);

  int length = change->size();
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
  ASSERT(execution_paused_);
  ASSERT(!program()->is_optimized());

  if (count != PostponedChange::number_of_changes()) {
    if (!has_program_update_error_) {
      has_program_update_error_ = true;
      program_update_error_ =
          "The CommitChanges command had a different count of changes than "
          "the buffered changes.";
    }
    DiscardChanges();
  }

  if (!has_program_update_error_) {
    // TODO(kustermann): Sanity check all changes the compiler gave us.
    // If we are unable to apply a change, we should continue the program
    // and "return false".

    bool schemas_changed = false;
    for (PostponedChange* current = first_change_; current != NULL;
         current = current->next()) {
      Change change = static_cast<Change>(Smi::cast(current->get(0))->value());
      switch (change) {
        case kChangeSuperClass:
          ASSERT(!schemas_changed);
          CommitChangeSuperClass(current);
          break;
        case kChangeMethodTable:
          ASSERT(!schemas_changed);
          CommitChangeMethodTable(current);
          break;
        case kChangeMethodLiteral:
          CommitChangeMethodLiteral(current);
          break;
        case kChangeStatics:
          CommitChangeStatics(current);
          break;
        case kChangeSchemas:
          CommitChangeSchemas(current);
          schemas_changed = true;
          break;
        default:
          UNREACHABLE();
          break;
      }
    }

    DiscardChanges();

    if (schemas_changed) TransformInstances();

    // Fold the program after applying changes to continue running in the
    // optimized compact form.
    {
      ProgramFolder program_folder(program());
      program_folder.Fold();
    }
  }

  return !has_program_update_error_;
}

void Session::DiscardChanges() {
  PostponedChange* current = first_change_;
  while (current != NULL) {
    PostponedChange* next = current->next();
    delete current;
    current = next;
  }
  first_change_ = last_change_ = NULL;
  ASSERT(PostponedChange::number_of_changes() == 0);
}

void Session::PostponeChange(Change change, int count) {
  Object** description = new Object*[count + 1];
  description[0] = Smi::FromWord(change);
  for (int i = count; i >= 1; i--) {
    description[i] = Pop();
  }
  PostponedChange* postponed_change =
      new PostponedChange(description, count + 1);
  if (last_change_ != NULL) {
    last_change_->set_next(postponed_change);
    last_change_ = postponed_change;
  } else {
    last_change_ = first_change_ = postponed_change;
  }
}

bool Session::UncaughtException(Process* process) {
  if (process_ == process) {
    RequestExecutionPause();
    WriteBuffer buffer;
    connection_->Send(Connection::kUncaughtException, buffer);
    return true;
  }
  return false;
}

bool Session::Killed(Process* process) {
  if (process_ != process) return false;

  // TODO(kustermann): We might want to let a debugger know that the process
  // didn't normally terminate, but rather was killed.
  WriteBuffer buffer;
  connection_->Send(Connection::kProcessTerminated, buffer);
  process_ = NULL;
  program_->scheduler()->ExitAtTermination(process, Signal::kKilled);
  return true;
}

bool Session::UncaughtSignal(Process* process) {
  if (process_ != process) return false;

  // TODO(kustermann): We might want to let a debugger know that the process
  // didn't normally terminate, but rather was killed due to a linked process.
  WriteBuffer buffer;
  connection_->Send(Connection::kProcessTerminated, buffer);
  process_ = NULL;
  program_->scheduler()->ExitAtTermination(process, Signal::kUnhandledSignal);
  return true;
}

bool Session::BreakPoint(Process* process) {
  if (process_ == process) {
    RequestExecutionPause();
    DebugInfo* debug_info = process->debug_info();
    int breakpoint_id = -1;
    if (debug_info != NULL) {
      debug_info->ClearStepping();
      breakpoint_id = debug_info->current_breakpoint_id();
    }
    WriteBuffer buffer;
    buffer.WriteInt(breakpoint_id);
    PushTopStackFrame(process->stack());
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

Process* Session::GetProcess(int process_id) {
  // TODO(zerny): Assert here and eliminate the default process.
  if (process_id < 0) return process_;
  for (Process* process = program()->process_list_head();
       process != NULL;
       process = process->process_list_next()) {
    process->EnsureDebuggerAttached(this);
    if (process->debug_info()->process_id() == process_id) {
      return process;
    }
  }
  UNREACHABLE();
  return NULL;
}

bool Session::ProcessTerminated(Process* process) {
  if (process_ == process) {
    WriteBuffer buffer;
    connection_->Send(Connection::kProcessTerminated, buffer);
    process_ = NULL;
    program_->scheduler()->ExitAtTermination(process, Signal::kTerminated);
    return true;
  }
  return false;
}

bool Session::CompileTimeError(Process* process) {
  if (process_ == process) {
    RequestExecutionPause();
    WriteBuffer buffer;
    connection_->Send(Connection::kProcessCompileTimeError, buffer);
    return true;
  }
  return false;
}

class TransformInstancesPointerVisitor : public PointerVisitor {
 public:
  explicit TransformInstancesPointerVisitor(Heap* heap, SharedHeap* shared_heap)
      : heap_(heap), shared_heap_(shared_heap->heap()) {}

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
      if (heap_object->HasForwardingAddress()) {
        *p = heap_object->forwarding_address();
      } else if (heap_object->IsInstance()) {
        Instance* instance = Instance::cast(heap_object);
        if (instance->get_class()->IsTransformed()) {
          Instance* clone;

          if (heap_->space()->Includes(instance->address())) {
            clone = instance->CloneTransformed(heap_);
          } else {
            ASSERT(shared_heap_->space()->Includes(instance->address()));
            clone = instance->CloneTransformed(shared_heap_);
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
  Heap* const shared_heap_;
};

class RebuildVisitor : public ProcessVisitor {
 public:
  explicit RebuildVisitor(SharedHeap* shared_heap)
      : shared_heap_(shared_heap) {}

  virtual void VisitProcess(Process* process) {
    process->heap()->space()->RebuildAfterTransformations();
    shared_heap_->heap()->space()->RebuildAfterTransformations();
    process->heap()->old_space()->RebuildAfterTransformations();
  }

 private:
  SharedHeap* shared_heap_;
};

class TransformInstancesProcessVisitor : public ProcessVisitor {
 public:
  explicit TransformInstancesProcessVisitor(SharedHeap* shared_heap)
      : shared_heap_(shared_heap) {}

  virtual void VisitProcess(Process* process) {
    Heap* heap = process->heap();

    SemiSpace* space = heap->space();
    SemiSpace* immutable_space = shared_heap_->heap()->space();

    NoAllocationFailureScope scope(space);
    NoAllocationFailureScope scope2(immutable_space);

    TransformInstancesPointerVisitor pointer_visitor(heap, shared_heap_);

    process->IterateRoots(&pointer_visitor);

    ASSERT(!space->is_empty());
    space->CompleteTransformations(&pointer_visitor);
    immutable_space->CompleteTransformations(&pointer_visitor);
  }

 private:
  SharedHeap* shared_heap_;
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

  SemiSpace* space = program()->heap()->space();
  NoAllocationFailureScope scope(space);
  TransformInstancesPointerVisitor pointer_visitor(program()->heap(),
                                                   program()->shared_heap());
  program()->IterateRoots(&pointer_visitor);
  ASSERT(!space->is_empty());
  space->CompleteTransformations(&pointer_visitor);

  TransformInstancesProcessVisitor process_visitor(program()->shared_heap());
  program()->VisitProcesses(&process_visitor);

  space->RebuildAfterTransformations();
  RebuildVisitor rebuilding_visitor(program()->shared_heap());
  program()->VisitProcesses(&rebuilding_visitor);
}

void Session::PushFrameOnSessionStack(const Frame* frame) {
  Function* function = frame->FunctionFromByteCodePointer();
  uint8* start_bcp = function->bytecode_address_for(0);

  uint8* bcp = frame->ByteCodePointer();
  int bytecode_offset = bcp - start_bcp;
  // The byte-code offset is not a return address but the offset for
  // the invoke bytecode. Make it look like a return address by adding
  // the current bytecode size to the byte-code offset.
  Opcode current = static_cast<Opcode>(*bcp);
  bytecode_offset += Bytecode::Size(current);

  PushNewInteger(bytecode_offset);
  PushFunction(function);
}

int Session::PushStackFrames(Stack* stack) {
  int frames = 0;
  Frame frame(stack);
  while (frame.MovePrevious()) {
    if (frame.ByteCodePointer() == NULL) continue;
    PushFrameOnSessionStack(&frame);
    ++frames;
  }
  return frames;
}

void Session::PushTopStackFrame(Stack* stack) {
  Frame frame(stack);
  bool has_top_frame = frame.MovePrevious();
  ASSERT(has_top_frame);
  PushFrameOnSessionStack(&frame);
}

void Session::RestartFrame(int frame_index) {
  Stack* stack = process_->stack();

  // Move down to the frame we want to reset to.
  Frame frame(stack);
  for (int i = 0; i <= frame_index; i++) frame.MovePrevious();

  // Reset the return address to the entry function.
  frame.SetReturnAddress(reinterpret_cast<void*>(InterpreterEntry));

  // Finally resize the stack to the next frame pointer.
  stack->SetTopFromPointer(frame.FramePointer());
}

}  // namespace fletch

#endif  // FLETCH_ENABLE_LIVE_CODING
