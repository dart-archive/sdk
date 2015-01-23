// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/compiler/emitter.h"

#include "src/compiler/const_interpreter.h"
#include "src/shared/assert.h"
#include "src/shared/names.h"
#include "src/shared/selectors.h"

namespace fletch {

int Label::UseAt(int n) const {
  ASSERT(n >= 0 && n < uses());
  return uses_[n];
}

void Label::Bind(int position) {
  ASSERT(!is_bound());
  position_ = position;
  ASSERT(is_bound());
}

void Label::Use(int position) {
  ASSERT(!is_bound());
  unsigned index = uses();
  if (index < ARRAY_SIZE(uses_)) {
    uses_[index] = position;
    position_--;
  } else {
    UNIMPLEMENTED();
  }
}

Emitter::Emitter(Zone* zone, int arity)
    : zone_(zone)
    , arity_(arity)
    , bytes_(zone)
    , literal_map_(zone, 8)
    , literals_(zone)
    , scope_(zone, 8, NULL)
    , stack_size_(0)
    , max_stack_size_(0)
    , last_opcode_(static_cast<Opcode>(-1))
    , ranges_(zone) {
  // Always start with a kStackOverflowCheck.
  EmitOpcode(kStackOverflowCheck);
  EmitInt32(0);
}

Code* Emitter::GetCode() {
  ASSERT(last_opcode_ != kMethodEnd);
  if (max_stack_size_ > Bytecode::kGuaranteedFrameSize) {
    int delta = max_stack_size_ - Bytecode::kGuaranteedFrameSize;
    bytes_.Set(1, (delta >>  0) & 0xFF);
    bytes_.Set(2, (delta >>  8) & 0xFF);
    bytes_.Set(3, (delta >> 16) & 0xFF);
    bytes_.Set(4, (delta >> 24) & 0xFF);
    MethodEnd(0);
    return new(zone()) Code(arity(), bytes_.ToList(), literals_.ToList());
  }
  MethodEnd(-5);
  // Skip the kStackOverflowCheck bytecode.
  List<uint8> bytes = bytes_.ToList();
  List<uint8> sublist(bytes.data() + 5, bytes.length() - 5);
  return new(zone()) Code(arity(), sublist, literals_.ToList());
}

void Emitter::LoadThis() {
  LoadParameter(0);
}

void Emitter::LoadInteger(int value) {
  if (value < 0) UNIMPLEMENTED();
  if (value == 0) {
    EmitOpcode(kLoadLiteral0);
  } else if (value == 1) {
    EmitOpcode(kLoadLiteral1);
  } else if (value <= 0xFF) {
    EmitOpcode(kLoadLiteral);
    bytes_.Add(value);
  } else {
    EmitOpcode(kLoadLiteralWide);
    for (int i = 0; i < 4; i++) {
      int part = 0xFF & (value >> (i << 3));
      bytes_.Add(part);
    }
  }
  StackSizeChange(1);
}

void Emitter::LoadParameter(int index) {
  ASSERT(index >= 0);
  LoadStackLocal(frame_size() + 1 + arity() - index - 1);
}

void Emitter::LoadLocal(int index) {
  ASSERT(index >= 0);
  LoadStackLocal(frame_size() - index - 1);
}

void Emitter::LoadStackLocal(int index) {
  ASSERT(index >= 0);
  if (index == 0) {
    EmitOpcode(kLoadLocal0);
  } else if (index == 1) {
    EmitOpcode(kLoadLocal1);
  } else if (index == 2) {
    EmitOpcode(kLoadLocal2);
  } else {
    EmitOpcode(kLoadLocal);
    if (index > 0xFF) UNIMPLEMENTED();
    bytes_.Add(index);
  }
  StackSizeChange(1);
}

void Emitter::LoadBoxed(int index) {
  ASSERT(index >= 0);
  EmitOpcode(kLoadBoxed);
  if (index > 0xFF) UNIMPLEMENTED();
  bytes_.Add(frame_size() - index - 1);
  StackSizeChange(1);
}

void Emitter::LoadStatic(int id) {
  EmitOpcode(kLoadStatic);
  EmitInt32(id);
  StackSizeChange(1);
}

void Emitter::LoadStaticInit(int id) {
  EmitOpcode(kLoadStaticInit);
  EmitInt32(id);
  StackSizeChange(1);
}

void Emitter::LoadField(int field) {
  EmitOpcode(kLoadField);
  if (field > 0xFF) UNIMPLEMENTED();
  bytes_.Add(field);
}

void Emitter::LoadConst(int id) {
  switch (id) {
    case ConstInterpreter::kConstNullId: EmitOpcode(kLoadLiteralNull); break;
    case ConstInterpreter::kConstTrueId: EmitOpcode(kLoadLiteralTrue); break;
    case ConstInterpreter::kConstFalseId: EmitOpcode(kLoadLiteralFalse); break;
    default:
      EmitOpcode(kLoadConstUnfold);
      EmitLiteral(id, kConstantId);
      break;
  }
  StackSizeChange(1);
}

void Emitter::StoreParameter(int index) {
  ASSERT(index < arity());
  StoreStackLocal(frame_size() + 1 + arity() - index - 1);
}

void Emitter::StoreLocal(int index) {
  StoreStackLocal(frame_size() - index - 1);
}

void Emitter::StoreStackLocal(int index) {
  ASSERT(index >= 0);
  ASSERT(index != frame_size());
  EmitOpcode(kStoreLocal);
  if (index > 0xFF) UNIMPLEMENTED();
  bytes_.Add(index);
}

void Emitter::StoreBoxed(int index) {
  ASSERT(index >= 0);
  EmitOpcode(kStoreBoxed);
  if (index > 0xFF) UNIMPLEMENTED();
  bytes_.Add(frame_size() - index - 1);
}

void Emitter::StoreStatic(int id) {
  EmitOpcode(kStoreStatic);
  EmitInt32(id);
}

void Emitter::StoreField(int field) {
  EmitOpcode(kStoreField);
  bytes_.Add(field);
  StackSizeChange(-1);
}

void Emitter::InvokeMethod(IdentifierNode* name, int arity) {
  InvokeMethod(name->id(), arity);
}

void Emitter::InvokeMethod(int id, int arity) {
  switch (id) {
    case Names::kEquals: EmitOpcode(kInvokeEq); break;
    case Names::kLessThan: EmitOpcode(kInvokeLt); break;
    case Names::kLessEqual: EmitOpcode(kInvokeLe); break;
    case Names::kGreaterThan: EmitOpcode(kInvokeGt); break;
    case Names::kGreaterEqual: EmitOpcode(kInvokeGe); break;

    case Names::kAdd: EmitOpcode(kInvokeAdd); break;
    case Names::kSub: EmitOpcode(kInvokeSub); break;
    case Names::kMod: EmitOpcode(kInvokeMod); break;
    case Names::kMul: EmitOpcode(kInvokeMul); break;
    case Names::kTruncDiv: EmitOpcode(kInvokeTruncDiv); break;

    case Names::kBitNot: EmitOpcode(kInvokeBitNot); break;
    case Names::kBitAnd: EmitOpcode(kInvokeBitAnd); break;
    case Names::kBitOr: EmitOpcode(kInvokeBitOr); break;
    case Names::kBitXor: EmitOpcode(kInvokeBitXor); break;
    case Names::kBitShr: EmitOpcode(kInvokeBitShr); break;
    case Names::kBitShl: EmitOpcode(kInvokeBitShl); break;

    default: EmitOpcode(kInvokeMethod); break;
  }
  if (!Selector::ArityField::is_valid(arity)) UNIMPLEMENTED();
  if (!Selector::IdField::is_valid(id)) UNIMPLEMENTED();
  int value = Selector::EncodeMethod(id, arity);
  EmitInt32(value);
  StackSizeChange(-arity);
}

void Emitter::InvokeNative(int arity, Native native) {
  EmitOpcode(kInvokeNative);
  if (arity > 0xFF) UNIMPLEMENTED();
  bytes_.Add(arity);
  bytes_.Add(native);
  StackSizeChange(1);
}

void Emitter::InvokeNativeYield(int arity, Native native) {
  EmitOpcode(kInvokeNativeYield);
  if (arity > 0xFF) UNIMPLEMENTED();
  bytes_.Add(arity);
  bytes_.Add(native);
  StackSizeChange(1);
}

void Emitter::InvokeGetter(IdentifierNode* name) {
  EmitOpcode(kInvokeMethod);
  int value = Selector::EncodeGetter(name->id());
  EmitInt32(value);
}

void Emitter::InvokeSetter(IdentifierNode* name) {
  EmitOpcode(kInvokeMethod);
  int value = Selector::EncodeSetter(name->id());
  EmitInt32(value);
  StackSizeChange(-1);
}

void Emitter::InvokeStatic(int arity, int id) {
  EmitOpcode(kInvokeStaticUnfold);
  EmitLiteral(id, kMethodId);
  StackSizeChange(1 - arity);
}

void Emitter::InvokeFactory(int arity, int id) {
  EmitOpcode(kInvokeFactoryUnfold);
  EmitLiteral(id, kMethodId);
  StackSizeChange(1 - arity);
}

void Emitter::InvokeTest(IdentifierNode* name) {
  EmitOpcode(kInvokeTest);
  int value = Selector::EncodeMethod(name->id(), 0);
  EmitInt32(value);
}

void Emitter::Bind(Label* label) {
  BindRaw(label);
  last_opcode_ = static_cast<Opcode>(-1);
}

void Emitter::BindRaw(Label* label) {
  ASSERT(!label->is_bound());
  int position = bytes_.length();
  for (int i = 0; i < label->uses(); i++) {
    int use = label->UseAt(i);
    int offset = static_cast<int8>(bytes_.Get(use));
    int delta = position - use + offset;
    bytes_.Set(use + 0, (delta >>  0) & 0xFF);
    bytes_.Set(use + 1, (delta >>  8) & 0xFF);
    bytes_.Set(use + 2, (delta >> 16) & 0xFF);
    bytes_.Set(use + 3, (delta >> 24) & 0xFF);
  }
  label->Bind(position);
}

void Emitter::Branch(Label* label) {
  if (label->is_bound()) {
    EmitBranch(kBranchBack, label);
  } else {
    EmitBranch(kBranchLong, label);
  }
}

void Emitter::BranchIfTrue(Label* label) {
  if (label->is_bound()) {
    EmitBranch(kBranchBackIfTrue, label);
  } else {
    EmitBranch(kBranchIfTrueLong, label);
  }
  StackSizeChange(-1);
}

void Emitter::BranchIfFalse(Label* label) {
  if (label->is_bound()) {
    EmitBranch(kBranchBackIfFalse, label);
  } else {
    EmitBranch(kBranchIfFalseLong, label);
  }
  StackSizeChange(-1);
}

void Emitter::Pop() {
  // Don't modify ends_with_return_.
  bytes_.Add(kPop);
  StackSizeChange(-1);
}

void Emitter::Return() {
  EmitOpcode(kReturn);
  ASSERT(frame_size() >= 0);
  ASSERT(arity() >= 0);
  bytes_.Add(frame_size());
  bytes_.Add(arity());
  StackSizeChange(-1);
}

void Emitter::Dup() {
  LoadStackLocal(0);
}

void Emitter::Allocate(int id, int fields) {
  EmitOpcode(kAllocateUnfold);
  EmitLiteral(id, kClassId);
  StackSizeChange(1 - fields);
}

void Emitter::AllocateBoxed() {
  EmitOpcode(kAllocateBoxed);
}

void Emitter::Negate() {
  EmitOpcode(kNegate);
}

void Emitter::Throw() {
  EmitOpcode(kThrow);
}

void Emitter::SubroutineCall(Label* label, Label* return_label) {
  ASSERT(!label->is_bound());
  EmitBranch(kSubroutineCall, label);
  return_label->Use(position());
  // The position is '-4 bytes' relative to the opcode index (next opcode).
  EmitInt32(-4);
}

void Emitter::SubroutineReturn(Label* return_label) {
  BindRaw(return_label);
  EmitOpcode(kSubroutineReturn);
  StackSizeChange(-1);
}

void Emitter::ProcessYield() {
  EmitOpcode(kProcessYield);
}

void Emitter::CoroutineChange() {
  EmitOpcode(kCoroutineChange);
  StackSizeChange(-1);
}

void Emitter::Identical() {
  EmitOpcode(kIdentical);
  StackSizeChange(-1);
}

void Emitter::IdenticalNonNumeric() {
  EmitOpcode(kIdenticalNonNumeric);
  StackSizeChange(-1);
}

void Emitter::EnterNoSuchMethod() {
  EmitOpcode(kEnterNoSuchMethod);
}

void Emitter::ExitNoSuchMethod() {
  EmitOpcode(kExitNoSuchMethod);
}

void Emitter::FrameSize() {
  EmitOpcode(kFrameSize);
  bytes_.Add(frame_size());
}

bool Emitter::EndsWithReturn() {
  return last_opcode_ == kReturn;
}

void Emitter::AddFrameRange(int start, int end) {
  FrameRange range = {start, end};
  ranges_.Add(range);
}

void Emitter::MethodEnd(int delta) {
  int bytes = bytes_.length();
  EmitOpcode(kMethodEnd);
  EmitInt32(bytes + delta);
  EmitInt32(ranges_.length());
  for (int i = 0; i < ranges_.length(); i++) {
    FrameRange range = ranges_.Get(i);
    EmitInt32(range.start + delta);
    EmitInt32(range.end + delta);
  }
}

void Emitter::EmitOpcode(Opcode opcode) {
  last_opcode_ = opcode;
  bytes_.Add(opcode);
}

void Emitter::EmitBranch(Opcode opcode, Label* label) {
  if (label->is_bound()) {
    int delta = position() - label->position();
    if (delta > 0xFF) {
      EmitOpcode(static_cast<Opcode>(opcode + 3));
      EmitInt32(delta);
    } else {
      ASSERT(delta >= 0x00 && delta <= 0xFF);
      EmitOpcode(opcode);
      bytes_.Add(delta);
    }
  } else {
    EmitOpcode(opcode);
    label->Use(position());
    // The position is '1 byte' relative to the opcode index.
    EmitInt32(1);
  }
}

void Emitter::EmitInt32(int value) {
  bytes_.Add((value >>  0) & 0xFF);
  bytes_.Add((value >>  8) & 0xFF);
  bytes_.Add((value >> 16) & 0xFF);
  bytes_.Add((value >> 24) & 0xFF);
}

void Emitter::EmitLiteral(int id, IdType type) {
  int key = (id << 2) | type;
  int index = 0;
  if (literal_map_.Contains(key)) {
    index = literal_map_.Lookup(key);
  } else {
    index = literals_.length();
    literals_.Add(key);
    literal_map_.Add(key, index);
  }
  EmitInt32(index);
}

void Emitter::StackSizeChange(int delta) {
  stack_size_ += delta;
  if (stack_size_ > max_stack_size_) max_stack_size_ = stack_size_;
}

}  // namespace fletch
