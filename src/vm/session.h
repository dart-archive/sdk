// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_VM_SESSION_H_
#define SRC_VM_SESSION_H_

#include "src/shared/names.h"

#include "src/vm/object_list.h"
#include "src/vm/program.h"

namespace fletch {

class Connection;
class ObjectMap;
class PointerVisitor;

class Session {
 public:
  explicit Session(Connection* connection);
  virtual ~Session();

  Program* program() const { return program_; }

  bool is_debugging() const { return debugging_; }

  void Initialize();
  void Reinitialize();
  void StartMessageProcessingThread();
  void ProcessMessages();

  void IteratePointers(PointerVisitor* visitor);
  void VisitProcesses(ProcessVisitor* visitor);

  // High-level operations.
  bool ProcessRun();
  bool WriteSnapshot(const char* path);
  void CollectGarbage();

  // Map operations.
  void NewMap(int index);
  void DeleteMap(int index);

  void PushFromMap(int index, int64 id);
  void PopToMap(int index, int64 id);
  void RemoveFromMap(int index, int64 id);

  // Get the id for the top object on the session stack in the object
  // map with the given index. Returns -1 if the object does not exist
  // in the map.
  int64 MapLookup(int map_index);

  // Stack operations.
  void Dup() { Push(Top()); }
  void Drop(int n) { stack_.DropLast(n); }

  void PushNull();
  void PushBoolean(bool value);
  void PushNewInteger(int64 value);
  void PushNewDouble(double value);
  void PushNewString(List<uint16> contents);

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

  void UncaughtException();

  void BreakPoint(Process* process);

  void ProcessTerminated(Process* process);

 private:
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
    kSessionEnd,
    kSessionReset
  };

  Connection* const connection_;
  Program* program_;

  // TODO(ager): For debugging, the session should have a mapping from
  // ids to processes. For now we just keep a reference to the main
  // process (with implicit id 0).
  Process* process_;

  bool debugging_;
  bool output_synchronization_;

  int method_map_id_;
  int class_map_id_;

  ObjectList stack_;
  ObjectList changes_;
  List<ObjectMap*> maps_;

  Monitor* main_thread_monitor_;
  MainThreadResumeKind main_thread_resume_kind_;
  bool main_thread_done_;

  void SignalMainThread(MainThreadResumeKind);
  void SignalMainThreadWaitUntilDone(MainThreadResumeKind);
  void MainThreadDone();

  void SendDartValue(Object* value);
  void SendInstanceStructure(Instance* instance);

  void Push(Object* object) { stack_.Add(object); }
  Object* Pop() { return stack_.RemoveLast(); }
  Object* Top() const { return stack_.Last(); }
  int64_t PopInteger();

  void PostponeChange(Change change, int count);

  void CommitChangeSuperClass(Array* change);
  void CommitChangeMethodTable(Array* change);
  void CommitChangeMethodLiteral(Array* change);
  void CommitChangeStatics(Array* change);
  void CommitChangeSchemas(Array* change);

  void TransformInstances();

  void PrintSynchronizationToken();
};

}  // namespace fletch

#endif  // SRC_VM_SESSION_H_
