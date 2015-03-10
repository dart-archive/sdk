// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_COMPILER_H_
#define SRC_COMPILER_COMPILER_H_

#include "src/compiler/allocation.h"
#include "src/compiler/library_loader.h"
#include "src/compiler/tree.h"

namespace fletch {

class Emitter;
class ValueVisitor;
class ConstInterpreter;
class InvokeSelector;
class SelectorX;
class IsSelector;
class ConstObject;
class StubMethodNode;
class Code;

class CompiledClass : public ZoneAllocated {
 public:
  class TableEntry : public StackAllocated {
   public:
    TableEntry(int selector, int method)
        : selector_(selector) , method_(method) { }

    TableEntry() : selector_(0), method_(0) { }

    int selector() const { return selector_; }
    int method() const { return method_; }

    static int Compare(const void* a, const void* b);

   private:
    int selector_;
    int method_;
  };

  CompiledClass(ClassNode* node, ClassNode* super, Zone* zone)
      : node_(node)
      , super_(super)
      , method_table_(zone)
      , constructors_(zone, 0) {
  }

  bool has_super() const { return super_ != NULL; }

  ClassNode* node() const { return node_; }
  ClassNode* super() const { return super_; }
  List<TableEntry> method_table() { return method_table_.ToList(); }

  void AddMethodTableEntry(TableEntry entry) {
    method_table_.Add(entry);
  }

  void AddMethodTableEntry(int selector, int method_id) {
    AddMethodTableEntry(TableEntry(selector, method_id));
  }

  void AddConstructor(int id, MethodNode* constructor) {
    constructors_.Add(id, constructor);
  }

  MethodNode* LookupConstructor(int id) {
    return constructors_.Lookup(id);
  }

  bool HasConstructors() const { return !constructors_.is_empty(); }

 private:
  ClassNode* node_;
  ClassNode* super_;
  ListBuilder<TableEntry, 2> method_table_;
  IdMap<MethodNode*> constructors_;
};

class CompilerConsumer {
 public:
  virtual ~CompilerConsumer() {}

  virtual void Initialize(int object_class_id) = 0;

  virtual void DoMethod(MethodNode* method, Code* code) = 0;
  virtual void DoClass(CompiledClass* clazz) = 0;

  virtual void Finalize(List<VariableDeclarationNode*> static_fields,
                        List<ConstObject*> constants,
                        int main_arity,
                        int entry_id) = 0;
};

class Compiler : public StackAllocated {
 public:
  Compiler(Zone* zone,
           Builder* builder,
           const char* library_root,
           const char* package_root);

  LibraryLoader* loader() { return &loader_; }
  Builder* builder() { return loader()->builder(); }

  ConstInterpreter* const_interpreter() { return const_interpreter_; }

  void CompileLibrary(LibraryElement* element, CompilerConsumer* consumer);

  MethodNode* CurrentMethod() const { return method_; }
  bool IsStaticContext() const;

  ClassNode* LookupClass(Scope* scope, IdentifierNode* name);

  int AddStub(StubMethodNode* node);
  int AddClass(ClassNode* node, ClassNode* super);

  int Enqueue(VariableDeclarationNode* node);
  int Enqueue(MethodNode* node);
  int EnqueueConstructor(ClassNode* class_node, MethodNode* node);
  template<typename T> void MarkForSelector(T* node);
  void MarkForInvokeSelector(MethodNode* node);
  void MarkIsSelector(CompiledClass* clazz, IdentifierNode* name);
  IdentifierNode* EnqueueIsSelector(IdentifierNode* name);
  void CreateIsTest(CompiledClass* clazz, IdentifierNode* selector);
  int EnqueueClass(ClassNode* node);

  void EnqueueSelector(IdentifierNode* node);
  void EnqueueSelectorId(int id);
  void EnqueueInvokeSelector(IdentifierNode* node,
                             int arity,
                             List<IdentifierNode*> named_arguments
                                = List<IdentifierNode*>());

  ClassNode* EnqueueCoreClass(const char* class_name);

  void CompileMethod(MethodNode* method, Emitter* emitter);

  void CompileFunction(List<VariableDeclarationNode*> parameters,
                       TreeNode* body,
                       Scope* outer,
                       Emitter* emitter,
                       bool has_this,
                       bool is_native);

  Zone* zone() const { return zone_; }
  IdentifierNode* this_name() const { return this_name_; }
  IdentifierNode* call_name() const { return call_name_; }

  int GetNamedStaticMethodStub(MethodNode* method,
                               IdentifierNode* stub_name,
                               int num_arguments,
                               List<IdentifierNode*> named_arguments,
                               Scope* scope);

  IdentifierNode* BuildNamedArgumentId(IdentifierNode* id,
                                       List<IdentifierNode*> named_arguments);

  CompiledClass* GetCompiledClass(int class_id);

  int GetFieldGetter(int index);
  int GetFieldSetter(int index);

  MethodNode* GetMethod(int id);

  void LoadMethod(MethodNode* method, ValueVisitor* value_visitor);

  void Error(Location location, const char* format, ...);

 private:
  int CompileConstructor(CompiledClass* clazz, MethodNode* constructor);
  int CompileStaticInitializer(int index, VariableDeclarationNode* node);

  void RegisterMethod(int id, MethodNode* node);

  Zone* const zone_;
  LibraryLoader loader_;
  ListBuilder<VariableDeclarationNode*, 8> statics_;
  ListBuilder<int, 4> field_getters_;
  ListBuilder<int, 4> field_setters_;
  ListBuilder<MethodNode*, 8> methods_;
  CompilerConsumer* consumer_;
  MethodNode* method_;
  ConstInterpreter* const_interpreter_;

  IdMap<int> method_tearoffs_;

  IdentifierNode* this_name_;
  IdentifierNode* call_name_;

  ListBuilder<CompiledClass*, 8> classes_;
  IdMap<InvokeSelector*> invoke_selectors_;
  IdMap<IdMap<int>*> named_static_stubs_;
  IdMap<SelectorX*> selectors_;
  IdMap<IsSelector*> is_selectors_;
  PointerMap<MethodNode*, int> constructors_;

  void ProcessQueue();
};

}  // namespace fletch

#endif  // SRC_COMPILER_COMPILER_H_
