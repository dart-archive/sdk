// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/vm/session.h"

#include "src/shared/bytecodes.h"
#include "src/shared/connection.h"
#include "src/shared/flags.h"

#include "src/vm/object_map.h"
#include "src/vm/platform.h"
#include "src/vm/process.h"
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

Session::Session(Connection* connection)
    : connection_(connection),
      program_(NULL),
      process_(NULL),
      debugging_(false),
      stack_(0),
      changes_(0),
      main_thread_monitor_(Platform::CreateMonitor()),
      main_thread_resume_kind_(kUnknown) {
}

Session::~Session() {
  delete connection_;
  delete program_->scheduler();
  delete program_;
  delete main_thread_monitor_;
  for (int i = 0; i < maps_.length(); ++i) delete maps_[i];
  maps_.Delete();
}

void Session::Initialize() {
  program_ = new Program();

  Scheduler* scheduler = new Scheduler();
  scheduler->ScheduleProgram(program_);

  program()->Initialize();
  program()->AddSession(this);
}

static void* MessageProcessingThread(void* data) {
  Session* session = reinterpret_cast<Session*>(data);
  session->ProcessMessages();
  return NULL;
}

void Session::StartMessageProcessingThread() {
  Thread::Run(MessageProcessingThread, this);
}

void Session::SignalMainThread(MainThreadResumeKind kind) {
  main_thread_monitor_->Lock();
  main_thread_resume_kind_ = kind;
  main_thread_monitor_->Notify();
  main_thread_monitor_->Unlock();
}

void Session::ProcessMessages() {
  while (true) {
    Connection::Opcode opcode = connection_->Receive();

    switch (opcode) {
      case Connection::kConnectionError: {
        FATAL("Compiler crashed. So do we.");
      }

      case Connection::kCompilerError: {
        SignalMainThread(kError);
        return;
      }

      case Connection::kProcessSpawnForMain: {
        // Setup entry point for main thread.
        program()->set_entry(Function::cast(Pop()));
        program()->set_main_arity(Smi::cast(Pop())->value());
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
        if (process_->debug_info() == NULL) {
          process_->AttachDebugger();
        }
        int bytecode_index = connection_->ReadInt();
        Function* function = Function::cast(Pop());
        DebugInfo* debug_info = process_->debug_info();
        int id = debug_info->SetBreakpoint(function, bytecode_index);
        connection_->WriteInt(id);
        connection_->Send(Connection::kProcessSetBreakpoint);
        break;
      }

      case Connection::kProcessDeleteBreakpoint: {
        ASSERT(process_->debug_info() != NULL);
        int id = connection_->ReadInt();
        bool deleted = process_->debug_info()->DeleteBreakpoint(id);
        ASSERT(deleted);
        connection_->WriteInt(id);
        connection_->Send(Connection::kProcessDeleteBreakpoint);
        break;
      }

      case Connection::kProcessStep: {
        Scheduler* scheduler = program()->scheduler();
        process_->debug_info()->set_is_stepping(true);
        scheduler->ProcessContinue(process_);
        break;
      }

      case Connection::kProcessStepOver: {
        Scheduler* scheduler = program()->scheduler();
        process_->PrepareStepOver();
        scheduler->ProcessContinue(process_);
        break;
      }

      case Connection::kProcessContinue: {
        Scheduler* scheduler = program()->scheduler();
        scheduler->ProcessContinue(process_);
        break;
      }

      case Connection::kProcessBacktrace: {
        connection_->ReadInt();
        int frames = StackWalker::ComputeStackTrace(process_, this);
        connection_->WriteInt(frames);
        connection_->Send(Connection::kProcessBacktrace);
        break;
      }

      case Connection::kSessionEnd: {
        return;
      }

      case Connection::kForceTermination: {
        exit(1);
      }

      case Connection::kDebugging: {
        debugging_ = true;
        break;
      }

      case Connection::kWriteSnapshot: {
        int length;
        const uint8* data = connection_->ReadBytes(&length);
        const char* path = reinterpret_cast<const char*>(data);
        ASSERT(static_cast<int>(strlen(path)) == length - 1);
        bool success = WriteSnapshot(path);
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
        List<uint8> contents(bytes, length);
        PushNewString(List<const char>(contents));
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

      case Connection::kCommitChanges: {
        CommitChanges(connection_->ReadInt());
        break;
      }

      case Connection::kDiscardChanges: {
        DiscardChanges();
        break;
      }

      case Connection::kMapLookup: {
        int map_index = connection_->ReadInt();
        int id = MapLookup(map_index);
        connection_->WriteInt(id);
        connection_->Send(Connection::kObjectId);
        break;
      }

      case Connection::kPopInteger: {
        Object* top = Pop();
        int64 value = 0;
        if (top->IsLargeInteger()) {
          value = LargeInteger::cast(top)->value();
        } else {
          value = Smi::cast(top)->value();
        }
        connection_->WriteInt64(value);
        connection_->Send(Connection::kInteger);
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
  main_thread_monitor_->Lock();
  while (main_thread_resume_kind_ == kUnknown) main_thread_monitor_->Wait();
  main_thread_monitor_->Unlock();
  switch (main_thread_resume_kind_) {
    case kError:
      return false;
    case kSnapshotDone:
      return true;
    case kProcessRun:
      return program()->ProcessRun(process_);
    case kUnknown:
      UNREACHABLE();
      break;
  }
  return false;
}

bool Session::WriteSnapshot(const char* path) {
  program()->set_entry(Function::cast(Pop()));
  program()->set_main_arity(Smi::cast(Pop())->value());
  SnapshotWriter writer;
  List<uint8> snapshot = writer.WriteProgram(program());
  bool success = Platform::StoreFile(path, snapshot);
  snapshot.Delete();
  return success;
}

void Session::NewMap(int index) {
  int length = maps_.length();
  if (index >= length) {
    maps_.Reallocate(index + 1);
    for (int i = length; i <= index; i++) {
      maps_[i] = NULL;
    }
  }
  ObjectMap* existing = maps_[index];
  if (existing != NULL) delete existing;
  maps_[index] = new ObjectMap(64);
}

void Session::DeleteMap(int index) {
  ObjectMap* map = maps_[index];
  if (map == NULL) return;
  delete map;
  maps_[index] = NULL;
}

void Session::PushFromMap(int index, int64 id) {
  Push(maps_[index]->LookupById(id));
}

void Session::PopToMap(int index, int64 id) {
  maps_[index]->Add(id, Pop());
}

int64 Session::MapLookup(int map_index) {
  int64 id = -1;
  ObjectMap* map = maps_[map_index];
  if (map != NULL) id = map->LookupByObject(Top());
  return id;
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

void Session::PushNewString(List<const char> contents) {
  // TODO(ager): Decide on the format the compiler generates. For now assume
  // ascii strings.
  GC_AND_RETRY_ON_ALLOCATION_FAILURE(
      result,
      program()->CreateStringFromAscii(contents));
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
      case kAllocateUnfold: {
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
    printf("Method:\n");
    uint8* bytes = function->bytecode_address_for(0);
    Opcode opcode;
    int i = 0;
    do {
      opcode = static_cast<Opcode>(bytes[i]);
      printf("  %04d: ", i);
      i += Bytecode::Print(bytes + i);
      printf("\n");
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
  } else if (name == Names::kForeign) {
    klass = program()->foreign_class();
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

void Session::CommitChanges(int count) {
  Scheduler* scheduler = program()->scheduler();
  if (!scheduler->StopProgram(program())) {
    FATAL("Failed to stop program, for committing changes\n");
  }

  ASSERT(count == changes_.length());
  for (int i = 0; i < count; i++) {
    Array* array = Array::cast(changes_[i]);
    Change change = static_cast<Change>(Smi::cast(array->get(0))->value());
    switch (change) {
      case kChangeSuperClass:
        CommitChangeSuperClass(array);
        break;
      case kChangeMethodTable:
        CommitChangeMethodTable(array);
        break;
      case kChangeMethodLiteral:
        CommitChangeMethodLiteral(array);
        break;
      case kChangeStatics:
        CommitChangeStatics(array);
        break;
      default:
        UNREACHABLE();
        break;
    }
  }
  changes_.Clear();

  scheduler->ResumeProgram(program());
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

void Session::UncaughtException() {
  // TODO(ager): This is not thread safe. UncaughtException is called
  // from the interpreter on a thread from the thread pool and it is
  // writing on the connection.  We need a real event loop for the
  // message handling and we need to enqueue a message for the event
  // loop here.
  connection_->Send(Connection::kUncaughtException);
}

void Session::BreakPoint(Process* process) {
  process->debug_info()->set_is_stepping(false);
  connection_->Send(Connection::kProcessBreakpoint);
}

void Session::ProcessTerminated(Process* process) {
  if (process_ == process) {
    connection_->Send(Connection::kProcessTerminated);
    process_ = NULL;
  }
}

}  // namespace fletch
