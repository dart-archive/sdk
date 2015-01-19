// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_EMITTER_H_
#define SRC_COMPILER_EMITTER_H_

#include "src/shared/bytecodes.h"
#include "src/shared/natives.h"
#include "src/compiler/list_builder.h"
#include "src/compiler/scope.h"
#include "src/compiler/zone.h"

namespace fletch {

enum IdType {
  kMethodId = 0,
  kClassId = 1,
  kConstantId = 2
};

class Label : public StackAllocated {
 public:
  Label() : position_(-1) { }

  bool is_bound() const { return position_ >= 0; }
  int position() const { return position_; }
  int uses() const { return -position_ - 1; }

  int UseAt(int n) const;

  void Bind(int position);
  void Use(int position);

 private:
  int position_;
  int uses_[8];
};

class Code : public ZoneAllocated {
 public:
  Code(int arity, List<uint8> bytes, List<int> ids)
      : arity_(arity)
      , bytes_(bytes)
      , ids_(ids) { }

  int arity() const { return arity_; }
  List<uint8> bytes() const { return bytes_; }
  List<int> ids() const { return ids_; }

 private:
  const int arity_;
  const List<uint8> bytes_;
  const List<int> ids_;
};

class Emitter : public StackAllocated {
 public:
  Emitter(Zone* zone, int arity);

  Zone* zone() const { return zone_; }

  Code* GetCode();

  void LoadThis();
  void LoadParameter(int index);
  void LoadLocal(int index);
  void LoadStackLocal(int index);
  void LoadBoxed(int index);
  void LoadStatic(int id);
  void LoadStaticInit(int id);
  void LoadField(int field);
  void LoadConst(int id);

  void StoreParameter(int index);
  void StoreLocal(int index);
  void StoreStackLocal(int index);
  void StoreBoxed(int index);
  void StoreStatic(int id);
  void StoreField(int field);

  void LoadInteger(int value);

  void InvokeMethod(IdentifierNode* name, int arity);
  void InvokeMethod(int id, int arity);
  void InvokeGetter(IdentifierNode* name);
  void InvokeSetter(IdentifierNode* name);

  void InvokeStatic(int arity, int id);
  void InvokeFactory(int arity, int id);

  void InvokeNative(int arity, Native native);
  void InvokeNativeYield(int arity, Native native);

  void InvokeTest(IdentifierNode* name);

  void Bind(Label* label);
  void BindRaw(Label* label);
  void Branch(Label* label);
  void BranchIfTrue(Label* label);
  void BranchIfFalse(Label* label);

  void Pop();
  void Return();
  void Dup();

  void Allocate(int id, int fields);
  void AllocateBoxed();

  void Negate();

  void Throw();
  void SubroutineCall(Label* label, Label* return_label);
  void SubroutineReturn(Label* return_label);

  void ProcessYield();
  void CoroutineChange();
  void Identical();

  void EnterNoSuchMethod();
  void ExitNoSuchMethod();

  void FrameSize();

  bool EndsWithReturn();

  int position() const { return bytes_.length(); }
  void AddFrameRange(int start, int end);

  void FrameSizeFix(int delta) {
    StackSizeChange(delta);
  }

  int frame_size() const { return stack_size_; }
  int arity() const { return arity_; }

 private:
  struct FrameRange {
    int start;
    int end;
  };

  Zone* const zone_;
  const int arity_;

  ListBuilder<uint8, 256> bytes_;

  IdMap<int> literal_map_;
  ListBuilder<int, 16> literals_;

  Scope scope_;
  int stack_size_;
  int max_stack_size_;
  Opcode last_opcode_;
  ListBuilder<FrameRange, 2> ranges_;

  void MethodEnd(int delta);

  void EmitOpcode(Opcode opcode);
  void EmitBranch(Opcode opcode, Label* label);
  void EmitInt32(int value);
  void StackSizeChange(int delta);
  void EmitLiteral(int id, IdType type);
};

}  // namespace fletch

#endif  // SRC_COMPILER_EMITTER_H_
