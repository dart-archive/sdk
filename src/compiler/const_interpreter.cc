// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/compiler/class_visitor.h"
#include "src/compiler/compiler.h"
#include "src/compiler/const_interpreter.h"
#include "src/compiler/resolver.h"
#include "src/compiler/scope.h"

namespace fletch {

class ConstClassVisitor : public ClassVisitor {
 public:
  ConstClassVisitor(List<ConstObject*>* const_fields,
                    List<ExpressionNode*> arguments,
                    Scope* caller_scope,
                    int field_offset,
                    ConstInterpreter* const_interpreter,
                    ClassNode* clazz)
      : ClassVisitor(clazz, const_interpreter->zone())
      , const_fields_(const_fields)
      , arguments_(arguments)
      , caller_scope_(caller_scope)
      , field_offset_(field_offset)
      , const_interpreter_(const_interpreter)
      , constructor_scope_(const_interpreter->zone(), 0, caller_scope_) {
  }

  void Visit(MethodNode* constructor) {
    if (!constructor->modifiers().is_const()) {
      ExpressionNode* name = constructor->name()->AsExpression();
      if (name->IsDot()) name = name->AsDot()->name();
      const_interpreter()->compiler()->Error(name->location(),
                                             "Constructor is not const");
    }
    Zone* zone = const_interpreter()->zone();

    // TODO(ajohnsen): We need a way to correctly match these
    // arguments/parameters. Use the MatchParameters from ValueVisitor.
    List<VariableDeclarationNode*> parameters = constructor->parameters();
    // Create scope for 'fake' constructor calls.
    Modifiers modifiers;
    modifiers.set_const();
    for (int i = 0; i < parameters.length(); i++) {
      VariableDeclarationNode* parameter = parameters[i];
      VariableDeclarationNode* scope_parameter =
          new(zone) VariableDeclarationNode(NULL, arguments()[i], modifiers);
      DeclarationEntry* entry = new(zone) DeclarationEntry(scope_parameter);
      constructor_scope_.Add(parameter->name(), entry);
    }

    ClassVisitor::Visit(constructor);
  }

  void DoThisInitializerField(VariableDeclarationNode* node,
                              int index,
                              int parameter_index,
                              bool assigned) {
    if (assigned || node->has_initializer()) {
      const_interpreter()->compiler()->Error(node->name()->location(),
                                             "Duplicate field initializer");
    }
    ExpressionNode* value = arguments()[parameter_index];
    ConstInterpreter::ConstVisitor visitor(const_interpreter(), caller_scope());
    SetConstField(index, visitor.Resolve(value));
  }

  void DoListInitializerField(VariableDeclarationNode* node,
                              int index,
                              AssignNode* initializer,
                              bool assigned) {
    if (assigned || node->has_initializer()) {
      const_interpreter()->compiler()->Error(node->name()->location(),
                                             "Duplicate field initializer");
    }
    ConstInterpreter::ConstVisitor visitor(const_interpreter(),
                                           &constructor_scope_);
    SetConstField(index, visitor.Resolve(initializer->value()));
  }

  void DoSuperInitializerField(InvokeNode* node,
                               int parameter_count) {
    if (!class_node()->has_super() && node != NULL) UNIMPLEMENTED();
    ClassNode* super_node = Resolver::ResolveSuperClass(class_node());
    ASSERT(super_node != NULL);
    CompiledClass* super =
        const_interpreter()->compiler()->GetCompiledClass(super_node->id());
    IdentifierNode* constructor_name = super_node->name();
    List<ExpressionNode*> arguments;
    if (node != NULL) {
      arguments = node->arguments();
      DotNode* dot = node->target()->AsDot();
      if (dot != NULL) constructor_name = dot->name();
    }
    MethodNode* super_constructor = super->LookupConstructor(
        constructor_name->id());
    if (super_constructor == NULL) {
      const_interpreter()->compiler()->Error(constructor_name->location(),
                                             "Constructor not found");
    }
    ConstClassVisitor visitor(const_fields(),
                              arguments,
                              caller_scope(),
                              field_offset() - class_node()->FieldCount(false),
                              const_interpreter(),
                              super_node);
    visitor.Visit(super_constructor);
  }

  void SetConstField(int index, ConstObject* object) {
    (*const_fields())[field_offset() + index] = object;
  }

 private:
  List<ConstObject*>* const_fields_;
  List<ExpressionNode*> arguments_;
  Scope* caller_scope_;
  const int field_offset_;
  ConstInterpreter* const_interpreter_;
  Scope constructor_scope_;

  List<ConstObject*>* const_fields() const { return const_fields_; }
  List<ExpressionNode*> arguments() const { return arguments_; }
  Scope* caller_scope() const { return caller_scope_; }
  int field_offset() const { return field_offset_; }
  ConstInterpreter* const_interpreter() const { return const_interpreter_; }
};

ConstInterpreter::ConstInterpreter(Compiler* compiler)
    : compiler_(compiler)
    , const_objects_(compiler->zone())
    , integer_map_(compiler->zone(), 0)
    , double_map_(compiler->zone(), 0)
    , string_map_(compiler->zone(), 0)
    , list_map_(compiler->zone(), 0)
    , map_map_(compiler->zone(), 0)
    , class_map_(compiler->zone(), 0)
    , const_null_(new(compiler->zone()) ConstNull(kConstNullId))
    , const_true_(new(compiler->zone()) ConstTrue(kConstTrueId))
    , const_false_(new(compiler->zone()) ConstFalse(kConstFalseId)) {
  const_objects_.Add(const_null_);
  const_objects_.Add(const_true_);
  const_objects_.Add(const_false_);
}

int ConstInterpreter::Interpret(TreeNode* node, Scope* scope) {
  ConstVisitor visitor(this, scope);
  node->Accept(&visitor);
  if (!visitor.IsResolved()) UNIMPLEMENTED();
  return visitor.Pop()->id();
}

int ConstInterpreter::CreateConstInstance(ClassNode* clazz) {
  ASSERT(clazz->FieldCount() == 0);
  int id = const_objects_.length();
  ConstObject* object = new(zone()) ConstClass(id, clazz, List<ConstObject*>());
  const_objects_.Add(object);
  return id;
}

ConstInterpreter::ConstVisitor::ConstVisitor(
    ConstInterpreter* const_interpreter,
    Scope* scope)
    : const_interpreter_(const_interpreter)
    , scope_(scope)
    , stack_(const_interpreter->zone()) {
}

void ConstInterpreter::ConstVisitor::DoBinary(BinaryNode* node) {
  ConstObject* left = Resolve(node->left());
  ConstObject* right = Resolve(node->right());
  if (left == NULL || right == NULL) UNIMPLEMENTED();
  const ConstInteger* left_int = left->AsInteger();
  const ConstInteger* right_int = right->AsInteger();
  ConstObject* result = NULL;
  if (left_int != NULL && right_int != NULL) {
    int64 l = left_int->value();
    int64 r = right_int->value();
    switch (node->token()) {
      case kSHL: result = const_interpreter()->FindInteger(l << r); break;
      case kSHR: result = const_interpreter()->FindInteger(l >> r); break;
      case kADD: result = const_interpreter()->FindInteger(l + r); break;
      case kSUB: result = const_interpreter()->FindInteger(l - r); break;
      case kMUL: result = const_interpreter()->FindInteger(l * r); break;
      case kDIV: result = const_interpreter()->FindInteger(l / r); break;
      case kBIT_AND: result = const_interpreter()->FindInteger(l & r); break;
      case kBIT_OR: result = const_interpreter()->FindInteger(l | r); break;
      default:
        UNIMPLEMENTED();
    }
  }
  const ConstDouble* left_double = left->AsDouble();
  const ConstDouble* right_double = right->AsDouble();
  if (left_double != NULL && right_double != NULL) {
    double l = left_double->value();
    double r = right_double->value();
    switch (node->token()) {
      case kADD: result = const_interpreter()->FindDouble(l + r); break;
      case kSUB: result = const_interpreter()->FindDouble(l - r); break;
      case kMUL: result = const_interpreter()->FindDouble(l * r); break;
      // TODO(ager): The result of the division could be nan in which case
      // we will probably not find anything with FindDouble. We should
      // probably special case FindDouble for that.
      case kDIV: result = const_interpreter()->FindDouble(l / r); break;
      default:
        UNIMPLEMENTED();
    }
  }

  if (result == NULL) return;
  Push(result);
}

void ConstInterpreter::ConstVisitor::DoUnary(UnaryNode* node) {
  ConstObject* expression = Resolve(node->expression());
  if (expression == NULL) return;
  switch (node->token()) {
    case kBIT_NOT: {
      const ConstInteger* int_value = expression->AsInteger();
      if (int_value == NULL) UNIMPLEMENTED();
      int64 value = ~int_value->value();
      Push(const_interpreter()->FindInteger(value));
      break;
    }

    case kSUB: {
      const ConstInteger* int_value = expression->AsInteger();
      if (int_value != NULL) {
        int64 value = -int_value->value();
        Push(const_interpreter()->FindInteger(value));
        break;
      }
      const ConstDouble* double_value = expression->AsDouble();
      if (double_value != NULL) {
        double value = -double_value->value();
        Push(const_interpreter()->FindDouble(value));
        break;
      }
      UNIMPLEMENTED();
      break;
    }

    default:
      UNIMPLEMENTED();
  }
}

void ConstInterpreter::ConstVisitor::DoParenthesized(ParenthesizedNode* node) {
  node->expression()->Accept(this);
}

void ConstInterpreter::ConstVisitor::DoLiteralInteger(
    LiteralIntegerNode* node) {
  Push(const_interpreter()->FindInteger(node->value()));
}

void ConstInterpreter::ConstVisitor::DoLiteralDouble(LiteralDoubleNode* node) {
  Push(const_interpreter()->FindDouble(node->value()));
}

void ConstInterpreter::ConstVisitor::DoLiteralString(LiteralStringNode* node) {
  ConstString* object = const_interpreter()->string_map_.Lookup(node->value());
  if (object == NULL) {
    int id = const_interpreter()->const_objects_.length();
    object = new(zone()) ConstString(id, node->value());
    const_interpreter()->string_map_.Add(node->value(), object);
    const_interpreter()->const_objects_.Add(object);
  }
  Push(object);
}

void ConstInterpreter::ConstVisitor::DoLiteralList(LiteralListNode* node) {
  List<ExpressionNode*> elements = node->elements();
  int length = elements.length();
  List<ConstObject*> const_elements = List<ConstObject*>::New(zone(), length);
  // TODO(ajohnsen): Use the type class id instead of 0.
  PartialConstList* partial = const_interpreter()->list_map_.Lookup(0);
  if (partial == NULL) {
    partial = new(zone()) PartialConstList(zone());
    const_interpreter()->list_map_.Add(0, partial);
  }
  for (int i = 0; i < length; i++) {
    ConstObject* const_object = Resolve(elements[i]);
    if (const_object == NULL) return;
    const_elements[i] = const_object;
    int id = const_object->id();
    PartialConstList* next = partial->Lookup(id);
    if (next == NULL) {
      next = new(zone()) PartialConstList(zone());
      partial->Add(id, next);
    }
    partial = next;
  }
  ConstList* object = partial->list();
  if (object == NULL) {
    int id = const_interpreter()->const_objects_.length();
    object = new(zone()) ConstList(id, const_elements);
    partial->set_list(object);
    const_interpreter()->const_objects_.Add(object);
  }
  Push(object);
}

void ConstInterpreter::ConstVisitor::DoLiteralMap(LiteralMapNode* node) {
  List<ExpressionNode*> keys = node->keys();
  List<ExpressionNode*> values = node->values();
  int length = keys.length();
  List<ConstObject*> const_elements = List<ConstObject*>::New(zone(),
                                                              length * 2);
  // TODO(ajohnsen): Use the type class id instead of 0.
  PartialConstMap* partial = const_interpreter()->map_map_.Lookup(0);
  if (partial == NULL) {
    partial = new(zone()) PartialConstMap(zone());
    const_interpreter()->map_map_.Add(0, partial);
  }
  List<ExpressionNode*> lists[2] = {keys, values};
  for (int i = 0; i < length; i++) {
    for (int j = 0; j < 2; j++) {
      ConstObject* const_object = Resolve(lists[j][i]);
      if (const_object == NULL) return;
      const_elements[i * 2 + j] = const_object;
      int id = const_object->id();
      PartialConstMap* next = partial->Lookup(id);
      if (next == NULL) {
        next = new(zone()) PartialConstMap(zone());
        partial->Add(id, next);
      }
      partial = next;
    }
  }
  ConstMap* object = partial->map();
  if (object == NULL) {
    int id = const_interpreter()->const_objects_.length();
    object = new(zone()) ConstMap(id, const_elements);
    partial->set_map(object);
    const_interpreter()->const_objects_.Add(object);
  }
  Push(object);
}

void ConstInterpreter::ConstVisitor::DoNew(NewNode* node) {
  if (!node->is_const()) return;
  IdentifierNode* class_name = NULL;
  IdentifierNode* constructor_name = NULL;
  InvokeNode* invoke = node->invoke();
  TreeNode* target = invoke->target();
  DotNode* dot = target->AsDot();
  if (dot != NULL) {
    class_name = dot->object()->AsIdentifier();
    constructor_name = dot->name();
  } else {
    class_name = constructor_name = target->AsIdentifier();
  }
  Compiler* compiler = const_interpreter()->compiler();
  ClassNode* class_node = compiler->LookupClass(scope(), class_name);
  if (class_node == NULL) {
    compiler->Error(class_name->location(), "Class not found");
  }
  int class_id = compiler->EnqueueClass(class_node);
  CompiledClass* clazz = compiler->GetCompiledClass(class_id);

  // Accumulate all classes.
  ListBuilder<CompiledClass*, 2> classes_builder(zone());
  classes_builder.Add(clazz);
  ClassNode* super_node = clazz->super();
  while (super_node != NULL) {
    CompiledClass* super = compiler->GetCompiledClass(super_node->id());
    classes_builder.Add(super);
    super_node = super->super();
  }
  List<CompiledClass*> classes = classes_builder.ToList();

  ListBuilder<ConstObject*, 2> const_fields_builder(zone());
  for (int i = classes.length() - 1; i >= 0; i--) {
    ClassNode* current_class = classes[i]->node();
    List<TreeNode*> declarations = current_class->declarations();
    for (int j = 0; j < declarations.length(); j++) {
      VariableDeclarationStatementNode* field =
          declarations[j]->AsVariableDeclarationStatement();
      if (field == NULL) continue;
      List<VariableDeclarationNode*> vars = field->declarations();
      for (int k = 0; k < vars.length(); k++) {
        VariableDeclarationNode* var = vars[k];
        if (var->modifiers().is_static()) continue;
        if (!var->modifiers().is_final()) {
          compiler->Error(var->name()->location(),
                          "Non-final field in const instantiation.");
        }
        if (var->has_initializer()) {
          ConstObject* value = Resolve(var->value(), current_class->scope());
          if (value == NULL) return;
          const_fields_builder.Add(value);
        } else {
          const_fields_builder.Add(const_interpreter()->const_null());
        }
      }
    }
  }
  List<ConstObject*> const_fields = const_fields_builder.ToList();

  MethodNode* constructor = clazz->LookupConstructor(constructor_name->id());
  if (constructor == NULL) {
    compiler->Error(constructor_name->location(), "Constructor not found");
  }
  List<ExpressionNode*> arguments = node->invoke()->arguments();


  ConstClassVisitor visitor(
      &const_fields,
      arguments,
      scope(),
      const_fields.length() - class_node->FieldCount(false),
      const_interpreter(),
      class_node);
  visitor.Visit(constructor);
  PartialConstClass* partial = const_interpreter()->class_map_.Lookup(class_id);
  if (partial == NULL) {
    partial = new(zone()) PartialConstClass(zone());
    const_interpreter()->class_map_.Add(class_id, partial);
  }
  for (int i = 0; i < const_fields.length(); i++) {
    ConstObject* object = const_fields[i];
    if (object == NULL) return;
    int const_id = object->id();
    PartialConstClass* next = partial->Lookup(const_id);
    if (next == NULL) {
      next = new(zone()) PartialConstClass(zone());
      partial->Add(const_id, next);
    }
    partial = next;
  }
  ConstClass* object = partial->clazz();
  if (object == NULL) {
    int id = const_interpreter()->const_objects_.length();
    object = new(zone()) ConstClass(id, class_node, const_fields);
    partial->set_clazz(object);
    const_interpreter()->const_objects_.Add(object);
  }
  Push(object);
}

void ConstInterpreter::ConstVisitor::DoNull(NullNode* node) {
  Push(const_interpreter()->const_null());
}

void ConstInterpreter::ConstVisitor::DoLiteralBoolean(
    LiteralBooleanNode* node) {
  if (node->value()) {
    Push(const_interpreter()->const_true_);
  } else {
    Push(const_interpreter()->const_false_);
  }
}

void ConstInterpreter::ConstVisitor::DoIdentifier(IdentifierNode* node) {
  TreeNode* resolved = Resolver::Resolve(node, scope());
  if (resolved == NULL) UNIMPLEMENTED();
  VariableDeclarationNode* var = resolved->AsVariableDeclaration();
  if (var == NULL || !var->has_initializer()) UNIMPLEMENTED();
  if (!var->modifiers().is_const()) return;
  Scope* var_scope = scope();
  TreeNode* owner = var->owner();
  if (owner != NULL) {
    var_scope = owner->IsClass() ?
        owner->AsClass()->scope() :
        owner->AsLibrary()->scope();
  }
  ConstObject* value = Resolve(var->value(), var_scope);
  if (value != NULL) Push(value);
}

void ConstInterpreter::ConstVisitor::DoDot(DotNode* node) {
  TreeNode* resolved = Resolver::Resolve(node, scope());
  if (resolved == NULL) UNIMPLEMENTED();
  VariableDeclarationNode* var = resolved->AsVariableDeclaration();
  if (var == NULL || !var->has_initializer()) UNIMPLEMENTED();
  if (!var->modifiers().is_const()) return;
  Scope* var_scope = scope();
  TreeNode* owner = var->owner();
  if (owner != NULL) {
    var_scope = owner->IsClass() ?
        owner->AsClass()->scope() :
        owner->AsLibrary()->scope();
  }
  ConstObject* value = Resolve(var->value(), var_scope);
  if (value != NULL) Push(value);
}

void ConstInterpreter::ConstVisitor::DoConditional(ConditionalNode* node) {
  ConstObject* obj = Resolve(node->condition(), scope());
  if (obj == NULL) return;
  if (obj->AsTrue() != NULL) {
    obj = Resolve(node->if_true(), scope());
    if (obj != NULL) Push(obj);
  } else if (obj->AsFalse() != NULL) {
    obj = Resolve(node->if_false(), scope());
    if (obj != NULL) Push(obj);
  } else {
    return;
  }
}

ConstObject* ConstInterpreter::ConstVisitor::Resolve(TreeNode* node,
                                                     Scope* scope) {
  if (scope == NULL) scope = this->scope();
  ConstVisitor visitor(const_interpreter(), scope);
  node->Accept(&visitor);
  if (!visitor.IsResolved()) return NULL;
  return visitor.Pop();
}

bool ConstInterpreter::DoubleEquals(const double a, const double b) {
  return a == b;
}

int ConstInterpreter::DoubleHash(const double value) {
  const int* raw = reinterpret_cast<const int*>(&value);
  return raw[0] ^ raw[1];
}

ConstInteger* ConstInterpreter::FindInteger(int64 value) {
  if (integer_map_.Contains(value)) return integer_map_.Lookup(value);
  int id = const_objects_.length();
  ConstInteger* object = new(zone()) ConstInteger(id, value);
  integer_map_.Add(value, object);
  const_objects_.Add(object);
  return object;
}

ConstDouble* ConstInterpreter::FindDouble(double value) {
  ConstDouble* object = double_map_.Lookup(value);
  if (object == NULL) {
    int id = const_objects_.length();
    object = new(zone()) ConstDouble(id, value);
    double_map_.Add(value, object);
    const_objects_.Add(object);
  }
  return object;
}

}  // namespace fletch
