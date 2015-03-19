// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/compiler/session.h"

#include <cstdlib>

#include "src/compiler/compiler.h"
#include "src/compiler/const_interpreter.h"
#include "src/compiler/emitter.h"

#include "src/shared/bytecodes.h"
#include "src/shared/connection.h"
#include "src/shared/flags.h"

namespace fletch {

static const char* kBridgeConnectionFlag = "bridge-connection";

class SessionConsumer : public CompilerConsumer, public StackAllocated {
 public:
  SessionConsumer(Compiler* compiler, Session* session, Zone* zone)
      : compiler_(compiler)
      , session_(session)
      , object_class_id_(-1)
      , classes_(zone)
      , methods_(zone)
      , code_(zone)
      , changes_(0) {
  }

  void DoProgram(LibraryElement* root);

  void Initialize(int object_class_id);

  void DoMethod(MethodNode* method, Code* code);
  void DoClass(CompiledClass* clazz);

  void Finalize(List<VariableDeclarationNode*> static_fields,
                List<ConstObject*> constants,
                int main_arity,
                int entry_id);

 private:
  Compiler* const compiler_;
  Session* session_;

  int object_class_id_;
  ListBuilder<CompiledClass*, 128> classes_;
  ListBuilder<MethodNode*, 128> methods_;
  ListBuilder<Code*, 128> code_;
  int changes_;

  Session* session() const { return session_; }

  bool HasObjectClassId() const { return object_class_id_ >= 0; }

  void DoConstants(List<ConstObject*> constants);
  void DoStatics(List<VariableDeclarationNode*> statics);
};

class SessionConstantHandler : public ConstObjectVisitor {
 public:
  explicit SessionConstantHandler(Session* session) : session_(session) { }

  void DoNull(ConstNull* object);
  void DoTrue(ConstTrue* object);
  void DoFalse(ConstFalse* object);
  void DoInteger(ConstInteger* object);
  void DoDouble(ConstDouble* object);
  void DoString(ConstString* object);
  void DoList(ConstList* object);
  void DoMap(ConstMap* object);
  void DoClass(ConstClass* object);

 private:
  Session* const session_;
  Session* session() const { return session_; }
};

Session::Session(Connection* connection)
    : connection_(connection) {
}

Session::~Session() {
}

void Session::BuildProgram(Compiler* compiler, LibraryElement* root) {
  Zone zone;
  SessionConsumer consumer(compiler, this, &zone);
  consumer.DoProgram(root);
}

void Session::RunProcess() {
  connection_->Send(Connection::kSpawnProcessForMain);
  connection_->Send(Connection::kRunProcess);
}

void Session::WriteSnapshot(const char* path) {
  const uint8* data = reinterpret_cast<const uint8*>(path);
  connection_->WriteBytes(data, strlen(path) + 1);
  connection_->Send(Connection::kWriteSnapshot);
}

void Session::CollectGarbage() {
  connection_->Send(Connection::kCollectGarbage);
}

void Session::NewMap(int index) {
  connection_->WriteInt(index);
  connection_->Send(Connection::kNewMap);
}

void Session::DeleteMap(int index) {
  connection_->WriteInt(index);
  connection_->Send(Connection::kDeleteMap);
}

void Session::PushFromMap(int index, int64 id) {
  connection_->WriteInt(index);
  connection_->WriteInt64(id);
  connection_->Send(Connection::kPushFromMap);
}

void Session::PopToMap(int index, int64 id) {
  connection_->WriteInt(index);
  connection_->WriteInt64(id);
  connection_->Send(Connection::kPopToMap);
}

void Session::Dup() {
  connection_->Send(Connection::kDup);
}

void Session::PushNull() {
  connection_->Send(Connection::kPushNull);
}

void Session::PushBoolean(bool value) {
  connection_->WriteBoolean(value);
  connection_->Send(Connection::kPushBoolean);
}

void Session::PushNewInteger(int64 value) {
  connection_->WriteInt64(value);
  connection_->Send(Connection::kPushNewInteger);
}

void Session::PushNewDouble(double value) {
  connection_->WriteDouble(value);
  connection_->Send(Connection::kPushNewDouble);
}

void Session::PushNewString(List<const char> contents) {
  const uint8* data = reinterpret_cast<const uint8*>(contents.data());
  connection_->WriteBytes(data, contents.length());
  connection_->Send(Connection::kPushNewString);
}

void Session::PushNewInstance() {
  connection_->Send(Connection::kPushNewInstance);
}

void Session::PushNewArray(int length) {
  connection_->WriteInt(length);
  connection_->Send(Connection::kPushNewArray);
}

void Session::PushNewName(const char* name) {
  if (Flags::IsOn(kBridgeConnectionFlag)) {
    connection_->WriteString(name);
    connection_->Send(Connection::kPushNewName);
  }
}

void Session::PushNewFunction(int arity, int literals, List<uint8> bytecodes) {
  connection_->WriteInt(arity);
  connection_->WriteInt(literals);
  connection_->WriteBytes(bytecodes.data(), bytecodes.length());
  connection_->Send(Connection::kPushNewFunction);
}

void Session::PushNewInitializer() {
  connection_->Send(Connection::kPushNewInitializer);
}

void Session::PushNewClass(int fields) {
  connection_->WriteInt(fields);
  connection_->Send(Connection::kPushNewClass);
}

void Session::PushBuiltinClass(Names::Id name, int fields) {
  connection_->WriteInt(name);
  connection_->WriteInt(fields);
  connection_->Send(Connection::kPushBuiltinClass);
}

void Session::PushConstantList(int length) {
  connection_->WriteInt(length);
  connection_->Send(Connection::kPushConstantList);
}

void Session::PushConstantMap(int length) {
  connection_->WriteInt(length);
  connection_->Send(Connection::kPushConstantMap);
}

void Session::ChangeSuperClass() {
  connection_->Send(Connection::kChangeSuperClass);
}

void Session::ChangeMethodTable(int length) {
  connection_->WriteInt(length);
  connection_->Send(Connection::kChangeMethodTable);
}

void Session::ChangeMethodLiteral(int index) {
  connection_->WriteInt(index);
  connection_->Send(Connection::kChangeMethodLiteral);
}

void Session::ChangeStatics(int count) {
  connection_->WriteInt(count);
  connection_->Send(Connection::kChangeStatics);
}

void Session::CommitChanges(int count) {
  connection_->WriteInt(count);
  connection_->Send(Connection::kCommitChanges);
}

void Session::DiscardChanges() {
  connection_->Send(Connection::kDiscardChanges);
}

void SessionConstantHandler::DoNull(ConstNull* object) {
  session()->PushNull();
}

void SessionConstantHandler::DoTrue(ConstTrue* object) {
  session()->PushBoolean(true);
}

void SessionConstantHandler::DoFalse(ConstFalse* object) {
  session()->PushBoolean(false);
}

void SessionConstantHandler::DoInteger(ConstInteger* object) {
  session()->PushNewInteger(object->value());
}

void SessionConstantHandler::DoDouble(ConstDouble* object) {
  session()->PushNewDouble(object->value());
}

void SessionConstantHandler::DoString(ConstString* object) {
  const char* value = object->value();
  int length = strlen(value);
  session()->PushNewString(List<const char>(value, length));
}

void SessionConstantHandler::DoList(ConstList* object) {
  List<ConstObject*> elements = object->elements();
  for (int i = 0; i < elements.length(); i++) {
    session()->PushFromMap(kConstantId, elements[i]->id());
  }
  session()->PushConstantList(elements.length());
}

void SessionConstantHandler::DoMap(ConstMap* object) {
  List<ConstObject*> elements = object->elements();
  int map_length = elements.length() / 2;
  for (int i = 0; i < map_length; i++) {
    session()->PushFromMap(kConstantId, elements[i * 2]->id());
  }
  session()->PushConstantList(map_length);
  for (int i = 0; i < map_length; i++) {
    session()->PushFromMap(kConstantId, elements[i * 2 + 1]->id());
  }
  session()->PushConstantList(map_length);
  session()->PushConstantMap(elements.length());
}

void SessionConstantHandler::DoClass(ConstClass* object) {
  List<ConstObject*> fields = object->fields();
  for (int i = 0; i < fields.length(); i++) {
    session()->PushFromMap(kConstantId, fields[i]->id());
  }
  session()->PushFromMap(kClassId, object->node()->id());
  session()->PushNewInstance();
}

void SessionConsumer::DoProgram(LibraryElement* root) {
  session()->PushNewName("classMap");
  session()->NewMap(kClassId);
  session()->PushNewName("methodMap");
  session()->NewMap(kMethodId);
  session()->NewMap(kConstantId);
  compiler_->CompileLibrary(root, this);
}

void SessionConsumer::Initialize(int object_class_id) {
  ASSERT(!HasObjectClassId());
  object_class_id_ = object_class_id;
  ASSERT(HasObjectClassId());
}

void SessionConsumer::Finalize(List<VariableDeclarationNode*> static_fields,
                               List<ConstObject*> constants,
                               int main_arity,
                               int entry_id) {
  DoStatics(static_fields);
  DoConstants(constants);

  // Resolve all the super class references.
  for (int i = 0; i < classes_.length(); i++) {
    CompiledClass* clazz = classes_.Get(i);
    if (clazz->node()->id() == object_class_id_) continue;
    int super_id = object_class_id_;
    if (clazz->has_super()) super_id = clazz->super()->id();
    session()->PushFromMap(kClassId, clazz->node()->id());
    session()->PushFromMap(kClassId, super_id);
    session()->ChangeSuperClass();
    changes_++;
  }

  // Resolve all method literals.
  for (int i = 0; i < methods_.length(); i++) {
    MethodNode* method = methods_.Get(i);
    Code* code = code_.Get(i);
    List<int> literals = code->ids();
    for (int j = 0; j < literals.length(); j++) {
      int encoded = literals[j];
      IdType type = static_cast<IdType>(encoded & 3);
      int id = encoded >> 2;
      session()->PushFromMap(kMethodId, method->id());
      session()->PushFromMap(type, id);
      session()->ChangeMethodLiteral(j);
      changes_++;
    }
  }

  session()->CommitChanges(changes_);
  changes_ = 0;

  // Leave the entry method and the number of arguments to main on top of the
  // stack.
  session()->PushNewInteger(main_arity);
  session()->PushFromMap(kMethodId, entry_id);
}

void SessionConsumer::DoMethod(MethodNode* method, Code* code) {
  List<int> ids = code->ids();
  for (int i = 0; i < ids.length(); i++) {
    session()->PushNull();
  }

  const char* name = method->name()->IsIdentifier()
      ? method->name()->AsIdentifier()->value() : "";
  session()->PushNewName(name);
  session()->PushNewFunction(code->arity(), ids.length(), code->bytes());
  session()->PopToMap(kMethodId, method->id());

  methods_.Add(method);
  code_.Add(code);
}

void SessionConsumer::DoConstants(List<ConstObject*> constants) {
  SessionConstantHandler encoder(session());
  for (int i = 0; i < constants.length(); i++) {
    constants[i]->Accept(&encoder);
    session()->PopToMap(kConstantId, i);
  }
}

void SessionConsumer::DoClass(CompiledClass* clazz) {
  ASSERT(HasObjectClassId());
  int name = clazz->node()->name()->id();
  session()->PushNewName(clazz->node()->name()->value());
  if (Names::IsBuiltinClassName(name)) {
    session()->PushBuiltinClass(static_cast<Names::Id>(name),
                                clazz->node()->FieldCount());
  } else {
    session()->PushNewClass(clazz->node()->FieldCount());
  }

  session()->Dup();
  session()->PopToMap(kClassId, clazz->node()->id());

  List<CompiledClass::TableEntry> method_table = clazz->method_table();
  qsort(method_table.data(),
        method_table.length(),
        sizeof(CompiledClass::TableEntry),
        CompiledClass::TableEntry::Compare);

  int methods = method_table.length();
  for (int i = 0; i < method_table.length(); i++) {
    session()->PushNewInteger(method_table[i].selector());
    session()->PushFromMap(kMethodId, method_table[i].method());
  }
  session()->ChangeMethodTable(methods);
  changes_++;
  classes_.Add(clazz);
}

void SessionConsumer::DoStatics(List<VariableDeclarationNode*> statics) {
  for (int i = 0; i < statics.length(); i++) {
    VariableDeclarationNode* var = statics[i];
    ASSERT(var->owner()->IsLibrary() || var->modifiers().is_static());
    if (var->has_initializer()) {
      session()->PushFromMap(kMethodId, var->setter_id());
      session()->PushNewInitializer();
    } else {
      session()->PushNull();
    }
  }
  session()->ChangeStatics(statics.length());
  changes_++;
}

}  // namespace fletch
