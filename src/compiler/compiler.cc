// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <cstdlib>
#include <cstdarg>

#include "src/shared/assert.h"
#include "src/shared/flags.h"
#include "src/shared/names.h"
#include "src/shared/selectors.h"

#include "src/compiler/class_visitor.h"
#include "src/compiler/compiler.h"
#include "src/compiler/const_interpreter.h"
#include "src/compiler/emitter.h"
#include "src/compiler/os.h"
#include "src/compiler/resolver.h"
#include "src/compiler/scope.h"
#include "src/compiler/scope_resolver.h"
#include "src/compiler/string_buffer.h"

namespace fletch {

class AddOneNode;
class CompoundAssignNode;
class TearoffBodyNode;

struct RestoreLabel {
  Label* break_label;
  Label* continue_label;
  Label* finally_label;
  Label* finally_return_label;
  int stack_size;
  int name_id;
  bool label_only;
};

class ParameterMatcher {
 public:
  virtual int LoadArgument(ExpressionNode* argument) = 0;
  virtual void MatchPositional(IdentifierNode* name,
                               int position,
                               ExpressionNode* value) = 0;
  virtual void MatchNamed(IdentifierNode* name,
                          int positional,
                          ExpressionNode* value) = 0;
  virtual void BadMatch() = 0;
};

class ValueVisitor : public TreeVisitor {
 public:
  ValueVisitor(Compiler* compiler, Emitter* emitter, Scope* scope);

  void Do(TreeNode* node) { UNREACHABLE(); }

  void DoBlock(BlockNode* node);
  void DoStatements(List<TreeNode*> statements);
  void ImplicitScopeStatement(StatementNode* statements);
  void DoVariableDeclarationStatement(VariableDeclarationStatementNode* node);
  void DoVariableDeclaration(VariableDeclarationNode* node);
  void AddVariableDeclarationToScope(VariableDeclarationNode* node);
  void DoExpressionStatement(ExpressionStatementNode* node);
  void DoEmptyStatement(EmptyStatementNode* node);
  void DoLabelledStatement(LabelledStatementNode* node);
  void DoIf(IfNode* node);
  void DoWhile(WhileNode* node);
  void DoFor(ForNode* node);
  void DoForIn(ForInNode* node);
  void DoDoWhile(DoWhileNode* node);
  void DoSwitch(SwitchNode* node);
  void DoTry(TryNode* node);
  void DoCatch(CatchNode* node);
  void DoRethrow(RethrowNode* node);
  void DoReturn(ReturnNode* node);
  void EmitReturn();
  int PopTo(int stack_size, int new_stack_size, bool pop_transparent = true);

  void DoThis(ThisNode* node);
  void DoSuper(SuperNode* node);
  void DoNull(NullNode* node);

  void DoParenthesized(ParenthesizedNode* node);
  void DoAssign(AssignNode* node);
  void DoUnary(UnaryNode* node);
  void DoBinary(BinaryNode* node);
  void DoConditional(ConditionalNode* node);
  void DoDot(DotNode* node);
  void DoInvoke(InvokeNode* node);
  void DoIndex(IndexNode* node);
  void DoCascadeReceiver(CascadeReceiverNode* node);
  void DoCascade(CascadeNode* node);
  void DoNew(NewNode* node);
  void DoMethod(MethodNode* node);
  void DoFunctionExpression(FunctionExpressionNode* node);
  void DoClosure(IdentifierNode* name,
                 List<VariableDeclarationNode*> captured,
                 List<VariableDeclarationNode*> parameters,
                 TreeNode* body);
  void DoThrow(ThrowNode* node);
  void DoBreak(BreakNode* node);
  void DoContinue(ContinueNode* node);
  void DoIs(IsNode* node);
  void IsCheck(IdentifierNode* name);
  void DoAs(AsNode* node);

  void DoIdentifier(IdentifierNode* node);

  void DoStringInterpolation(StringInterpolationNode* node);

  void DoLiteralInteger(LiteralIntegerNode* node);
  void DoLiteralDouble(LiteralDoubleNode* node);
  void DoLiteralString(LiteralStringNode* node);
  void DoLiteralBoolean(LiteralBooleanNode* node);
  void DoLiteralList(LiteralListNode* node);
  void DoLiteralMap(LiteralMapNode* node);

  void DoAddOneNode(AddOneNode* node);
  void DoCompoundAssignNode(CompoundAssignNode* node);
  void DoTearoffBody(TearoffBodyNode* node);

  void StoreExpressionNode(ExpressionNode* node, ExpressionNode* value);
  void StoreScopeEntry(ScopeEntry* entry, ExpressionNode* value);
  void StoreVariableDeclaration(VariableDeclarationNode* node,
                                ExpressionNode* value);

  void LoadExpressionNode(ExpressionNode* node);
  void LoadScopeEntry(ScopeEntry* entry);
  void LoadVariableDeclaration(VariableDeclarationNode* node);
  void InvokeStatic(MethodNode* node,
                    List<ExpressionNode*> arguments,
                    List<IdentifierNode*> named_arguments);
  void InvokeMethod(
      ExpressionNode* object,
      IdentifierNode* name,
      List<ExpressionNode*> arguments,
      List<IdentifierNode*> named_arguments = List<IdentifierNode*>());
  void InvokeOperator(Token token, int argument_count);
  void InvokeConstructor(ClassNode* clazz,
                         MethodNode* node,
                         List<ExpressionNode*> arguments,
                         List<IdentifierNode*> named_arguments);

  void HandleUnresolved(IdentifierNode* name);

  bool LoadPositionalArguments(List<ExpressionNode*> arguments,
                               List<VariableDeclarationNode*> parameters);

  int LoadNamedArguments(MethodNode* method,
                         List<ExpressionNode*> arguments,
                         List<IdentifierNode*> named_arguments);

  void LoadArguments(List<ExpressionNode*> arguments);

  void MatchParameters(ParameterMatcher* parameter_matcher,
                       List<VariableDeclarationNode*> parameters,
                       List<ExpressionNode*> arguments,
                       List<IdentifierNode*> named_arguments);
  void MatchNamedParameter(ParameterMatcher* parameter_matcher,
                           VariableDeclarationNode* parameter,
                           List<ExpressionNode*> arguments,
                           List<IdentifierNode*> named_arguments,
                           List<int> positions);

  TreeNode* SuperLookup(IdentifierNode* name, bool report = true);

  void LoadName(IdentifierNode* name);
  void LoadConst(TreeNode* node, Scope* scope);
  void LoadNull();
  void LoadBoolean(bool value);

  void CreateStaticInitializerCycleCheck(int index);

  Emitter* emitter() const { return emitter_; }
  Compiler* compiler() const { return compiler_; }
  Builder* builder() const { return compiler()->builder(); }

  Scope* set_scope(Scope* value) {
    Scope* old = scope_;
    scope_ = value;
    return old;
  }

  void PopRestoreLabel() {
    restore_labels_.RemoveLast();
  }

  void PushRestoreLabel(Label* break_label,
                        Label* continue_label,
                        int stack_size,
                        bool label_only = false) {
    RestoreLabel restore = { break_label,
                             continue_label,
                             NULL,
                             NULL,
                             stack_size,
                             name_id_,
                             label_only };
    restore_labels_.Add(restore);
    name_id_ = -1;
  }

  void SetNamedRestoreLabel(int name_id) {
    name_id_ = name_id;
  }

  void PushFinallyRestoreLabel(Label* finally_label,
                               Label* finally_return_label,
                               int stack_size) {
    RestoreLabel restore = { NULL,
                             NULL,
                             finally_label,
                             finally_return_label,
                             stack_size,
                             -1,
                             false };
    restore_labels_.Add(restore);
  }

 private:
  Compiler* const compiler_;
  Emitter* const emitter_;
  Scope* scope_;
  ListBuilder<RestoreLabel, 2> restore_labels_;
  int exception_index_;
  int name_id_;

  Scope* scope() const { return scope_; }
  Zone* zone() const { return compiler_->zone(); }
};

class StubMethodNode : public MethodNode {
 public:
  StubMethodNode(IdentifierNode* name,
                 List<VariableDeclarationNode*> parameters)
      : MethodNode(Modifiers(), name, parameters, List<TreeNode*>(), NULL) {
  }

  StubMethodNode(Modifiers modifiers,
                 TreeNode* name,
                 List<VariableDeclarationNode*> parameters,
                 TreeNode* body)
      : MethodNode(modifiers, name, parameters, List<TreeNode*>(), body) {
  }

  Code* code() const { return code_; }
  void set_code(Code* value) { code_ = value; }

 private:
  Code* code_;
};

class AddOneNode : public ExpressionNode {
 public:
  AddOneNode(int frame_pos, ExpressionNode* expression, bool negative)
      : frame_pos_(frame_pos)
      , expression_(expression)
      , negative_(negative) {
  }

  virtual void Accept(TreeVisitor* visitor) {
    static_cast<ValueVisitor*>(visitor)->DoAddOneNode(this);
  }

  int frame_pos() const { return frame_pos_; }
  ExpressionNode* expression() const { return expression_; }
  bool negative() const { return negative_; }

 private:
  int frame_pos_;
  ExpressionNode* expression_;
  bool negative_;
};

class CompoundAssignNode : public ExpressionNode {
 public:
  CompoundAssignNode(int token, ExpressionNode* target, ExpressionNode* value)
      : token_(token)
      , target_(target)
      , value_(value) {
  }

  virtual void Accept(TreeVisitor* visitor) {
    static_cast<ValueVisitor*>(visitor)->DoCompoundAssignNode(this);
  }

  int token() const { return token_; }
  ExpressionNode* target() const { return target_; }
  ExpressionNode* value() const { return value_; }

 private:
  int token_;
  ExpressionNode* target_;
  ExpressionNode* value_;
};

class TearoffBodyNode : public TreeNode {
 public:
  explicit TearoffBodyNode(MethodNode* method)
      : method_(method) {
  }

  virtual void Accept(TreeVisitor* visitor) {
    static_cast<ValueVisitor*>(visitor)->DoTearoffBody(this);
  }

  MethodNode* method() const { return method_; }

 private:
  MethodNode* method_;
};

class SelectorX : public ZoneAllocated {
 public:
  explicit SelectorX(TreeNode* node) : node_(node) { }

  bool is_done() const { return node_ == NULL; }
  void mark_done() { node_ = NULL; }

  TreeNode* node() const { return node_; }
  void set_node(TreeNode* value) { node_ = value; }

 private:
  TreeNode* node_;
};

static IdentifierNode* GetLastIdentifier(TreeNode* name) {
  DotNode* dot = name->AsDot();
  if (dot != NULL) return dot->name();
  ASSERT(name->IsIdentifier());
  return name->AsIdentifier();
}

static bool HasThisArgument(MethodNode* method) {
  TreeNode* owner = method->owner();
  if (owner == NULL || !owner->IsClass()) return false;
  return !method->modifiers().is_static() && !method->modifiers().is_factory();
}

static bool IsEmptyBody(TreeNode* node) {
  if (node == NULL) return true;
  if (node->IsEmptyStatement()) return true;
  if (BlockNode* block = node->AsBlock()) return block->statements().is_empty();
  return false;
}

class IsSelector : public ZoneAllocated {
 public:
  explicit IsSelector(Zone* zone) : classes_(zone), selector_(NULL) { }

  void Add(Compiler* compiler, CompiledClass* clazz) {
    if (selector_ != NULL) {
      compiler->CreateIsTest(clazz, selector_);
    } else {
      classes_.Add(clazz);
    }
  }

  IdentifierNode* Mark(Compiler* compiler, IdentifierNode* name) {
    if (selector_ != NULL) return selector_;
    Zone* zone = compiler->zone();
    int length = strlen(name->value());
    char* buffer = reinterpret_cast<char*>(zone->Allocate(length + 4));
    buffer[0] = 'i';
    buffer[1] = 's';
    buffer[2] = '@';
    memmove(buffer + 3, name->value(), length);
    buffer[length + 3] = '\0';
    selector_ = compiler->builder()->Canonicalize(buffer);
    for (int i = 0; i < classes_.length(); i++) {
      compiler->CreateIsTest(classes_.Get(i), selector_);
    }
    classes_.Clear();
    return selector_;
  }

 private:
  ListBuilder<CompiledClass*, 2> classes_;
  IdentifierNode* selector_;
};

class InvokeSelector : public ZoneAllocated {
 public:
  explicit InvokeSelector(Zone* zone) : arities_(zone, 0) {}

  List<List<IdentifierNode*>*> SeenArity(
      int arity,
      List<IdentifierNode*> named_arguments) {
    ArityMap* map = arities_.Lookup(arity);
    if (map == NULL) return List<List<IdentifierNode*>*>();
    List<int> ids = List<int>::New(zone(), named_arguments.length());
    for (int i = 0; i < named_arguments.length(); i++) {
      ids[i] = named_arguments[i]->id();
    }
    qsort(ids.data(), ids.length(), sizeof(int), SortIds);
    ListBuilder<List<IdentifierNode*>*, 4> result(zone());
    NamedTrieNode* node = map->node;
    if (!node->seen.is_empty()) node->seen.AddToListBuilder(&result);
    FindSeen(node, 0, ids, &result);
    return result.ToList();
  }

  bool AddMethod(MethodNode* method) {
    List<VariableDeclarationNode*> parameters = method->parameters();
    ListBuilder<int, 2> ids_builder(zone());
    for (int i = 0; i < parameters.length(); i++) {
      VariableDeclarationNode* parameter = parameters[i];
      if (parameter->modifiers().is_named()) {
        ids_builder.Add(parameter->name()->id());
      }
    }
    List<int> ids = ids_builder.ToList();
    qsort(ids.data(), ids.length(), sizeof(int), SortIds);
    int optional_count = method->OptionalParameterCount();
    for (int missing = 0; missing <= optional_count; missing++) {
      int arity = parameters.length() - missing;
      ArityMap* map = arities_.Lookup(arity);
      if (map == NULL) {
        map = new(zone()) ArityMap(zone());
        arities_.Add(arity, map);
      }
      NamedTrieNode* node = map->node;
      if (node->marked) return true;
      node->methods.Add(method);
      for (int i = 0; i < ids.length(); i++) {
        node = map->node;
        // For all ids, marks as root (and add remaining). This works because
        // ids are sorted.
        for (int j = i; j < ids.length(); j++) {
          node = node->Child(zone(), ids[j]);
          if (node->marked) return true;
          node->methods.Add(method);
        }
      }
    }
    return false;
  }

  List<MethodNode*> MarkArity(int arity,
                              IdentifierNode* named_id,
                              List<IdentifierNode*> named_arguments) {
    ArityMap* map = arities_.Lookup(arity);
    if (map == NULL) {
      map = new(zone()) ArityMap(zone());
      arities_.Add(arity, map);
    }
    List<int> ids = List<int>::New(zone(), named_arguments.length());
    for (int i = 0; i < named_arguments.length(); i++) {
      ids[i] = named_arguments[i]->id();
    }
    qsort(ids.data(), ids.length(), sizeof(int), SortIds);
    NamedTrieNode* node = map->node;
    for (int i = 0; i < ids.length(); i++) {
      node = node->Child(zone(), ids[i]);
    }
    List<IdentifierNode*>* seen = node->seen.Lookup(named_id->id());
    if (seen == NULL) {
      seen = new(zone()) List<IdentifierNode*>(named_arguments.data(),
                                               named_arguments.length());
      node->seen.Add(named_id->id(), seen);
    }
    if (node->marked) return List<MethodNode*>();
    node->marked = true;
    List<MethodNode*> methods = node->methods.ToList();
    node->methods.Clear();
    return methods;
  }

 private:
  class NamedTrieNode : public TrieNode<NamedTrieNode> {
   public:
    explicit NamedTrieNode(Zone* zone, int id = 0)
      : TrieNode(id)
      , marked(false)
      , seen(zone, 0)
      , methods(zone) {
    }

    bool marked;
    IdMap<List<IdentifierNode*>*> seen;
    // To keep the TrieNodes small, don't pre-allocate more than one.
    ListBuilder<MethodNode*, 1> methods;
  };

  struct ArityMap : public ZoneAllocated {
    explicit ArityMap(Zone* zone)
        : methods(zone)
        , node(new(zone) NamedTrieNode(zone)) {
    }

    ListBuilder<MethodNode*, 2> methods;
    NamedTrieNode* node;
  };

  static void FindSeen(NamedTrieNode* node,
                       int offset,
                       List<int> ids,
                       ListBuilder<List<IdentifierNode*>*, 4>* result) {
    for (int i = offset; i < ids.length(); i++) {
      NamedTrieNode* child = node->LookupChild(ids[i]);
      if (child != NULL) {
        if (!child->seen.is_empty()) child->seen.AddToListBuilder(result);
        // Check methods.
        if (i < ids.length()) {
          FindSeen(child, i, ids, result);
        }
      }
    }
  }

  static int SortIds(const void* a, const void* b) {
    return *reinterpret_cast<const int*>(a) - *reinterpret_cast<const int*>(b);
  }

  Zone* zone() const { return arities_.zone(); }

  IdMap<ArityMap*> arities_;
};

int CompiledClass::TableEntry::Compare(const void* a, const void* b) {
  return static_cast<const TableEntry*>(a)->selector() -
      static_cast<const TableEntry*>(b)->selector();
}

Compiler::Compiler(Zone* zone, Builder* builder, const char* library_root)
    : zone_(zone)
    , loader_(builder, library_root)
    , statics_(zone)
    , field_getters_(zone)
    , field_setters_(zone)
    , methods_(zone)
    , consumer_(NULL)
    , method_(NULL)
    , method_tearoffs_(zone, 0)
    , classes_(zone)
    , invoke_selectors_(zone, 0)
    , named_static_stubs_(zone, 0)
    , selectors_(zone, 0)
    , is_selectors_(zone, 0)
    , constructors_(zone, 0) {
  const_interpreter_ = new(zone) ConstInterpreter(this);
  this_name_ = builder->Canonicalize("this$");
  call_name_ = builder->Canonicalize("call");
}

void Compiler::CompileLibrary(LibraryElement* element,
                              CompilerConsumer* consumer) {
  consumer_ = consumer;

  // Load main through 'dart:system's _entry method.
  LibraryElement* system = loader_.FetchLibrary("dart:system");
  system->AddImportOf(element);

  const char* entry_name = Flags::IsOn("scheduler")
      ? "_entryScheduler"
      : "_entry";
  IdentifierNode* entry_identifier = builder()->Canonicalize(entry_name);
  Scope* system_scope = system->library()->scope();
  MemberEntry* entry = system_scope->Lookup(entry_identifier)->AsMember();
  ASSERT(entry != NULL);
  int entry_id = Enqueue(entry->member()->AsMethod());

  // Verify that main is valid.
  IdentifierNode* main_identifier = builder()->Canonicalize("main");
  ScopeEntry* main_entry = system_scope->Lookup(main_identifier);
  if (main_entry == NULL) {
    Error(Location(), "Unable to locate main");
  }
  TreeNode* node = main_entry->AsMember()->member();
  if (node == NULL) {
    Error(Location(), "main can not be a setter");
  }
  MethodNode* main = node->AsMethod();
  if (main == NULL || main->modifiers().is_get()) {
    Error(Location(), "main must be a method");
  }
  int main_arity = main->parameters().length();

  static const int kObjectClassId = 0;
  consumer->Initialize(kObjectClassId);
  int object_class_id = EnqueueCoreClass("Object")->id();
  ASSERT(object_class_id == kObjectClassId);

  EnqueueCoreClass("bool");
  EnqueueCoreClass("Null");
  EnqueueCoreClass("double");
  EnqueueCoreClass("_Smi");
  EnqueueCoreClass("_Mint");
  EnqueueCoreClass("List");
  EnqueueCoreClass("_ConstantList");
  EnqueueCoreClass("_ConstantMap");
  EnqueueCoreClass("String");

  EnqueueSelectorId(Names::kNoSuchMethod);
  EnqueueSelectorId(Names::kNoSuchMethodTrampoline);
  EnqueueSelectorId(Names::kYield);
  EnqueueSelectorId(Names::kCoroutineStart);

  ProcessQueue();

  for (int i = 0; i < classes_.length(); i++) {
    consumer_->DoClass(classes_.Get(i));
  }

  List<ConstObject*> constants = const_interpreter()->const_objects();
  consumer->Finalize(statics_.ToList(), constants, main_arity, entry_id);
  consumer_ = NULL;
}

bool Compiler::IsStaticContext() const {
  MethodNode* method = CurrentMethod();
  return !HasThisArgument(method);
}

struct FieldAccessors : public ZoneAllocated {
  MethodNode* getter;
  MethodNode* setter;
};

void Compiler::ProcessQueue() {
  int method_count = 0;
  for (int i = 0; i < methods_.length(); i++) {
    MethodNode* method = methods_.Get(i);
    if (method->id() < 0) {
      StubMethodNode* stub = static_cast<StubMethodNode*>(method);
      stub->set_id(method_count++);
      consumer_->DoMethod(stub, stub->code());
    } else {
      int argument_count = method->parameters().length();
      if (HasThisArgument(method)) argument_count++;
      Emitter emitter(zone(), argument_count);
      CompileMethod(method, &emitter);
      method_count++;
      consumer_->DoMethod(method, emitter.GetCode());
    }
  }

  ASSERT(method_count == methods_.length());

  for (int i = 0; i < method_count; i++) {
    MethodNode* method = methods_.Get(i);
    if (method->modifiers().is_static()) continue;
    TreeNode* owner = method->owner();
    if (owner == NULL) continue;
    ClassNode* class_node = owner->AsClass();
    if (class_node == NULL) continue;
    CompiledClass* clazz = GetCompiledClass(class_node->id());

    IdentifierNode* name = method->name()->AsIdentifier();
    if (name == NULL) name = method->name()->AsDot()->name();
    InvokeSelector* selector = invoke_selectors_.Lookup(name->id());
    if (selector == NULL) continue;

    List<VariableDeclarationNode*> parameters = method->parameters();
    ListBuilder<IdentifierNode*, 2> named_builder(zone());
    for (int i = 0; i < parameters.length(); i++) {
      VariableDeclarationNode* parameter = parameters[i];
      if (parameter->modifiers().is_named()) {
        named_builder.Add(parameter->name());
      }
    }
    List<IdentifierNode*> named = named_builder.ToList();
    for (int i = parameters.length(); i >= 0; i--) {
      List<List<IdentifierNode*>*> seen = selector->SeenArity(i, named);
      for (int k = 0; k < seen.length(); k++) {
        if (named.length() > 0) {
          List<IdentifierNode*> named_arguments = *seen[k];
          IdentifierNode* stub_name = BuildNamedArgumentId(name,
                                                           named_arguments);
          int id = GetNamedStaticMethodStub(method,
                                            stub_name,
                                            i,
                                            named_arguments,
                                            method->GetOwnerScope());
          int selector = Selector::EncodeMethod(stub_name->id(), i);
          if (id >= 0) clazz->AddMethodTableEntry(selector, id);
        } else {
          if (i == parameters.length()) continue;
          VariableDeclarationNode* parameter = parameters[i];
          if (!parameter->modifiers().is_positional()) break;
          Emitter emitter(zone(), 1 + i);
          emitter.LoadThis();
          for (int j = 0; j < i; j++) {
            emitter.LoadParameter(j + 1);
          }
          for (int j = i; j < parameters.length(); j++) {
            VariableDeclarationNode* p = parameters[j];
            Scope* scope = method->GetOwnerScope();
            ValueVisitor visitor(this, &emitter, scope);
            if (p->has_initializer()) {
              visitor.LoadConst(p->value(), scope);
            } else {
              visitor.LoadNull();
            }
          }
          emitter.InvokeStatic(parameters.length() + 1, method->id());
          emitter.Return();
          StubMethodNode* stub = new(zone()) StubMethodNode(
              name, List<VariableDeclarationNode*>::New(zone(), i));
          stub->set_owner(class_node);
          stub->set_code(emitter.GetCode());
          AddStub(stub);
        }
      }
    }
  }

  for (int i = method_count; i < methods_.length(); i++) {
    StubMethodNode* stub = static_cast<StubMethodNode*>(methods_.Get(i));
    ASSERT(stub->id() == -1);
    stub->set_id(method_count++);
    consumer_->DoMethod(stub, stub->code());
  }
}

ClassNode* Compiler::LookupClass(Scope* scope, IdentifierNode* name) {
  ScopeEntry* entry = scope->Lookup(name);
  if (entry == NULL) return NULL;
  if (entry->IsMember()) {
    TreeNode* member = entry->AsMember()->member();
    if (member != NULL) {
      ClassNode* class_node = member->AsClass();
      if (class_node != NULL) return class_node;
    }
  }
  Error(name->location(), "'%s' is not a class", name->value());
  return NULL;
}

int Compiler::AddStub(StubMethodNode* node) {
  int id = methods_.length();
  methods_.Add(node);
  RegisterMethod(id, node);
  return id;
}

int Compiler::Enqueue(VariableDeclarationNode* node) {
  TreeNode* owner = node->owner();
  if (owner->IsLibrary() || node->modifiers().is_static()) {
    int index = node->index();
    if (index < 0) {
      index = statics_.length();
      statics_.Add(node);
      node->set_index(index);
      if (node->has_initializer()) {
        // Hack. We reuse the setter_id field.
        int initializer_id = CompileStaticInitializer(index, node);
        node->set_setter_id(initializer_id);
      }
    }
    return index;
  }

  // Class field, add getter/setter.
  int class_id = EnqueueClass(owner->AsClass());
  CompiledClass* clazz = GetCompiledClass(class_id);
  int index = node->index();
  int id = node->name()->id();
  clazz->AddMethodTableEntry(Selector::EncodeGetter(id), GetFieldGetter(index));
  if (!node->modifiers().is_final()) {
    clazz->AddMethodTableEntry(Selector::EncodeSetter(id),
                               GetFieldSetter(index));
  }
  return -1;
}

int Compiler::Enqueue(MethodNode* node) {
  int id = node->id();
  if (id < 0) {
    id = methods_.length();
    node->set_id(id);
    methods_.Add(node);
    RegisterMethod(id, node);
  }
  return id;
}

int Compiler::EnqueueConstructor(ClassNode* class_node, MethodNode* node) {
  int class_id = EnqueueClass(class_node);
  ASSERT(node != NULL);
  // Factory constructors are just plain static functions.
  if (node->modifiers().is_factory()) {
    return Enqueue(node);
  }
  if (constructors_.Contains(node)) {
    return constructors_.Lookup(node);
  }
  int stub_id = CompileConstructor(GetCompiledClass(class_id), node);
  constructors_.Add(node, stub_id);
  return stub_id;
}

template<typename T> void Compiler::MarkForSelector(T* node) {
  int id = node->name()->AsIdentifier()->id();
  SelectorX* selector = selectors_.Lookup(id);
  if (selector == NULL) {
    selectors_.Add(id, new(zone()) SelectorX(node));
  } else if (selector->is_done()) {
    Enqueue(node);
  } else {
    node->set_link(selector->node());
    selector->set_node(node);
  }
}

void Compiler::MarkForInvokeSelector(MethodNode* node) {
  int id = node->name()->AsIdentifier()->id();
  InvokeSelector* selector = invoke_selectors_.Lookup(id);
  if (selector == NULL) {
    selector = new(zone()) InvokeSelector(zone());
    invoke_selectors_.Add(id, selector);
  }
  if (selector->AddMethod(node)) {
    Enqueue(node);
  }
}

int Compiler::AddClass(ClassNode* node, ClassNode* super) {
  int id = classes_.length();
  node->set_id(id);
  CompiledClass* clazz = new(zone()) CompiledClass(node, super, zone());
  classes_.Add(clazz);
  return id;
}

void Compiler::MarkIsSelector(CompiledClass* clazz, IdentifierNode* name) {
  IsSelector* selector = is_selectors_.Lookup(name->id());
  if (selector == NULL) {
    selector = new(zone()) IsSelector(zone());
    is_selectors_.Add(name->id(), selector);
  }
  selector->Add(this, clazz);
}

IdentifierNode* Compiler::EnqueueIsSelector(IdentifierNode* name) {
  IsSelector* selector = is_selectors_.Lookup(name->id());
  if (selector == NULL) {
    selector = new(zone()) IsSelector(zone());
    is_selectors_.Add(name->id(), selector);
  }
  return selector->Mark(this, name);
}

void Compiler::CreateIsTest(CompiledClass* clazz, IdentifierNode* selector) {
  StubMethodNode* test_method = new(zone()) StubMethodNode(
      selector, List<VariableDeclarationNode*>());
  test_method->set_owner(clazz->node());
  Emitter emitter(zone(), 1);
  ValueVisitor visitor(this, &emitter, clazz->node()->scope());
  visitor.LoadBoolean(true);
  emitter.Return();
  test_method->set_code(emitter.GetCode());
  AddStub(test_method);
}

int Compiler::EnqueueClass(ClassNode* node) {
  int id = node->id();
  if (id < 0) {
    ClassNode* super = Resolver::ResolveSuperClass(node);
    if (super == NULL && node->has_super()) {
      // TODO(ajohnsen): Move to library loader.
      IdentifierNode* name = node->super()->AsIdentifier();
      Error(name->location(), "Cannot find class '%s'", name->value());
    }
    id = AddClass(node, super);
    CompiledClass* clazz = GetCompiledClass(id);
    int field_offset = 0;
    if (super != NULL) {
      EnqueueClass(super);
      field_offset = super->FieldCount();
    }
    IdentifierNode* class_name = node->name();
    // Mark is method for itself, and all implements.
    MarkIsSelector(clazz, class_name);
    List<TreeNode*> implements = node->implements();
    for (int i = 0; i < implements.length(); i++) {
      MarkIsSelector(clazz, implements[i]->AsIdentifier());
    }
    List<TreeNode*> declarations = node->declarations();
    for (int i = 0; i < declarations.length(); i++) {
      MethodNode* method = declarations[i]->AsMethod();
      VariableDeclarationStatementNode* field =
          declarations[i]->AsVariableDeclarationStatement();
      if (method != NULL) {
        if (method->modifiers().is_static()) continue;
        IdentifierNode* method_name = method->name()->AsIdentifier();
        // Skip constructors.
        if (method_name == NULL) {
          method_name = method->name()->AsDot()->name();
          clazz->AddConstructor(method_name->id(), method);
          continue;
        } else if (method_name->id() == class_name->id()) {
          clazz->AddConstructor(method_name->id(), method);
          continue;
        }
        // Skip abstract methods.
        if (!method->modifiers().is_native() &&
            !method->modifiers().is_external() &&
            method->body()->IsEmptyStatement()) {
          continue;
        }
        // If the method is a getter, trigger on 'dot' and not 'invoke'.
        if (method->modifiers().is_get() || method->modifiers().is_set()) {
          MarkForSelector(method);
        } else {
          MarkForInvokeSelector(method);

          // Create a 'getter' version to be used if the method is invoked
          // as a tearoff.
          Modifiers modifiers;
          modifiers.set_get();
          MethodNode* getter = new(zone()) MethodNode(
              modifiers,
              method->name(),
              List<VariableDeclarationNode*>(),
              List<TreeNode*>(),
              new(zone()) TearoffBodyNode(method));
          getter->set_owner(node);
          MarkForSelector(getter);
        }
      } else if (field != NULL) {
        List<VariableDeclarationNode*> vars = field->declarations();
        for (int j = 0; j < vars.length(); j++) {
          VariableDeclarationNode* var = vars[j];
          if (var->modifiers().is_static()) continue;
          var->set_index(field_offset);
          MarkForSelector(var);
          field_offset++;
        }
      }
    }
    if (!clazz->HasConstructors()) {
      MethodNode* implicit_constructor = new(zone()) MethodNode(
            Modifiers(),
            class_name,
            List<VariableDeclarationNode*>(),
            List<TreeNode*>(),
            NULL);
      implicit_constructor->set_owner(node);
      clazz->AddConstructor(class_name->id(), implicit_constructor);
    }
  }
  return id;
}

ClassNode* Compiler::EnqueueCoreClass(const char* class_name) {
  IdentifierNode* name = builder()->Canonicalize(class_name);
  LibraryElement* core = loader_.FetchLibrary("dart:core");
  if (core == NULL) return NULL;
  Scope* scope = core->library()->scope();
  ClassNode* clazz = LookupClass(scope, name);
  if (clazz != NULL) EnqueueClass(clazz);
  return clazz;
}

void Compiler::EnqueueSelector(IdentifierNode* node) {
  EnqueueSelectorId(node->id());
}

void Compiler::EnqueueSelectorId(int id) {
  SelectorX* selector = selectors_.Lookup(id);
  if (selector == NULL) {
    selectors_.Add(id, new(zone()) SelectorX(NULL));
  } else if (selector->is_done()) {
    // Do nothing.
  } else {
    TreeNode* current = selector->node();
    while (current != NULL) {
      TreeNode* next = NULL;
      MethodNode* method = current->AsMethod();
      VariableDeclarationNode* field = current->AsVariableDeclaration();
      if (method != NULL) {
        next = method->link();
        method->set_link(NULL);
        Enqueue(method);
      } else if (field != NULL) {
        next = field->link();
        field->set_link(NULL);
        int id = Enqueue(field);
        ASSERT(id < 0);
      }
      current = next;
    }
    selector->mark_done();
    ASSERT(selector->is_done());
  }
}

void Compiler::EnqueueInvokeSelector(IdentifierNode* node,
                                     int arity,
                                     List<IdentifierNode*> named_arguments) {
  int id = node->id();
  InvokeSelector* selector = invoke_selectors_.Lookup(id);
  if (selector == NULL) {
    selector = new(zone()) InvokeSelector(zone());
    invoke_selectors_.Add(id, selector);
  }
  IdentifierNode* named_id = BuildNamedArgumentId(node, named_arguments);
  List<MethodNode*> methods = selector->MarkArity(arity,
                                                  named_id,
                                                  named_arguments);
  for (int i = 0; i < methods.length(); i++) {
    Enqueue(methods[i]);
  }
}

void Compiler::CompileMethod(MethodNode* method,
                             Emitter* emitter) {
  if (Flags::IsOn("trace-compiler")) {
    // TODO(ajohnsen): Handle qualified constructor names.
    const char* name = method->name()->AsIdentifier()->value();
    TreeNode* owner = method->owner();
    if (owner != NULL && owner->IsClass()) {
      printf("Compiling %s.%s\n", owner->AsClass()->name()->value(), name);
    } else {
      printf("Compiling %s\n", name);
    }
  }

  if (method->modifiers().is_external()) {
    ASSERT(method->body()->IsEmptyStatement());
    switch (method->name()->AsIdentifier()->id()) {
      case Names::kNoSuchMethodTrampoline: {
        emitter->EnterNoSuchMethod();
        int id = Names::kNoSuchMethod;
        EnqueueSelectorId(id);
        emitter->InvokeMethod(id, 1);
        emitter->ExitNoSuchMethod();
        break;
      }

      case Names::kYield: {
        emitter->LoadParameter(0);
        emitter->ProcessYield();
        emitter->Return();
        break;
      }

      // This method is needed, if the identical is used through a tearoff.
      case Names::kIdentical: {
        emitter->LoadParameter(0);
        emitter->LoadParameter(1);
        emitter->Identical();
        emitter->Return();
        break;
      }

      default:
        FATAL1("Cannot deal with external method '%s'.",
               method->name()->AsIdentifier()->value());
    }
    return;
  }

  bool is_native = method->modifiers().is_native();
  if (is_native) {
    int arity = method->parameters().length();
    if (method->owner()->IsClass() && !method->modifiers().is_static()) {
      arity++;
    }
    IdentifierNode* method_name = method->name()->AsIdentifier();
    ClassNode* holder = method->owner()->AsClass();
    IdentifierNode* holder_name = (holder != NULL)
        ? holder->name()
        : builder()->Canonicalize("<none>");
    Native native = builder()->LookupNative(method_name, holder_name);
    if (native == Native::kPortSend) {
      emitter->InvokeNativeYield(arity, native);
    } else {
      emitter->InvokeNative(arity, native);
    }
    if (method->body()->IsEmptyStatement()) {
      emitter->Throw();
      return;
    }
  }

  ASSERT(method_ == NULL);
  method_ = method;
  Scope* scope = method->GetOwnerScope();

  ScopeResolver resolver(zone(), scope, this_name());
  resolver.ResolveMethod(method);

  CompileFunction(method->parameters(),
                  method->body(),
                  scope,
                  emitter,
                  !IsStaticContext(),
                  is_native);
  if (emitter->frame_size() != 0) {
    printf("Bad exit frame size: %i\n", emitter->frame_size());
    UNREACHABLE();
  }
  method_ = NULL;
}

void Compiler::CompileFunction(
    List<VariableDeclarationNode*> parameters,
    TreeNode* body,
    Scope* outer,
    Emitter* emitter,
    bool has_this,
    bool is_native) {
  Scope scope(zone(), parameters.length() + (has_this ? 1 : 0), outer);
  int stack_parameters = 0;

  ValueVisitor visitor(this, emitter, &scope);
  // Setters should store the value, so it can be returned later on.
  if (CurrentMethod()->modifiers().is_set()) {
    stack_parameters++;
    emitter->LoadParameter(has_this ? 1 : 0);
  }

  for (int i = 0; i < parameters.length(); i++) {
    VariableDeclarationNode* var = parameters[i];
    if (var->modifiers().is_this()) continue;
    int index = i;
    if (has_this) index++;
    if (var->entry()->IsCapturedByReference()) {
      DeclarationEntry* entry = var->entry();
      scope.Add(var->name(), entry);
      entry->set_index(emitter->frame_size());
      emitter->LoadParameter(index);
      emitter->AllocateBoxed();
      stack_parameters++;
    } else {
      FormalParameterEntry* entry = new(zone()) FormalParameterEntry(index);
      scope.Add(var->name(), entry);
    }
  }

  if (is_native) {
    Modifiers modifiers;
    modifiers.set_final();
    IdentifierNode* native_error_name = builder()->Canonicalize("error");
    VariableDeclarationNode* var = new(zone()) VariableDeclarationNode(
        native_error_name, NULL, modifiers);
    DeclarationEntry* entry = new(zone()) DeclarationEntry(var);
    scope.Add(var->name(), entry);
    entry->set_index(emitter->frame_size() - 1);
    var->set_entry(entry);
    stack_parameters++;
  }

  if (IsEmptyBody(body)) {
    visitor.LoadNull();
    visitor.EmitReturn();
  } else {
    body->Accept(&visitor);
    if (body->IsExpression()) {
      visitor.EmitReturn();
    } else if (!emitter->EndsWithReturn()) {
      visitor.LoadNull();
      visitor.EmitReturn();
    }
  }
  emitter->FrameSizeFix(-stack_parameters);
}

ValueVisitor::ValueVisitor(Compiler* compiler, Emitter* emitter, Scope* scope)
    : compiler_(compiler)
    , emitter_(emitter)
    , scope_(scope)
    , restore_labels_(compiler->zone())
    , exception_index_(-1)
    , name_id_(-1) {
}

void ValueVisitor::DoBlock(BlockNode* node) {
  Label done;
  PushRestoreLabel(&done, NULL, emitter()->frame_size(), true);
  DoStatements(node->statements());
  PopRestoreLabel();
  emitter()->BindRaw(&done);
}

void ValueVisitor::DoStatements(List<TreeNode*> statements) {
  Scope nested(scope()->zone(), 0, scope());
  scope_ = &nested;

  int old_size = emitter()->frame_size();

  for (int i = 0; i < statements.length(); i++) {
    statements[i]->Accept(this);
  }

  // TODO(ajohnsen): Add 'pop x' bytecode.
  while (emitter()->frame_size() > old_size) {
    emitter()->Pop();
  }

  scope_ = nested.outer();
}

void ValueVisitor::ImplicitScopeStatement(StatementNode* statement) {
  // If a single statement may introduce a new scope entry, be sure to wrap it
  // in a new scope and pop at end.
  if (statement->IsVariableDeclarationStatement() || statement->IsMethod()) {
    StackList<TreeNode*, 1> stack_statements;
    List<TreeNode*> statements = stack_statements.ToList();
    statements[0] = statement;
    DoStatements(statements);
    return;
  }

  statement->Accept(this);
}

void ValueVisitor::DoVariableDeclarationStatement(
    VariableDeclarationStatementNode* node) {
  List<VariableDeclarationNode*> declarations = node->declarations();
  // TODO(kasperl): Pre-introduce all the names in the scope.
  for (int i = 0; i < declarations.length(); i++) {
    declarations[i]->Accept(this);
  }
}

void ValueVisitor::DoVariableDeclaration(VariableDeclarationNode* node) {
  if (node->modifiers().is_const()) {
    scope()->AddDeclaration(node->name(), node);
    return;
  }
  if (node->has_initializer()) {
    node->value()->Accept(this);
  } else {
    LoadNull();
  }
  AddVariableDeclarationToScope(node);
}

void ValueVisitor::AddVariableDeclarationToScope(
    VariableDeclarationNode* node) {
  DeclarationEntry* entry = node->entry();
  ASSERT(entry != NULL);
  entry->set_index(emitter()->frame_size() - 1);
  if (entry->IsCapturedByReference()) {
    emitter()->AllocateBoxed();
  }
  int id = node->name()->id();
  if (scope()->LookupLocal(id) != NULL) {
    compiler()->Error(node->name()->location(),
                      "Declaration shadows another declaration");
  }
  scope()->Add(node->name(), entry);
}

void ValueVisitor::DoExpressionStatement(ExpressionStatementNode* node) {
  node->expression()->Accept(this);
  emitter()->Pop();
}

void ValueVisitor::DoEmptyStatement(EmptyStatementNode* node) {
  // Do nothing.
}

void ValueVisitor::DoIf(IfNode* node) {
  node->condition()->Accept(this);
  Label done, if_false;
  emitter()->BranchIfFalse(&if_false);
  PushRestoreLabel(&done, NULL, emitter()->frame_size(), true);
  ImplicitScopeStatement(node->if_true());
  if (node->has_else()) {
    emitter()->Branch(&done);
    emitter()->Bind(&if_false);
    ImplicitScopeStatement(node->if_false());
  } else {
    emitter()->Bind(&if_false);
  }
  PopRestoreLabel();
  emitter()->Bind(&done);
}

void ValueVisitor::DoWhile(WhileNode* node) {
  Label loop, done;
  emitter()->Bind(&loop);
  node->condition()->Accept(this);
  emitter()->BranchIfFalse(&done);
  PushRestoreLabel(&done, &loop, emitter()->frame_size());
  ImplicitScopeStatement(node->body());
  PopRestoreLabel();
  emitter()->Branch(&loop);
  emitter()->Bind(&done);
}

void ValueVisitor::DoFor(ForNode* node) {
  Scope nested(scope()->zone(), 0, scope());
  scope_ = &nested;

  Label loop, done, continue_label;
  node->initializer()->Accept(this);
  emitter()->Bind(&loop);
  if (node->has_condition()) {
    node->condition()->Accept(this);
  } else {
    LoadBoolean(true);
  }
  emitter()->BranchIfFalse(&done);
  PushRestoreLabel(&done, &continue_label, emitter()->frame_size());
  ImplicitScopeStatement(node->body());
  PopRestoreLabel();
  emitter()->Bind(&continue_label);
  List<TreeNode*> increments = node->increments();
  for (int i = 0; i < increments.length(); i++) {
    increments[i]->Accept(this);
    emitter()->Pop();
  }
  emitter()->Branch(&loop);
  emitter()->Bind(&done);

  scope_ = nested.outer();
}

void ValueVisitor::DoForIn(ForInNode* node) {
  Label loop, done;

  Scope local_scope(scope()->zone(), 0, scope());
  scope_ = &local_scope;

  int iterator_index = emitter()->frame_size();

  // Push iterator on the stack
  node->expression()->Accept(this);
  IdentifierNode* iterator = builder()->Canonicalize("iterator");
  compiler()->EnqueueSelector(iterator);
  emitter()->InvokeGetter(iterator);

  emitter()->Bind(&loop);

  // Move next.
  emitter()->LoadLocal(iterator_index);
  IdentifierNode* move_next = builder()->Canonicalize("moveNext");
  compiler()->EnqueueInvokeSelector(move_next, 0);
  emitter()->InvokeMethod(move_next, 0);
  emitter()->BranchIfFalse(&done);

  Scope nested(scope()->zone(), 0, scope());
  scope_ = &nested;

  int var_offset = emitter()->frame_size();
  node->var()->Accept(this);

  // Get 'current' and store in the local var.
  emitter()->LoadLocal(iterator_index);
  IdentifierNode* current = builder()->Canonicalize("current");
  compiler()->EnqueueSelector(current);
  emitter()->InvokeGetter(current);
  emitter()->StoreLocal(var_offset);
  emitter()->Pop();

  PushRestoreLabel(&done, &loop, emitter()->frame_size());
  ImplicitScopeStatement(node->body());
  PopRestoreLabel();

  // Pop the var.
  emitter()->Pop();

  scope_ = nested.outer();

  emitter()->Branch(&loop);
  emitter()->Bind(&done);

  // Pop iterator.
  emitter()->Pop();

  scope_ = local_scope.outer();
  ASSERT(emitter()->frame_size() == iterator_index);
}

void ValueVisitor::DoDoWhile(DoWhileNode* node) {
  Label done, skip, loop;
  emitter()->Bind(&loop);
  PushRestoreLabel(&done, &skip, emitter()->frame_size());
  ImplicitScopeStatement(node->body());
  PopRestoreLabel();
  emitter()->Bind(&skip);
  node->condition()->Accept(this);
  emitter()->BranchIfTrue(&loop);
  emitter()->Bind(&done);
}

void ValueVisitor::DoSwitch(SwitchNode* node) {
  Label start, break_label, done;

  node->value()->Accept(this);

  emitter()->Branch(&start);
  emitter()->Bind(&break_label);
  emitter()->Branch(&done);
  emitter()->Bind(&start);

  List<TreeNode*> cases = node->cases();
  for (int i = 0; i < cases.length(); i++) {
    Label skip;
    CaseNode* case_node = cases[i]->AsCase();
    emitter()->Dup();
    case_node->condition()->Accept(this);
    InvokeOperator(kEQ, 1);
    emitter()->BranchIfFalse(&skip);

    PushRestoreLabel(&break_label, NULL, emitter()->frame_size());
    DoStatements(case_node->statements());
    PopRestoreLabel();

    emitter()->Branch(&break_label);
    emitter()->Bind(&skip);
  }

  PushRestoreLabel(&break_label, NULL, emitter()->frame_size());
  DoStatements(node->default_statements());
  PopRestoreLabel();

  emitter()->Bind(&done);
  // Pop the value.
  emitter()->Pop();
}

void ValueVisitor::DoLabelledStatement(LabelledStatementNode* node) {
  SetNamedRestoreLabel(node->name()->id());
  ImplicitScopeStatement(node->statement());
  SetNamedRestoreLabel(-1);
}

void ValueVisitor::DoTry(TryNode* node) {
  bool has_finally = node->has_finally_block();
  Label catch_start, end, finally, finally_return_label;
  // We set up scope since we inject an artificial 'local' where we can
  // store the exception between try-catch-finally.
  // The exception - null when uncaught.
  LoadNull();

  int start = emitter()->position();

  if (has_finally) {
    PushFinallyRestoreLabel(&finally,
                            &finally_return_label,
                            emitter()->frame_size());
  }
  node->block()->Accept(this);
  emitter()->Branch(&end);
  emitter()->AddFrameRange(start, emitter()->position());

  int old_exception_index = exception_index_;
  exception_index_ = emitter()->frame_size() - 1;

  emitter()->Bind(&catch_start);
  int catch_start_position = emitter()->position();

  List<TreeNode*> catches = node->catches();
  for (int i = 0; i < catches.length(); i++) {
    CatchNode* catch_node = catches[i]->AsCatch();
    if (catch_node->has_type()) {
      emitter()->Dup();
      IsCheck(catch_node->type()->AsIdentifier());
      Label not_match;
      emitter()->BranchIfFalse(&not_match);
      catch_node->Accept(this);
      emitter()->Branch(&end);
      emitter()->Bind(&not_match);
    } else {
      catch_node->Accept(this);
      emitter()->Branch(&end);
      // No need to visit other nodes.
      break;
    }
  }

  if (has_finally) {
    if (!catches.is_empty()) {
      // If we have a finally block, add another frame around catch-clauses, to
      // ensure we call finally.
      emitter()->AddFrameRange(catch_start_position, emitter()->position());
    }
    PopRestoreLabel();
    emitter()->SubroutineCall(&finally, &finally_return_label);
  }

  // The exception was not cought - re-throw.
  emitter()->Throw();

  emitter()->Bind(&end);

  if (has_finally) {
    Label done;
    emitter()->SubroutineCall(&finally, &finally_return_label);
    emitter()->Branch(&done);

    // Emit the actual finally block.
    emitter()->Bind(&finally);
    emitter()->FrameSizeFix(1);
    node->finally_block()->Accept(this);
    emitter()->SubroutineReturn(&finally_return_label);

    emitter()->Bind(&done);
  }

  emitter()->Pop();

  exception_index_ = old_exception_index;
}

void ValueVisitor::DoCatch(CatchNode* node) {
  Scope nested(scope()->zone(), 0, scope());
  scope_ = &nested;

  if (node->has_exception_name()) {
    emitter()->LoadLocal(exception_index_);
    AddVariableDeclarationToScope(node->exception_name());
    if (node->has_stack_trace_name()) {
      LoadNull();
      AddVariableDeclarationToScope(node->stack_trace_name());
    }
  }

  node->block()->Accept(this);

  if (node->has_exception_name()) {
    emitter()->Pop();
    if (node->has_stack_trace_name()) {
      emitter()->Pop();
    }
  }

  scope_ = nested.outer();
}

void ValueVisitor::DoRethrow(RethrowNode* node) {
  if (exception_index_ == -1) {
    compiler()->Error(Location(), "Rethrow is not in catch block");
  }

  emitter()->LoadLocal(exception_index_);
  emitter()->Throw();
}

void ValueVisitor::DoReturn(ReturnNode* node) {
  if (node->has_expression()) {
    node->value()->Accept(this);
  } else {
    LoadNull();
  }
  EmitReturn();
}

void ValueVisitor::EmitReturn() {
  int stack_size = emitter()->frame_size();
  for (int i = restore_labels_.length() - 1; i >= 0; i--) {
    RestoreLabel restore = restore_labels_.Get(i);
    if (restore.finally_label != NULL) {
      emitter()->StoreLocal(restore.stack_size - 1);
      PopTo(emitter()->frame_size(), restore.stack_size, false);
      emitter()->SubroutineCall(restore.finally_label,
                                restore.finally_return_label);
      emitter()->LoadStackLocal(0);
    }
  }

  // Setters has the original value stored at position 0.
  if (compiler()->CurrentMethod()->modifiers().is_set()) {
    emitter()->Pop();
    emitter()->LoadLocal(0);
  }

  emitter()->Return();
  emitter()->FrameSizeFix(stack_size - emitter()->frame_size() - 1);
}

int ValueVisitor::PopTo(int stack_size,
                        int new_stack_size,
                        bool pop_transparent) {
  int pop_count = stack_size - new_stack_size;
  ASSERT(pop_count >= 0);
  for (int i = 0; i < pop_count; i++) {
    emitter()->Pop();
  }
  if (pop_transparent) emitter()->FrameSizeFix(pop_count);
  return new_stack_size;
}

void ValueVisitor::DoThis(ThisNode* node) {
  ScopeEntry* entry = scope()->Lookup(compiler()->this_name());
  if (entry != NULL) {
    LoadScopeEntry(entry);
  } else {
    emitter()->LoadThis();
  }
}

void ValueVisitor::DoSuper(SuperNode* node) {
  UNREACHABLE();
}

void ValueVisitor::DoNull(NullNode* node) {
  LoadNull();
}

void ValueVisitor::DoParenthesized(ParenthesizedNode* node) {
  node->expression()->Accept(this);
}

void ValueVisitor::DoAssign(AssignNode* node) {
  ExpressionNode* target = node->target();
  ExpressionNode* value = node->value();
  Token token = node->token();
  if (token == kASSIGN) {
    StoreExpressionNode(target, value);
  } else {
    CompoundAssignNode pre(token, target, value);
    StoreExpressionNode(target, &pre);
  }
}

void ValueVisitor::DoConditional(ConditionalNode* node) {
  LoadNull();
  node->condition()->Accept(this);
  Label if_false, done;
  emitter()->BranchIfFalse(&if_false);
  emitter()->Pop();
  node->if_true()->Accept(this);
  emitter()->Branch(&done);
  emitter()->Bind(&if_false);
  emitter()->Pop();
  node->if_false()->Accept(this);
  emitter()->Bind(&done);
}

void ValueVisitor::DoUnary(UnaryNode* node) {
  ExpressionNode* expression = node->expression();
  Token token = node->token();
  if (token == kINCREMENT || token == kDECREMENT) {
    bool prefix = node->prefix();
    int frame_pos = -1;
    if (!prefix) {
      frame_pos = emitter()->frame_size();
      LoadExpressionNode(expression);
    }
    AddOneNode add(frame_pos, expression, token == kDECREMENT);
    StoreExpressionNode(expression, &add);
    if (!prefix) {
      emitter()->Pop();
    }
    return;
  }
  if (token == kSUB) {
    IdentifierNode* name = builder()->Canonicalize("unary-");
    InvokeMethod(expression, name, List<ExpressionNode*>());
    return;
  }
  expression->Accept(this);
  if (token == kNOT) {
    emitter()->Negate();
    return;
  }
  InvokeOperator(token, 0);
}

void ValueVisitor::DoBinary(BinaryNode* node) {
  Token token = node->token();
  switch (token) {
    case kAND: {
      LoadBoolean(false);
      Label if_false;
      node->left()->Accept(this);
      emitter()->BranchIfFalse(&if_false);
      node->right()->Accept(this);
      emitter()->BranchIfFalse(&if_false);
      emitter()->Pop();
      LoadBoolean(true);
      emitter()->Bind(&if_false);
      break;
    }

    case kOR: {
      LoadBoolean(true);
      Label if_true;
      node->left()->Accept(this);
      emitter()->BranchIfTrue(&if_true);
      node->right()->Accept(this);
      emitter()->BranchIfTrue(&if_true);
      emitter()->Pop();
      LoadBoolean(false);
      emitter()->Bind(&if_true);
      break;
    }

    case kNE:
    case kEQ: {
      node->left()->Accept(this);
      node->right()->Accept(this);
      if (node->left()->IsNull() || node->right()->IsNull()) {
        emitter()->Identical();
      } else {
        IdentifierNode* name = builder()->OperatorName(kEQ);
        compiler()->EnqueueInvokeSelector(name, 1);
        emitter()->InvokeMethod(name, 1);
      }
      if (token == kNE) emitter()->Negate();
      break;
    }

    default: {
      node->left()->Accept(this);
      node->right()->Accept(this);
      IdentifierNode* name = builder()->OperatorName(token);
      compiler()->EnqueueInvokeSelector(name, 1);
      emitter()->InvokeMethod(name, 1);
    }
  }
}

void ValueVisitor::DoDot(DotNode* node) {
  LoadExpressionNode(node);
}

void ValueVisitor::DoInvoke(InvokeNode* node) {
  ExpressionNode* target = node->target();
  List<ExpressionNode*> arguments = node->arguments();
  List<IdentifierNode*> named_arguments = node->named_arguments();

  DotNode* dot = target->AsDot();
  if (dot != NULL) {
    TreeNode* target = Resolver::ResolveDot(dot, scope());
    if (target != NULL) {
      MethodNode* method = target->AsMethod();
      if (method != NULL) {
        if (method->owner()->IsLibrary() || method->modifiers().is_static()) {
          InvokeStatic(method, arguments, named_arguments);
        } else {
          HandleUnresolved(dot->name());
        }
        return;
      }
      VariableDeclarationNode* var = target->AsVariableDeclaration();
      if (var != NULL) {
        if (var->modifiers().is_static()) {
          // TODO(ajohnsen): Use e.g. LoadVariableDeclarationNode to avoid
          // double scope resolve of 'dot'.
          InvokeMethod(dot,
                       compiler()->call_name(),
                       arguments,
                       named_arguments);
        } else {
          HandleUnresolved(dot->name());
        }
        return;
      }

      // TODO(ajohnsen): What if target is static?
      InvokeMethod(dot, compiler()->call_name(), arguments, named_arguments);
      return;
    }
    if (dot->object()->IsSuper()) {
      MethodNode* method = SuperLookup(dot->name())->AsMethod();
      InvokeStatic(method, arguments, named_arguments);
      return;
    }
    target = Resolver::Resolve(dot->object(), scope());
    // If the target is a class, we failed to do a static method lookup.
    if (target != NULL && target->IsClass()) {
      HandleUnresolved(dot->name());
      return;
    }
    InvokeMethod(dot->object(), dot->name(), arguments, named_arguments);
    return;
  }

  IdentifierNode* identifier = target->AsIdentifier();
  if (identifier != NULL) {
    ScopeEntry* entry = scope()->Lookup(identifier);
    if (entry == NULL) {
      if (compiler()->IsStaticContext()) {
        HandleUnresolved(identifier);
      } else {
        ThisNode this_node;
        InvokeMethod(&this_node, identifier, arguments, named_arguments);
      }
      return;
    } else if (entry->IsMember()) {
      MemberEntry* member = entry->AsMember();
      if (member->has_member()) {
        MethodNode* method = member->member()->AsMethod();
        if (method != NULL && !method->modifiers().is_get()) {
          if (method->owner()->IsClass() && !method->modifiers().is_static()) {
            if (compiler()->IsStaticContext()) {
              HandleUnresolved(identifier);
            } else {
              ThisNode this_node;
              InvokeMethod(&this_node, identifier, arguments, named_arguments);
            }
          } else {
            InvokeStatic(method, arguments, named_arguments);
          }
          return;
        }
      }
    }
  }
  InvokeMethod(target, compiler()->call_name(), arguments, named_arguments);
}

void ValueVisitor::DoIndex(IndexNode* node) {
  LoadExpressionNode(node);
}

void ValueVisitor::DoCascadeReceiver(CascadeReceiverNode* node) {
  node->object()->Accept(this);
  emitter()->Dup();
}

void ValueVisitor::DoCascade(CascadeNode* node) {
  node->expression()->Accept(this);
  emitter()->Pop();
}

void ValueVisitor::DoNew(NewNode* node) {
  if (node->is_const()) {
    LoadConst(node, scope());
    return;
  }
  IdentifierNode* class_name = NULL;
  IdentifierNode* constructor_name = NULL;
  InvokeNode* invoke = node->invoke();
  ExpressionNode* target = invoke->target();
  ClassNode* class_node = NULL;
  TreeNode* resolved_node = Resolver::Resolve(target, scope());
  DotNode* dot = target->AsDot();
  if ((resolved_node == NULL || !resolved_node->IsClass()) && dot != NULL) {
    resolved_node = Resolver::Resolve(dot->object(), scope());
    constructor_name = dot->name();
    class_name = GetLastIdentifier(dot->object());
  } else {
    constructor_name = class_name = GetLastIdentifier(target);
  }
  if (resolved_node == NULL) {
    HandleUnresolved(class_name);
    return;
  }
  if (!resolved_node->IsClass()) {
    compiler()->Error(class_name->location(),
                      "'%s' is not a class",
                      class_name);
  }
  class_node = resolved_node->AsClass();
  List<ExpressionNode*> arguments = invoke->arguments();
  int class_id = compiler()->EnqueueClass(class_node);
  CompiledClass* clazz = compiler()->GetCompiledClass(class_id);
  MethodNode* constructor = clazz->LookupConstructor(constructor_name->id());
  if (constructor == NULL) {
    LoadArguments(arguments);
    HandleUnresolved(constructor_name);
    return;
  }
  InvokeConstructor(class_node, constructor, arguments,
                    invoke->named_arguments());
}

void ValueVisitor::DoMethod(MethodNode* node) {
  IdentifierNode* id = node->name()->AsIdentifier();
  DoClosure(id,
            node->captured(),
            node->parameters(),
            node->body());
  DeclarationEntry* entry = new(zone()) DeclarationEntry(NULL);
  VariableDeclarationNode var(id, NULL, Modifiers());
  var.set_entry(entry);
  AddVariableDeclarationToScope(&var);
}

void ValueVisitor::DoFunctionExpression(FunctionExpressionNode* node) {
  MethodNode* method = compiler()->CurrentMethod();
  IdentifierNode* name = method->name()->AsIdentifier();
  if (name == NULL) name = method->name()->AsDot()->name();
  List<VariableDeclarationNode*> captured = node->captured();

  DoClosure(name, captured, node->parameters(), node->body());
}

void ValueVisitor::DoClosure(IdentifierNode* name,
                             List<VariableDeclarationNode*> captured,
                             List<VariableDeclarationNode*> parameters,
                             TreeNode* body) {
  ASSERT(name != NULL);
  // Create members for class.
  ListBuilder<TreeNode*, 2> members(zone());
  // Add captured variables to the class.
  VariableDeclarationStatementNode* statement = new(zone())
      VariableDeclarationStatementNode(Modifiers(), captured);
  members.Add(statement);
  // Add the 'call' method.
  IdentifierNode* call = compiler()->call_name();
  StubMethodNode* call_method = new(zone()) StubMethodNode(call, parameters);
  members.Add(call_method);
  ClassNode* clazz = new(zone()) ClassNode(
      false, name, NULL, List<TreeNode*>(), List<TreeNode*>(),
      members.ToList());
  // Create a copy of 'scope()' for the class, as the current scope may be
  // stack allocated.
  Scope* class_scope = new(zone()) Scope(zone(), 0, NULL);
  Scope* current = scope();
  while (current != NULL) {
    class_scope->AddAll(current);
    current = current->outer();
  }
  clazz->set_scope(class_scope);
  call_method->set_owner(clazz);

  int self = -1;
  for (int i = 0; i < captured.length(); i++) {
    VariableDeclarationNode* var = captured[i];
    if (var->name() == name) {
      // TODO(ajohnsen): When shadowing, can this go wrong?
      ASSERT(self == -1);
      self = i;
      LoadNull();
      continue;
    }
    int index = var->entry()->index();
    // Load as local.
    if (index < 0) {
      DoThis(NULL);
    } else {
      emitter()->LoadLocal(index);
    }
  }
  int class_id = compiler()->AddClass(clazz, NULL);
  emitter()->Allocate(class_id, captured.length());

  if (self >= 0) {
    emitter()->Dup();
    emitter()->StoreField(self);
  }

  Scope* owner_scope = compiler()->CurrentMethod()->GetOwnerScope();
  Scope inner_scope(zone(), 0, owner_scope);
  Emitter nested(zone(), 1 + parameters.length());
  List<int> old_indices = List<int>::New(zone(), captured.length());
  for (int i = 0; i < captured.length(); i++) {
    VariableDeclarationNode* var = captured[i];
    DeclarationEntry* entry = var->entry();
    old_indices[i] = entry->index();
    entry->set_index(i);
    inner_scope.Add(var->name(), entry);
    nested.LoadThis();
    nested.LoadField(i);
  }
  compiler()->CompileFunction(parameters,
                              body,
                              &inner_scope,
                              &nested,
                              true,
                              false);
  if (nested.frame_size() != captured.length()) {
    printf("Bad exit frame size: %i\n", nested.frame_size());
    UNREACHABLE();
  }
  // Restore old indices.
  for (int i = 0; i < captured.length(); i++) {
    VariableDeclarationNode* var = captured[i];
    DeclarationEntry* entry = var->entry();
    entry->set_index(old_indices[i]);
  }
  call_method->set_code(nested.GetCode());
  compiler()->AddStub(call_method);
}

void ValueVisitor::DoThrow(ThrowNode* node) {
  node->expression()->Accept(this);
  emitter()->Throw();
}

void ValueVisitor::DoBreak(BreakNode* node) {
  int name_id = node->has_label() ? node->label()->id() : -1;
  int stack_size = emitter()->frame_size();
  for (int i = restore_labels_.length() - 1; i >= 0; i--) {
    RestoreLabel restore = restore_labels_.Get(i);
    if (restore.finally_label != NULL) {
      stack_size = PopTo(stack_size, restore.stack_size);
      emitter()->SubroutineCall(restore.finally_label,
                                restore.finally_return_label);
    } else if (restore.break_label != NULL) {
      if ((name_id == -1 && !restore.label_only) ||
          (name_id != -1 && restore.name_id == name_id)) {
        stack_size = PopTo(stack_size, restore.stack_size);
        emitter()->Branch(restore.break_label);
        emitter()->FrameSize();
        return;
      }
    }
  }
  compiler()->Error(Location(), "Unmatched break statement");
}

void ValueVisitor::DoContinue(ContinueNode* node) {
  int name_id = node->has_label() ? node->label()->id() : -1;
  int stack_size = emitter()->frame_size();
  for (int i = restore_labels_.length() - 1; i >= 0; i--) {
    RestoreLabel restore = restore_labels_.Get(i);
    if (restore.finally_label != NULL) {
      stack_size = PopTo(stack_size, restore.stack_size);
      emitter()->SubroutineCall(restore.finally_label,
                                restore.finally_return_label);
    } else if (restore.continue_label != NULL) {
      if ((name_id == -1 && !restore.label_only) ||
          (name_id != -1 && restore.name_id == name_id)) {
        stack_size = PopTo(stack_size, restore.stack_size);
        emitter()->Branch(restore.continue_label);
        emitter()->FrameSize();
        return;
      }
    }
  }
  compiler()->Error(Location(), "Unmatched continue statement");
}

void ValueVisitor::DoIs(IsNode* node) {
  node->object()->Accept(this);
  IdentifierNode* name = node->type()->AsIdentifier();
  IsCheck(name);
  if (node->is_not()) {
    emitter()->Negate();
  }
}

void ValueVisitor::IsCheck(IdentifierNode* name) {
  IdentifierNode* is_test = compiler()->EnqueueIsSelector(name);
  emitter()->InvokeTest(is_test);
}

void ValueVisitor::DoAs(AsNode* node) {
  Label done;
  node->object()->Accept(this);
  // If value is null the result is null.
  emitter()->Dup();
  LoadNull();
  InvokeOperator(kEQ, 1);
  emitter()->BranchIfTrue(&done);
  // If is check passes the result is the object.
  emitter()->Dup();
  IdentifierNode* name = node->type()->AsIdentifier();
  IsCheck(name);
  emitter()->BranchIfTrue(&done);
  // TODO(ager): This throws the object tested. It should throw a
  // CastError.
  emitter()->Throw();
  emitter()->Bind(&done);
}

void ValueVisitor::DoIdentifier(IdentifierNode* node) {
  LoadExpressionNode(node);
}

void ValueVisitor::DoStringInterpolation(StringInterpolationNode* node) {
  IdentifierNode* to_string = builder()->Canonicalize("toString");
  compiler()->EnqueueInvokeSelector(to_string, 0);
  IdentifierNode* plus = builder()->OperatorName(kADD);
  compiler()->EnqueueInvokeSelector(plus, 1);
  List<LiteralStringNode*> strings = node->strings();
  List<ExpressionNode*> expressions = node->expressions();
  strings[0]->Accept(this);
  for (int i = 0; i < expressions.length(); i++) {
    expressions[i]->Accept(this);
    emitter()->InvokeMethod(to_string, 0);
    emitter()->InvokeMethod(plus, 1);
    strings[i + 1]->Accept(this);
    emitter()->InvokeMethod(plus, 1);
  }
}

void ValueVisitor::DoLiteralInteger(LiteralIntegerNode* node) {
  if (node->IsLarge()) {
    LoadConst(node, NULL);
  } else {
    emitter()->LoadInteger(node->value());
  }
}

void ValueVisitor::DoLiteralDouble(LiteralDoubleNode* node) {
  LoadConst(node, scope());
}

void ValueVisitor::DoLiteralString(LiteralStringNode* node) {
  compiler()->EnqueueCoreClass("String");
  LoadConst(node, scope());
}

void ValueVisitor::DoLiteralBoolean(LiteralBooleanNode* node) {
  LoadConst(node, scope());
}

void ValueVisitor::DoLiteralList(LiteralListNode* node) {
  if (node->is_const()) {
    LoadConst(node, scope());
    return;
  }
  ClassNode* class_node = compiler()->EnqueueCoreClass("_GrowableList");
  int class_id = class_node->id();
  CompiledClass* clazz = compiler()->GetCompiledClass(class_id);

  MethodNode* constructor = clazz->LookupConstructor(class_node->name()->id());
  InvokeConstructor(class_node, constructor, List<ExpressionNode*>(),
                    List<IdentifierNode*>());

  IdentifierNode* add = builder()->Canonicalize("add");
  compiler()->EnqueueInvokeSelector(add, 1);

  List<ExpressionNode*> elements = node->elements();
  for (int i = 0; i < elements.length(); i++) {
    emitter()->Dup();
    elements[i]->Accept(this);
    emitter()->InvokeMethod(add, 1);
    emitter()->Pop();
  }
}

void ValueVisitor::DoLiteralMap(LiteralMapNode* node) {
  ClassNode* class_node = compiler()->EnqueueCoreClass("Map");
  if (node->is_const()) {
    LoadConst(node, scope());
    return;
  }
  int class_id = class_node->id();
  CompiledClass* clazz = compiler()->GetCompiledClass(class_id);

  MethodNode* constructor = clazz->LookupConstructor(class_node->name()->id());
  InvokeConstructor(class_node, constructor, List<ExpressionNode*>(),
                    List<IdentifierNode*>());

  List<ExpressionNode*> keys = node->keys();
  List<ExpressionNode*> values = node->values();
  for (int i = 0; i < keys.length(); i++) {
    emitter()->Dup();
    keys[i]->Accept(this);
    values[i]->Accept(this);
    InvokeOperator(kASSIGN_INDEX, 2);
    emitter()->Pop();
  }
}

void ValueVisitor::DoAddOneNode(AddOneNode* node) {
  int frame_pos = node->frame_pos();
  if (frame_pos < 0) {
    LoadExpressionNode(node->expression());
  } else {
    emitter()->LoadLocal(frame_pos);
  }
  IdentifierNode* op = builder()->OperatorName(node->negative() ? kSUB : kADD);
  emitter()->LoadInteger(1);
  compiler()->EnqueueInvokeSelector(op, 1);
  emitter()->InvokeMethod(op, 1);
}

void ValueVisitor::DoCompoundAssignNode(CompoundAssignNode* node) {
  Token token = kEOF;
  switch (node->token()) {
    case kASSIGN_OR: token = kBIT_OR; break;
    case kASSIGN_XOR: token = kBIT_XOR; break;
    case kASSIGN_AND: token = kBIT_AND; break;
    case kASSIGN_SHL: token = kSHL; break;
    case kASSIGN_SHR: token = kSHR; break;
    case kASSIGN_ADD: token = kADD; break;
    case kASSIGN_SUB: token = kSUB; break;
    case kASSIGN_MUL: token = kMUL; break;
    case kASSIGN_TRUNCDIV: token = kTRUNCDIV; break;
    case kASSIGN_DIV: token = kDIV; break;
    case kASSIGN_MOD: token = kMOD; break;
    default:
      UNIMPLEMENTED();
  }
  LoadExpressionNode(node->target());
  node->value()->Accept(this);
  InvokeOperator(token, 1);
}

void ValueVisitor::DoTearoffBody(TearoffBodyNode* node) {
  MethodNode* method = node->method();
  compiler()->LoadMethod(method, this);
  emitter()->Return();
}

void ValueVisitor::StoreExpressionNode(ExpressionNode* node,
                                       ExpressionNode* value) {
  ScopeEntry* entry = Resolver::ResolveEntry(node, scope());
  if (entry != NULL) {
    StoreScopeEntry(entry, value);
    return;
  }

  IdentifierNode* id = node->AsIdentifier();
  if (id != NULL) {
    // Look in super classes.
    TreeNode* member = SuperLookup(id);
    StoreVariableDeclaration(member->AsVariableDeclaration(), value);
    return;
  }

  DotNode* dot = node->AsDot();
  if (dot != NULL) {
    TreeNode* object = dot->object();
    IdentifierNode* name = dot->name();
    if (object->IsSuper()) {
      TreeNode* member = SuperLookup(name);
      StoreVariableDeclaration(member->AsVariableDeclaration(), value);
      return;
    }
    object->Accept(this);
    value->Accept(this);
    compiler()->EnqueueSelector(name);
    emitter()->InvokeSetter(name);
    return;
  }

  IndexNode* index = node->AsIndex();
  if (index != NULL) {
    TreeNode* target = index->target();
    if (target->IsSuper()) {
      IdentifierNode* name = builder()->OperatorName(kASSIGN_INDEX);
      MethodNode* method = SuperLookup(name)->AsMethod();
      List<ExpressionNode*> arguments =
          List<ExpressionNode*>::New(zone(), 2);
      arguments[0] = index->key();
      arguments[1] = value;
      InvokeStatic(method, arguments, List<IdentifierNode*>());
      return;
    }
    index->target()->Accept(this);
    index->key()->Accept(this);
    value->Accept(this);
    InvokeOperator(kASSIGN_INDEX, 2);
    return;
  }

  compiler()->Error(node->location(), "Expression is not assignable");
}

void ValueVisitor::StoreScopeEntry(ScopeEntry* entry, ExpressionNode* value) {
  if (entry == NULL || value == NULL) UNIMPLEMENTED();
  if (entry->IsFormalParameter()) {
    value->Accept(this);
    FormalParameterEntry* parameter = entry->AsFormalParameter();
    int index = parameter->index();
    emitter()->StoreParameter(index);
  } else if (entry->IsMember()) {
    MemberEntry* member = entry->AsMember();
    if (member->has_setter()) {
      MethodNode* setter = member->setter();
      if (!setter->modifiers().is_static() && setter->owner()->IsClass()) {
        IdentifierNode* name = member->name();
        compiler()->EnqueueSelector(name);
        DoThis(NULL);
        value->Accept(this);
        emitter()->InvokeSetter(name);
      } else {
        List<ExpressionNode*> arguments =
            List<ExpressionNode*>::New(zone(), 1);
        arguments[0] = value;
        InvokeStatic(setter, arguments, List<IdentifierNode*>());
      }
    } else {
      TreeNode* node = member->member();
      if (VariableDeclarationNode* var = node->AsVariableDeclaration()) {
        StoreVariableDeclaration(var, value);
        return;
      }
      HandleUnresolved(member->name());
    }
  } else if (entry->IsDeclaration()) {
    DeclarationEntry* declaration = entry->AsDeclaration();
    int index = declaration->index();
    ASSERT(index >= 0);
    value->Accept(this);
    if (declaration->IsCapturedByReference()) {
      emitter()->StoreBoxed(index);
    } else {
      emitter()->StoreLocal(index);
    }
  } else {
    UNIMPLEMENTED();
  }
}

void ValueVisitor::StoreVariableDeclaration(VariableDeclarationNode* node,
                                            ExpressionNode* value) {
  if (node == NULL || value == NULL) UNIMPLEMENTED();
  int id = compiler()->Enqueue(node);
  if (id >= 0) {
    value->Accept(this);
    emitter()->StoreStatic(id);
  } else if (!compiler()->IsStaticContext()) {
    IdentifierNode* name = node->name();
    compiler()->EnqueueSelector(name);
    DoThis(NULL);
    value->Accept(this);
    emitter()->InvokeSetter(name);
  } else {
    HandleUnresolved(node->name());
  }
}

void ValueVisitor::LoadExpressionNode(ExpressionNode* node) {
  ScopeEntry* entry = Resolver::ResolveEntry(node, scope());
  if (entry != NULL) {
    LoadScopeEntry(entry);
    return;
  }

  IdentifierNode* id = node->AsIdentifier();
  if (id != NULL) {
    TreeNode* member = SuperLookup(id, /* report */ false);
    if (member != NULL && member->IsVariableDeclaration()) {
      LoadVariableDeclaration(member->AsVariableDeclaration());
    } else if (!compiler()->IsStaticContext()) {
      DoThis(NULL);
      compiler()->EnqueueSelector(id);
      emitter()->InvokeGetter(id);
    } else {
      HandleUnresolved(id);
    }
    return;
  }

  DotNode* dot = node->AsDot();
  if (dot != NULL) {
    TreeNode* object = dot->object();
    IdentifierNode* name = dot->name();
    if (object->IsSuper()) {
      TreeNode* member = SuperLookup(name);
      VariableDeclarationNode* var = member->AsVariableDeclaration();
      DoThis(NULL);
      int index = var->index();
      int method_id = compiler()->GetFieldGetter(index);
      emitter()->InvokeStatic(1, method_id);
      return;
    }
    object->Accept(this);
    compiler()->EnqueueSelector(name);
    emitter()->InvokeGetter(name);
    return;
  }

  IndexNode* index = node->AsIndex();
  if (index != NULL) {
    TreeNode* target = index->target();
    if (target->IsSuper()) {
      IdentifierNode* name = builder()->OperatorName(kINDEX);
      MethodNode* method = SuperLookup(name)->AsMethod();
      List<ExpressionNode*> arguments =
          List<ExpressionNode*>::New(zone(), 1);
      arguments[0] = index->key();
      InvokeStatic(method, arguments, List<IdentifierNode*>());
      return;
    }
    index->target()->Accept(this);
    index->key()->Accept(this);
    InvokeOperator(kINDEX, 1);
    return;
  }

  ParenthesizedNode* parenthesized = node->AsParenthesized();
  if (parenthesized != NULL) {
    LoadExpressionNode(parenthesized->expression());
    return;
  }

  compiler()->Error(node->location(), "Cannot load value of expression");
}

void ValueVisitor::LoadScopeEntry(ScopeEntry* entry) {
  if (entry == NULL) UNIMPLEMENTED();
  if (entry->IsFormalParameter()) {
    FormalParameterEntry* parameter = entry->AsFormalParameter();
    int index = parameter->index();
    emitter()->LoadParameter(index);
  } else if (entry->IsMember()) {
    MemberEntry* member = entry->AsMember();
    if (member->has_member()) {
      TreeNode* node = member->member();
      VariableDeclarationNode* var = node->AsVariableDeclaration();
      if (var != NULL) {
        LoadVariableDeclaration(var);
        return;
      }
      MethodNode* method = node->AsMethod();
      if (method != NULL) {
        if (method->modifiers().is_get()) {
          if (!method->modifiers().is_static() && method->owner()->IsClass()) {
            IdentifierNode* name = method->name()->AsIdentifier();
            DoThis(NULL);
            compiler()->EnqueueSelector(name);
            emitter()->InvokeGetter(name);
          } else {
            InvokeStatic(method,
                         List<ExpressionNode*>(),
                         List<IdentifierNode*>());
          }
        } else if (!compiler()->IsStaticContext() ||
                   method->owner()->IsLibrary() ||
                   method->modifiers().is_static()) {
          compiler()->LoadMethod(method, this);
        } else {
          HandleUnresolved(method->name()->AsIdentifier());
        }
        return;
      }
      if (ClassNode* clazz = node->AsClass()) {
        ClassNode* cycle_error = compiler()->EnqueueCoreClass("_Type");
        LiteralStringNode name(clazz->name()->value());
        // TODO(ajohnsen): Make A.C and B.C differnt (by including library
        // path/name in the _Type).
        List<ExpressionNode*> arguments =
            List<ExpressionNode*>::New(zone(), 1);
        arguments[0] = &name;
        InvokeNode invoke_node(cycle_error->name(),
                               arguments,
                               List<IdentifierNode*>());
        NewNode new_node(true, &invoke_node);
        LoadConst(&new_node, scope());
        return;
      }
    }
    HandleUnresolved(member->name());
  } else if (entry->IsDeclaration()) {
    DeclarationEntry* declaration = entry->AsDeclaration();
    int index = declaration->index();
    if (index >= 0) {
      if (declaration->IsCapturedByReference()) {
        emitter()->LoadBoxed(index);
      } else {
        emitter()->LoadLocal(index);
      }
    } else {
      // May be local const field.
      TreeNode* node = declaration->node();
      VariableDeclarationNode* var = node->AsVariableDeclaration();
      if (var != NULL) {
        LoadVariableDeclaration(var);
        return;
      }
      UNIMPLEMENTED();
    }
  } else if (entry->IsLibrary()) {
    HandleUnresolved(entry->AsLibrary()->name());
  } else {
    UNIMPLEMENTED();
  }
}

void ValueVisitor::LoadVariableDeclaration(VariableDeclarationNode* node) {
  if (node == NULL) UNIMPLEMENTED();
  if (node->modifiers().is_const()) {
    Scope* var_scope = scope();
    TreeNode* owner = node->owner();
    if (owner != NULL) {
      var_scope = owner->IsClass() ?
          owner->AsClass()->scope() :
          owner->AsLibrary()->scope();
    }
    LoadConst(node->value(), var_scope);
    return;
  }
  int id = compiler()->Enqueue(node);
  if (id >= 0) {
    if (node->has_initializer()) {
      emitter()->LoadStaticInit(id);
    } else {
      emitter()->LoadStatic(id);
    }
  } else if (!compiler()->IsStaticContext()) {
    DoThis(NULL);
    emitter()->InvokeGetter(node->name());
  } else {
    HandleUnresolved(node->name());
  }
}

void ValueVisitor::InvokeStatic(MethodNode* node,
                                List<ExpressionNode*> arguments,
                                List<IdentifierNode*> named_arguments) {
  if (node == NULL) UNIMPLEMENTED();
  // TODO(ajohnsen): check if owner is library?
  bool with_this = node->owner()->IsClass() && !node->modifiers().is_static();
  if (with_this) {
    if (compiler()->IsStaticContext()) UNIMPLEMENTED();
    DoThis(NULL);
  }

  List<VariableDeclarationNode*> parameters = node->parameters();
  if (node->modifiers().is_external()) {
    int name_id = node->name()->AsIdentifier()->id();
    if (name_id == Names::kCoroutineChange) {
      ASSERT(named_arguments.is_empty());
      ASSERT(arguments.length() == 2);
      LoadPositionalArguments(arguments, parameters);
      emitter()->CoroutineChange();
      return;
    }

    if (name_id == Names::kIdentical) {
      ASSERT(named_arguments.is_empty());
      ASSERT(arguments.length() == 2);
      LoadPositionalArguments(arguments, parameters);
      emitter()->Identical();
      return;
    }
  }

  int id = compiler()->Enqueue(node);
  if (!named_arguments.is_empty()) {
    int stub_id = LoadNamedArguments(node, arguments, named_arguments);
    if (stub_id >= 0) {
      int argument_count = arguments.length();
      if (with_this) argument_count++;
      emitter()->InvokeStatic(argument_count, stub_id);
      return;
    }
  } else if (LoadPositionalArguments(arguments, parameters)) {
    int argument_count = parameters.length();
    if (with_this) argument_count++;
    emitter()->InvokeStatic(argument_count, id);
    return;
  }
  HandleUnresolved(node->name()->AsIdentifier());
}

void ValueVisitor::InvokeMethod(ExpressionNode* object,
                                IdentifierNode* name,
                                List<ExpressionNode*> arguments,
                                List<IdentifierNode*> named_arguments) {
  object->Accept(this);
  LoadArguments(arguments);
  compiler()->EnqueueInvokeSelector(name,
                                    arguments.length(),
                                    named_arguments);
  IdentifierNode* id = compiler()->BuildNamedArgumentId(name, named_arguments);
  emitter()->InvokeMethod(id, arguments.length());
}

void ValueVisitor::InvokeOperator(Token token, int argument_count) {
  IdentifierNode* name = builder()->OperatorName(token);
  compiler()->EnqueueInvokeSelector(name, argument_count);
  emitter()->InvokeMethod(name, argument_count);
}

void ValueVisitor::InvokeConstructor(ClassNode* clazz,
                                     MethodNode* node,
                                     List<ExpressionNode*> arguments,
                                     List<IdentifierNode*> named_arguments) {
  int id = compiler()->EnqueueConstructor(clazz, node);
  List<VariableDeclarationNode*> parameters;
  if (node != NULL) parameters = node->parameters();
  if (!named_arguments.is_empty()) {
    int stub_id = LoadNamedArguments(
        compiler()->GetMethod(id), arguments, named_arguments);
    if (stub_id >= 0) {
      emitter()->InvokeFactory(arguments.length(), stub_id);
      return;
    }
  } else if (LoadPositionalArguments(arguments, parameters)) {
    emitter()->InvokeFactory(parameters.length(), id);
    return;
  }
  IdentifierNode* name = node->name()->AsIdentifier();
  if (name == NULL) name = node->name()->AsDot()->name();
  HandleUnresolved(name);
}

void ValueVisitor::HandleUnresolved(IdentifierNode* name) {
  LibraryElement* system = compiler()->loader()->FetchLibrary("dart:system");
  IdentifierNode* unresolved = builder()->Canonicalize("_unresolved");
  Scope* system_scope = system->library()->scope();
  MemberEntry* entry = system_scope->Lookup(unresolved)->AsMember();
  ASSERT(entry != NULL);
  MethodNode* helper = entry->member()->AsMethod();

  int helper_id = compiler()->Enqueue(helper);
  LoadName(name);
  emitter()->InvokeStatic(1, helper_id);
}

bool ValueVisitor::LoadPositionalArguments(
    List<ExpressionNode*> arguments,
    List<VariableDeclarationNode*> parameters) {
  int pos_index = 0;
  for (int i = 0; i < parameters.length(); i++) {
    VariableDeclarationNode* parameter = parameters[i];
    if (parameter->modifiers().is_named()) {
      if (parameter->has_initializer()) {
        LoadConst(parameter->value(), scope());
      } else {
        LoadNull();
      }
      continue;
    }
    if (pos_index < arguments.length()) {
      arguments[pos_index]->Accept(this);
      pos_index++;
      continue;
    }
    if (parameter->modifiers().is_positional() &&
        pos_index >= arguments.length()) {
      if (parameter->has_initializer()) {
        LoadConst(parameter->value(), scope());
      } else {
        LoadNull();
      }
      continue;
    }
    return false;
  }
  return arguments.length() == pos_index;
}

int ValueVisitor::LoadNamedArguments(MethodNode* method,
                                     List<ExpressionNode*> arguments,
                                     List<IdentifierNode*> named_arguments) {
  IdentifierNode* name = method->name()->AsIdentifier();
  if (name == NULL) name = method->name()->AsDot()->name();
  IdentifierNode* stub_name =
      compiler()->BuildNamedArgumentId(name, named_arguments);
  int stub_id = compiler()->GetNamedStaticMethodStub(
      method, stub_name, arguments.length(), named_arguments, scope());
  if (stub_id < 0) return -1;
  LoadArguments(arguments);
  return stub_id;
}

void ValueVisitor::LoadArguments(List<ExpressionNode*> arguments) {
  for (int i = 0; i < arguments.length(); i++) {
    arguments[i]->Accept(this);
  }
}

void ValueVisitor::MatchParameters(ParameterMatcher* parameter_matcher,
                                   List<VariableDeclarationNode*> parameters,
                                   List<ExpressionNode*> arguments,
                                   List<IdentifierNode*> named_arguments) {
  if (arguments.length() > parameters.length()) {
    parameter_matcher->BadMatch();
    return;
  }
  List<int> positions = List<int>::New(zone(), arguments.length());
  for (int i = 0; i < arguments.length(); i++) {
    positions[i] = parameter_matcher->LoadArgument(arguments[i]);
  }
  int pos_arg_count = arguments.length() - named_arguments.length();
  int pos_index = 0;
  for (int i = 0; i < parameters.length(); i++) {
    VariableDeclarationNode* parameter = parameters[i];
    IdentifierNode* name = parameter->name();
    if (parameter->modifiers().is_named()) {
      MatchNamedParameter(parameter_matcher,
                          parameter,
                          arguments,
                          named_arguments,
                          positions);
    } else if (pos_index < pos_arg_count) {
      parameter_matcher->MatchPositional(name, positions[pos_index], NULL);
      pos_index++;
    } else if (parameter->modifiers().is_positional() &&
               pos_index >= pos_arg_count) {
      if (parameter->has_initializer()) {
        parameter_matcher->MatchPositional(name, 0, parameter->value());
      } else {
        NullNode null;
        parameter_matcher->MatchPositional(name, 0, &null);
      }
    } else {
      parameter_matcher->BadMatch();
      return;
    }
  }

  if (pos_arg_count != pos_index) {
    parameter_matcher->BadMatch();
  }
}

void ValueVisitor::MatchNamedParameter(ParameterMatcher* parameter_matcher,
                                       VariableDeclarationNode* parameter,
                                       List<ExpressionNode*> arguments,
                                       List<IdentifierNode*> named_arguments,
                                       List<int> positions) {
  IdentifierNode* name = parameter->name();
  for (int i = 0; i < named_arguments.length(); i++) {
    IdentifierNode* named_argument = named_arguments[i];
    if (name->id() == named_argument->id()) {
      int index = arguments.length() - named_arguments.length() + i;
      parameter_matcher->MatchNamed(name, positions[index], NULL);
      return;
    }
  }
  if (parameter->has_initializer()) {
    parameter_matcher->MatchNamed(name, 0, parameter->value());
  } else {
    NullNode null;
    parameter_matcher->MatchNamed(name, 0, &null);
  }
}

TreeNode* ValueVisitor::SuperLookup(IdentifierNode* name, bool report) {
  MethodNode* method = compiler()->CurrentMethod();
  ClassNode* clazz = method->owner()->AsClass();
  if (clazz == NULL) {
    if (!report) return NULL;
    compiler()->Error(name->location(), "Super access in non-class context");
  }
  TreeNode* member = Resolver::ResolveSuperMember(clazz, name);
  if (member == NULL) {
    if (!report) return NULL;
    compiler()->Error(name->location(), "Super member not found");
  }
  return member;
}

void ValueVisitor::LoadName(IdentifierNode* name) {
  LiteralStringNode node(name->value());
  LoadConst(&node, NULL);
}

void ValueVisitor::LoadConst(TreeNode* node, Scope* scope) {
  ConstInterpreter* const_interpreter = compiler()->const_interpreter();
  int id = const_interpreter->Interpret(node, scope);
  emitter()->LoadConst(id);
}

void ValueVisitor::LoadNull() {
  NullNode null;
  LoadConst(&null, NULL);
}

void ValueVisitor::LoadBoolean(bool value) {
  LiteralBooleanNode boolean(value);
  LoadConst(&boolean, NULL);
}

void ValueVisitor::CreateStaticInitializerCycleCheck(int index) {
  // Start by checking if a cycle is already set, otherwise, set it.
  ClassNode* cycle_marker = compiler()->EnqueueCoreClass(
      "_CyclicInitializationMarker");
  // TODO(ajohnsen): Add helper method on ConstInterpreter to create from class.
  InvokeNode invoke_node(cycle_marker->name(),
                         List<ExpressionNode*>(),
                         List<IdentifierNode*>());
  NewNode new_node(true, &invoke_node);
  LoadConst(&new_node, scope());

  // Compare marker with current value.
  emitter()->Dup();
  emitter()->LoadStatic(index);
  InvokeOperator(kEQ, 1);
  Label if_false;
  emitter()->BranchIfFalse(&if_false);
  // If equal, allocate and throw.
  ClassNode* cycle_error = compiler()->EnqueueCoreClass(
      "CyclicInitializationError");
  emitter()->Allocate(cycle_error->id(), 0);
  emitter()->Throw();
  emitter()->Pop();

  emitter()->Bind(&if_false);
  // Not cycle, store marker and clean up.
  emitter()->StoreStatic(index);
  emitter()->Pop();
}

int Compiler::GetNamedStaticMethodStub(MethodNode* method,
                                       IdentifierNode* stub_name,
                                       int num_arguments,
                                       List<IdentifierNode*> named_arguments,
                                       Scope* scope) {
  // First check if the method/argument combination is valid.
  List<VariableDeclarationNode*> parameters = method->parameters();
  int pos_arg_count = num_arguments - named_arguments.length();
  if (pos_arg_count >= parameters.length()) return -1;
  for (int i = 0; i < parameters.length(); i++) {
    Modifiers modifiers = parameters[i]->modifiers();
    if (i < pos_arg_count) {
      if (modifiers.is_named() || modifiers.is_positional()) return -1;
    } else {
      if (!modifiers.is_named()) return -1;
    }
  }

  IdMap<int>* named_map = named_static_stubs_.Lookup(method->id());
  if (named_map == NULL) {
    named_map = new(zone()) IdMap<int>(zone(), 0);
    named_static_stubs_.Add(method->id(), named_map);
  }

  if (named_map->Contains(stub_name->id())) {
    return named_map->Lookup(stub_name->id());
  }

  bool with_this = HasThisArgument(method);

  Emitter emitter(zone(), num_arguments + (with_this ? 1 : 0));

  if (with_this) pos_arg_count++;
  for (int i = 0; i < pos_arg_count; i++) {
    emitter.LoadParameter(i);
  }
  for (int i = 0; i < parameters.length(); i++) {
    VariableDeclarationNode* parameter = parameters[i];
    if (!parameter->modifiers().is_named()) continue;
    IdentifierNode* param_name = parameter->name();
    bool found = false;
    for (int j = 0; j < named_arguments.length(); j++) {
      if (named_arguments[j]->id() == param_name->id()) {
        emitter.LoadParameter(pos_arg_count + j);
        found = true;
        break;
      }
    }
    if (!found) {
      ValueVisitor visitor(this, &emitter, scope);
      if (parameter->has_initializer()) {
        visitor.LoadConst(parameter->value(), scope);
      } else {
        visitor.LoadNull();
      }
    }
  }
  int parameter_count = parameters.length();
  if (with_this) parameter_count++;
  emitter.InvokeStatic(parameter_count, method->id());
  emitter.Return();
  StubMethodNode* stub = new(zone()) StubMethodNode(
      stub_name, List<VariableDeclarationNode*>());
  stub->set_code(emitter.GetCode());
  int stub_id = AddStub(stub);
  named_map->Add(stub_name->id(), stub_id);
  return stub_id;
}

IdentifierNode* Compiler::BuildNamedArgumentId(
    IdentifierNode* id,
    List<IdentifierNode*> named_arguments) {
  if (named_arguments.is_empty()) return id;
  ListBuilder<char, 256> chars(zone_);
  const char* name = id->value();
  int length = strlen(name);
  for (int j = 0; j < length; j++) chars.Add(name[j]);
  for (int i = 0; i < named_arguments.length(); i++) {
    name = named_arguments[i]->value();
    int length = strlen(name);
    chars.Add(':');
    for (int j = 0; j < length; j++) chars.Add(name[j]);
  }
  chars.Add('\0');
  return builder()->Canonicalize(chars.ToList().data());
}

CompiledClass* Compiler::GetCompiledClass(int class_id) {
  ASSERT(class_id >= 0);
  return classes_.Get(class_id);
}

int Compiler::GetFieldGetter(int index) {
  while (field_getters_.length() <= index) field_getters_.Add(-1);
  int id = field_getters_.Get(index);
  if (id == -1) {
    Emitter emitter(zone(), 1);
    emitter.LoadThis();
    emitter.LoadField(index);
    emitter.Return();
    IdentifierNode* name = builder()->BuiltinName(kGET);
    StubMethodNode* stub = new(zone()) StubMethodNode(
        name, List<VariableDeclarationNode*>());
    stub->set_code(emitter.GetCode());
    id = AddStub(stub);
    field_getters_.Set(index, id);
  }
  return id;
}

int Compiler::GetFieldSetter(int index) {
  while (field_setters_.length() <= index) field_setters_.Add(-1);
  int id = field_setters_.Get(index);
  if (id == -1) {
    Emitter emitter(zone(), 2);
    emitter.LoadThis();
    emitter.LoadParameter(1);
    emitter.StoreField(index);
    emitter.Return();
    IdentifierNode* name = builder()->BuiltinName(kSET);
    StubMethodNode* stub = new(zone()) StubMethodNode(
        name, List<VariableDeclarationNode*>());
    stub->set_code(emitter.GetCode());
    id = AddStub(stub);
    field_setters_.Set(index, id);
  }
  return id;
}

MethodNode* Compiler::GetMethod(int id) {
  return methods_.Get(id);
}

void Compiler::LoadMethod(MethodNode* node, ValueVisitor* value_visitor) {
  if (node == NULL) UNIMPLEMENTED();
  bool with_this = node->owner()->IsClass() && !node->modifiers().is_static();
  int method_id = Enqueue(node);
  int tearoff_id;
  if (method_tearoffs_.Contains(method_id)) {
    tearoff_id = method_tearoffs_.Lookup(method_id);
  } else {
    IdentifierNode* name = node->name()->AsIdentifier();
    ASSERT(name != NULL);
    // Create members for class.
    int member_count = 1;
    if (with_this) member_count++;
    List<TreeNode*> members = List<TreeNode*>::New(zone(), member_count);
    // Add the 'call' method.
    List<VariableDeclarationNode*> parameters = node->parameters();
    IdentifierNode* call = call_name();
    StubMethodNode* call_method = new(zone()) StubMethodNode(call, parameters);

    Emitter nested(zone(), parameters.length() + 1);
    if (with_this) {
      nested.LoadThis();
      nested.LoadField(0);
    }
    for (int i = 0; i < parameters.length(); i++) {
      nested.LoadParameter(i + 1);
    }
    int parameter_count = parameters.length();
    if (with_this) parameter_count++;
    nested.InvokeStatic(parameter_count, method_id);
    nested.Return();

    call_method->set_code(nested.GetCode());

    members[0] = call_method;

    if (with_this) {
      List<VariableDeclarationNode*> fields =
          List<VariableDeclarationNode*>::New(zone(), 1);
      fields[0] = new(zone()) VariableDeclarationNode(
          this_name(), NULL, Modifiers());
      VariableDeclarationStatementNode* node = new(zone())
          VariableDeclarationStatementNode(Modifiers(), fields);
      members[1] = node;
    }

    ClassNode* clazz = new(zone()) ClassNode(
        false, name, NULL, List<TreeNode*>(), List<TreeNode*>(), members);
    clazz->set_scope(node->GetOwnerScope());
    call_method->set_owner(clazz);
    int class_id = AddClass(clazz, NULL);
    AddStub(call_method);
    if (with_this) {
      tearoff_id = class_id;
    } else {
      // The class is unique for this method, with no references. Create a const
      // version. This means static function references are const objects.
      tearoff_id = const_interpreter()->CreateConstInstance(clazz);
    }
    method_tearoffs_.Add(method_id, tearoff_id);
  }
  // Create the instance of the class.
  if (with_this) {
    value_visitor->DoThis(NULL);
    value_visitor->emitter()->Allocate(tearoff_id, 1);
  } else {
    value_visitor->emitter()->LoadConst(tearoff_id);
  }
}

void Compiler::Error(Location location, const char* format, ...) {
  va_list args;
  va_start(args, format);
  builder()->ReportError(location, format, args);
  va_end(args);
}

class ConstructorParameterMatcher : public ParameterMatcher {
 public:
  ConstructorParameterMatcher(ValueVisitor* value_visitor,
                              Scope* scope,
                              IdentifierNode* constructor_name)
      : value_visitor_(value_visitor)
      , scope_(scope)
      , constructor_name_(constructor_name) { }

  int LoadArgument(ExpressionNode* argument) {
    int position = value_visitor()->emitter()->frame_size();
    argument->Accept(value_visitor());
    return position;
  }

  void MatchPositional(IdentifierNode* name,
                       int position,
                       ExpressionNode* value) {
    if (value == NULL) {
      value_visitor()->emitter()->LoadLocal(position);
    } else {
      value_visitor()->LoadConst(value, scope());
    }
  }

  void MatchNamed(IdentifierNode* name,
                  int position,
                  ExpressionNode* value) {
    if (value == NULL) {
      value_visitor()->emitter()->LoadLocal(position);
    } else {
      value_visitor()->LoadConst(value, scope());
    }
  }

  void BadMatch() {
    value_visitor()->compiler()->Error(
        constructor_name()->location(), "Invalid arguments to constructor");
  }

 private:
  ValueVisitor* const value_visitor_;
  Scope* const scope_;
  IdentifierNode* const constructor_name_;

  ValueVisitor* value_visitor() const { return value_visitor_; }
  Scope* scope() const { return scope_; }
  IdentifierNode* constructor_name() const { return constructor_name_; }
};

class CompilerClassVisitor : public ClassVisitor {
 public:
  CompilerClassVisitor(ValueVisitor* value_visitor,
                       int params_offset,
                       ListBuilder<MethodNode*, 2>* constructors,
                       ListBuilder<int, 2>* argument_counts,
                       ClassNode* class_node,
                       Zone* zone)
      : ClassVisitor(class_node, zone)
      , value_visitor_(value_visitor)
      , params_offset_(params_offset)
      , constructors_(constructors)
      , argument_counts_(argument_counts)
      , constructor_scope_(zone, 0, class_node->scope()) {
  }

  void Visit(MethodNode* constructor) {
    // TODO(ajohnsen): Avoid multiple scope resolutions on the same method.
    Scope* scope = constructor->GetOwnerScope();
    ScopeResolver resolver(zone(), scope, compiler()->this_name());
    resolver.ResolveMethod(constructor);

    // Create scope for 'fake' constructor calls.
    List<VariableDeclarationNode*> parameters = constructor->parameters();
    for (int i = 0; i < parameters.length(); i++) {
      VariableDeclarationNode* parameter = parameters[i];
      if (!parameter->modifiers().is_this()) {
        DeclarationEntry* entry = parameter->entry();
        int index = params_offset() + i;
        entry->set_index(index);
        constructor_scope_.Add(parameter->name(), entry);
      }
    }

    constructors_->Add(constructor);
    ClassVisitor::Visit(constructor);
  }

  void DoThisInitializerField(VariableDeclarationNode* node,
                              int index,
                              int parameter_index,
                              bool assigned) {
    if (assigned) {
      compiler()->Error(node->name()->location(),
                        "Duplicate field initializer");
    }
    if (node->modifiers().is_final() && (node->has_initializer())) {
      value_visitor()->HandleUnresolved(node->name());
      return;
    }
    int param_index = params_offset() + parameter_index;
    value_visitor()->emitter()->LoadLocal(param_index);
    // TODO(ajohnsen): Find another way to get the total field pos.
    int abs_index = (class_node()->FieldCount() -
        class_node()->FieldCount(false)) + index;
    value_visitor()->emitter()->StoreLocal(abs_index);
    value_visitor()->emitter()->Pop();
  }

  void DoListInitializerField(VariableDeclarationNode* node,
                              int index,
                              AssignNode* initializer,
                              bool assigned) {
    if (assigned) {
      compiler()->Error(node->name()->location(),
                        "Duplicate field initializer");
    }
    if (node->modifiers().is_final() && (node->has_initializer())) {
      value_visitor()->HandleUnresolved(node->name());
      return;
    }
    Scope* old_scope = value_visitor()->set_scope(constructor_scope());
    // TODO(ajohnsen): Find another way to get the total field pos.
    int abs_index = (class_node()->FieldCount() -
        class_node()->FieldCount(false)) + index;
    initializer->value()->Accept(value_visitor());
    value_visitor()->emitter()->StoreLocal(abs_index);
    value_visitor()->emitter()->Pop();
    value_visitor()->set_scope(old_scope);
  }

  void DoSuperInitializerField(InvokeNode* node,
                               int parameter_count) {
    ClassNode* super_node = NULL;
    if (class_node()->has_super()) {
      super_node = Resolver::ResolveSuperClass(class_node());
    } else {
      IdentifierNode* object = compiler()->builder()->Canonicalize("Object");
      super_node = compiler()->LookupClass(class_node()->scope(), object);
      ASSERT(object != NULL);
    }
    ASSERT(super_node != NULL);
    CompiledClass* super = compiler()->GetCompiledClass(super_node->id());
    IdentifierNode* constructor_name = super_node->name();
    if (node != NULL) {
      DotNode* dot = node->target()->AsDot();
      if (dot != NULL) constructor_name = dot->name();
    }
    MethodNode* super_constructor = super->LookupConstructor(
        constructor_name->id());
    if (super_constructor == NULL) {
      compiler()->Error(constructor_name->location(),
                        "Cannot find constructor '%s'",
                        constructor_name->value());
    }
    if (constructors_->last()->modifiers().is_const() &&
        !super_constructor->modifiers().is_const()) {
      compiler()->Error(
          constructor_name->location(),
          "Cannot call non-const constructor from const constructor");
    }
    List<ExpressionNode*> arguments;
    List<IdentifierNode*> named_arguments;
    if (node != NULL) {
      arguments = node->arguments();
      named_arguments = node->named_arguments();
    }
    // Push potential super-arguments onto the stack.
    Scope* old_scope = value_visitor()->set_scope(constructor_scope());

    ConstructorParameterMatcher parameter_matcher(value_visitor(),
                                                  constructor_scope(),
                                                  constructor_name);
    value_visitor()->MatchParameters(&parameter_matcher,
                                     super_constructor->parameters(),
                                     arguments,
                                     named_arguments);
    argument_counts_->Add(arguments.length());
    value_visitor()->set_scope(old_scope);
    CompilerClassVisitor visitor(
        value_visitor(),
        params_offset() + arguments.length() + parameter_count,
        constructors_,
        argument_counts_,
        super_node,
        zone());
    visitor.Visit(super_constructor);
  }

 private:
  ValueVisitor* value_visitor_;
  const int params_offset_;
  ListBuilder<MethodNode*, 2>* constructors_;
  ListBuilder<int, 2>* argument_counts_;
  Scope constructor_scope_;

  ValueVisitor* value_visitor() const { return value_visitor_; }
  Compiler* compiler() const { return value_visitor()->compiler(); }
  int params_offset() const { return params_offset_; }
  Scope* constructor_scope() { return &constructor_scope_; }
};

int Compiler::CompileConstructor(CompiledClass* clazz,
                                 MethodNode* constructor) {
  ClassNode* class_node = clazz->node();

  // Accumulate all classes.
  ListBuilder<CompiledClass*, 2> classes_builder(zone());
  classes_builder.Add(clazz);
  ClassNode* super_node = clazz->super();
  while (super_node != NULL) {
    CompiledClass* super = GetCompiledClass(super_node->id());
    classes_builder.Add(super);
    super_node = super->super();
  }
  List<CompiledClass*> classes = classes_builder.ToList();

  List<VariableDeclarationNode*> parameters = constructor->parameters();

  Emitter emitter(zone(), parameters.length());
  ValueVisitor visitor(this, &emitter, class_node->scope());

  // Initialize fields in reverse order.
  int total_field_count = 0;
  for (int i = classes.length() - 1; i >= 0; i--) {
    CompiledClass* clazz = classes[i];
    ClassNode* class_node = clazz->node();
    List<TreeNode*> declarations = class_node->declarations();
    for (int j = 0; j < declarations.length(); j++) {
      VariableDeclarationStatementNode* field =
          declarations[j]->AsVariableDeclarationStatement();
      if (field == NULL) continue;
      List<VariableDeclarationNode*> vars = field->declarations();
      for (int k = 0; k < vars.length(); k++) {
        VariableDeclarationNode* var = vars[k];
        if (var->modifiers().is_static()) continue;
        total_field_count++;
        if (var->has_initializer()) {
          var->value()->Accept(&visitor);
        } else {
          visitor.LoadNull();
        }
      }
    }
  }

  // Start by loading the parameters onto the stack.
  for (int i = 0; i < parameters.length(); i++) {
    emitter.LoadParameter(i);
    // TODO(ajohnsen): Handle captured.
  }

  // Recursively visit the class and all super classes, and emit initializers
  // and simulate super calls.
  ListBuilder<MethodNode*, 2> constructors(zone());
  ListBuilder<int, 2> argument_counts(zone());
  CompilerClassVisitor class_visitor(&visitor,
                                     total_field_count,
                                     &constructors,
                                     &argument_counts,
                                     class_node,
                                     zone());
  class_visitor.Visit(constructor);

  // Allocate the class.
  for (int i = 0; i < total_field_count; i++) {
    emitter.LoadLocal(i);
  }
  emitter.Allocate(class_node->id(), total_field_count);
  int params_offset = emitter.frame_size() - 1;
  // Invoke constructor 'bodies' in reverse order.
  for (int i = constructors.length() - 1; i >= 0; i--) {
    MethodNode* constructor = constructors.Get(i);

    List<VariableDeclarationNode*> parameters = constructor->parameters();
    params_offset -= parameters.length();

    if (!IsEmptyBody(constructor->body())) {
      // Be sure to enqueue the constructor.
      Enqueue(constructor);
      // Dup the allocated class.
      emitter.Dup();
      for (int j = 0; j < parameters.length(); j++) {
        emitter.LoadLocal(params_offset + j);
      }
      emitter.InvokeStatic(1 + parameters.length(), constructor->id());
      emitter.Pop();
    }

    // Also skip the number of arguments pushed by the previous constructor.
    if (i > 0) {
      params_offset -= argument_counts.Get(i - 1);
    }
  }
  emitter.Return();

  Modifiers modifiers;
  modifiers.set_static();
  StubMethodNode* constructor_stub = new(zone()) StubMethodNode(
      modifiers, constructor->name(), List<VariableDeclarationNode*>(), NULL);
  constructor_stub->set_owner(class_node);
  constructor_stub->set_code(emitter.GetCode());
  return AddStub(constructor_stub);
}

int Compiler::CompileStaticInitializer(int index,
                                       VariableDeclarationNode* node) {
  Modifiers modifiers;
  modifiers.set_static();
  IdentifierNode* name = node->name();
  TreeNode* expr = node->value();
  Emitter emitter(zone(), 0);
  // Create initializer stub.
  StubMethodNode* stub = new(zone()) StubMethodNode(
      modifiers,
      name,
      List<VariableDeclarationNode*>(),
      expr);
  stub->set_owner(node->owner());
  Scope* scope = stub->GetOwnerScope();
  // Resolve the scopes of the stub (needed as we visit custom code).
  ScopeResolver resolver(zone(), scope, this_name());
  resolver.ResolveMethod(stub);
  ValueVisitor visitor(this, &emitter, scope);

  visitor.CreateStaticInitializerCycleCheck(index);

  // Now first visit the expr.

  // Catch the exception, and store 'null' in the variable.
  visitor.LoadNull();
  int start = emitter.position();

  MethodNode* old = method_;
  method_ = stub;
  expr->Accept(&visitor);
  method_ = old;

  // Store the value and return.
  emitter.StoreStatic(index);
  emitter.Return();
  emitter.AddFrameRange(start, emitter.position());
  // Store null and re-throw error.
  visitor.LoadNull();
  emitter.StoreStatic(index);
  emitter.Pop();
  emitter.Throw();

  stub->set_code(emitter.GetCode());
  return AddStub(stub);
}

void Compiler::RegisterMethod(int id, MethodNode* node) {
  if (node->modifiers().is_static()) return;
  TreeNode* owner = node->owner();
  if (owner == NULL) return;
  ClassNode* class_node = owner->AsClass();
  if (class_node == NULL) return;
  CompiledClass* clazz = GetCompiledClass(class_node->id());
  IdentifierNode* name = node->name()->AsIdentifier();
  // Don't add constructors.
  if (name == NULL ||
      (name->id() != call_name()->id() &&
       name->id() == class_node->name()->id())) {
    return;
  }
  int arity = node->parameters().length();
  Selector::Kind kind = Selector::METHOD;
  if (node->modifiers().is_get()) kind = Selector::GETTER;
  if (node->modifiers().is_set()) kind = Selector::SETTER;
  int selector = Selector::Encode(name->id(), kind, arity);
  clazz->AddMethodTableEntry(selector, id);
}

}  // namespace fletch
