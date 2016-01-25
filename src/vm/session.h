// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SESSION_H_
#define SRC_VM_SESSION_H_

#ifndef FLETCH_ENABLE_LIVE_CODING
#include "src/vm/session_no_live_coding.h"
#else  // FLETCH_ENABLE_LIVE_CODING

#include "src/shared/names.h"

#include "src/vm/object_list.h"
#include "src/vm/program.h"
#include "src/vm/snapshot.h"
#include "src/vm/thread.h"

namespace fletch {

class Connection;
class Frame;
class ObjectMap;
class PointerVisitor;
class PostponedChange;

class Session {
 public:
  explicit Session(Connection* connection);
  virtual ~Session();

  Program* program() const { return program_; }

  bool is_debugging() const { return debugging_; }

  int FreshProcessId() { return next_process_id_++; }

  void Initialize();
  void StartMessageProcessingThread();
  void JoinMessageProcessingThread();
  void ProcessMessages();

  void IteratePointers(PointerVisitor* visitor);

  // High-level operations.
  int ProcessRun();
  bool WriteSnapshot(const char* path, FunctionOffsetsType* function_offsets,
                     ClassOffsetsType* class_offsets);

  // These functions return `true` if the session knows about [process] and was
  // able to take action on the event.
  // In case the session does not know about [process] these functions will
  // return `false` and the caller is responsible for handling the event.
  bool UncaughtException(Process* process);
  bool Killed(Process* process);
  bool UncaughtSignal(Process* process);
  bool BreakPoint(Process* process);
  bool ProcessTerminated(Process* process);
  bool CompileTimeError(Process* process);

 private:
  // Map operations.
  void NewMap(int map_index);
  void DeleteMap(int map_index);

  void PushFromMap(int map_index, int64 id);
  void PopToMap(int map_index, int64 id);
  void RemoveFromMap(int map_index, int64 id);

  // Get the id for the object in the map with the given
  // index. Returns -1 if the object does not exist in the map.
  int64 MapLookupByObject(int map_index, Object* object);

  // Get the object for the id in the map with the given
  // index. Returns NULL if the id does not exist in the map.
  Object* MapLookupById(int map_index, int64 id);

  // Stack operations.
  void Dup() { Push(Top()); }
  void Drop(int n) { stack_.DropLast(n); }

  void PushNull();
  void PushBoolean(bool value);
  void PushNewInteger(int64 value);
  void PushNewDouble(double value);
  void PushNewOneByteString(List<uint8> contents);
  void PushNewTwoByteString(List<uint16> contents);

  // Stack: class, field<n-1>, ..., field<0>, ...
  //     -> new instance, ...
  void PushNewInstance();

  // Stack: entry<n-1>, ..., entry<0>, ...
  //     -> new array, ...
  void PushNewArray(int length);

  // Stack: literal<n-1>, ..., literal<0>, ...
  //     -> new function
  void PushNewFunction(int arity, int literals, List<uint8> bytecodes);

  // Stack: function -> new initializer
  void PushNewInitializer();

  void PushNewClass(int fields);
  void PushBuiltinClass(Names::Id name, int fields);

  void PushConstantList(int length);
  void PushConstantByteList(int length);
  void PushConstantMap(int length);

  void PushFunction(Function* function) { Push(function); }

  // These methods supports building up a list of changes and
  // committing (or discarding) them in one atomic operation.
  void ChangeSuperClass();
  void ChangeMethodTable(int length);
  void ChangeMethodLiteral(int index);
  void ChangeStatics(int count);
  void ChangeSchemas(int count, int delta);

  void PrepareForChanges();
  bool CommitChanges(int count);
  void DiscardChanges();

  enum Change {
    kChangeSuperClass,
    kChangeMethodTable,
    kChangeMethodLiteral,
    kChangeStatics,
    kChangeSchemas
  };

  enum MainThreadResumeKind {
    kUnknown,
    kProcessRun,
    kError,
    kSnapshotDone,
    kSessionEnd
  };

  ThreadIdentifier message_handling_thread_;

  Connection* const connection_;
  Program* program_;

  // TODO(ager): For debugging, the session should have a mapping from
  // ids to processes. For now we just keep a reference to the main
  // process (with implicit id 0).
  Process* process_;
  int next_process_id_;

  // When true execution_paused_ implies that the program is not
  // running in the scheduler. Either it has not yet been scheduled
  // (in which case program()->scheduler() == NULL) or the program
  // is stopped and the GC thread is paused.
  bool execution_paused_;
  bool request_execution_pause_;

  bool debugging_;

  int method_map_id_;
  int class_map_id_;
  int fibers_map_id_;

  ObjectList stack_;
  PostponedChange* first_change_;
  PostponedChange* last_change_;
  List<ObjectMap*> maps_;
  bool has_program_update_error_;
  const char* program_update_error_;

  Monitor* main_thread_monitor_;
  MainThreadResumeKind main_thread_resume_kind_;

  void IterateChangesPointers(PointerVisitor* visitor);

  void HandShake();

  void AddToMap(int map_index, int64 id, Object* value);

  void SignalMainThread(MainThreadResumeKind);

  void RequestExecutionPause();
  void PauseExecution();
  void ResumeExecution();
  void ProcessContinue(Process* process);

  bool IsScheduledAndPaused() const {
    return execution_paused_ && program()->scheduler() != NULL;
  }

  void SendStackTrace(Stack* stack);
  void SendDartValue(Object* value);
  void SendInstanceStructure(Instance* instance);
  void SendSnapshotResult(ClassOffsetsType* class_offsets,
                          FunctionOffsetsType* function_offsets);

  void Push(Object* object) { stack_.Add(object); }
  Object* Pop() { return stack_.RemoveLast(); }
  Object* Top() const { return stack_.Last(); }
  int64_t PopInteger();

  void PostponeChange(Change change, int count);

  void CommitChangeSuperClass(PostponedChange* change);
  void CommitChangeMethodTable(PostponedChange* change);
  void CommitChangeMethodLiteral(PostponedChange* change);
  void CommitChangeStatics(PostponedChange* change);
  void CommitChangeSchemas(PostponedChange* change);

  // This will leave process and program heaps with old and new objects behind.
  // Where the old objects will have a forwarding pointer installed. It is
  // therefore not safe to traverse heap objects after calling this method.
  void TransformInstances();

  void PushFrameOnSessionStack(const Frame* frame);

  // Compute a stack trace and push it on the session stack.
  int PushStackFrames(Stack* stack);

  // Compute the function for the top frame on the stack
  // and push it on the session stack.
  void PushTopStackFrame(Stack* stack);

  void RestartFrame(int index);

  Process* GetProcess(int process_id);
};

}  // namespace fletch

#endif  // FLETCH_ENABLE_LIVE_CODING

#endif  // SRC_VM_SESSION_H_
