// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_SESSION_H_
#define SRC_COMPILER_SESSION_H_

#include "src/compiler/list.h"
#include "src/shared/names.h"

namespace fletch {

class Compiler;
class Connection;
class LibraryElement;

class Session {
 public:
  explicit Session(Connection* connection);
  virtual ~Session();

  // Build the program and leave the entry function at the
  // top of the stack, so the session is ready for writing
  // a snapshot or running the program.
  void BuildProgram(Compiler* compiler, LibraryElement* root);

  // High-level operations.
  void ProcessRun();
  void WriteSnapshot(const char* path);
  void CollectGarbage();

  // Map operations.
  void NewMap(int index);
  void DeleteMap(int index);

  void PushFromMap(int index, int64 id);
  void PopToMap(int index, int64 id);

  // Stack operations.
  void Dup();

  void PushNull();
  void PushBoolean(bool value);
  void PushNewInteger(int64 value);
  void PushNewDouble(double value);
  void PushNewString(List<const char> contents);

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

  void PushNewName(const char* name);

  // These methods supports building up a list of changes and
  // committing (or discarding) them in one atomic operation.
  void ChangeSuperClass();
  void ChangeMethodTable(int length);
  void ChangeMethodLiteral(int index);
  void ChangeStatics(int count);

  void CommitChanges(int count);
  void DiscardChanges();

 private:
  Connection* const connection_;
};

}  // namespace fletch

#endif  // SRC_COMPILER_SESSION_H_
