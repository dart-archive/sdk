// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/compiler/scope_resolver.h"
#include "src/compiler/scope.h"

namespace fletch {

ScopeResolver::ScopeResolver(Zone* zone,
                             Scope* scope,
                             IdentifierNode* this_name)
    : zone_(zone)
    , scope_(scope)
    , this_name_(this_name)
    , functions_(zone) {
}

void ScopeResolver::ResolveMethod(MethodNode* node) {
  TreeNode* body = node->body();
  if (body != NULL) {
    if (!body->IsBlock() && !body->IsExpression()) body = NULL;
  }

  TreeNode* owner = node->owner();
  bool has_this = !node->modifiers().is_static() &&
      owner != NULL && owner->IsClass();

  Scope scope(zone(), 0, NULL);
  scope_ = &scope;
  DoFunction(node->parameters(), body, has_this);
  List<TreeNode*> initializers = node->initializers();
  for (int i = 0; i < initializers.length(); i++) {
    AssignNode* assign = initializers[i]->AsAssign();
    if (assign != NULL) {
      DoFunction(node->parameters(), assign->value(), has_this);
    }
  }
  scope_ = NULL;
}

void ScopeResolver::DoMethod(MethodNode* node) {
  Modifiers modifiers;
  modifiers.set_final();
  VariableDeclarationNode* var = new(zone()) VariableDeclarationNode(
      node->name()->AsIdentifier(), NULL, modifiers);
  DeclarationEntry* entry = new(zone()) DeclarationEntry(var);
  scope()->AddLocalVariable(var->name(), entry);
  var->set_entry(entry);
  node->set_captured(DoFunction(node->parameters(), node->body(), false));
}

void ScopeResolver::DoBlock(BlockNode* node) {
  Scope nested(zone(), 0, scope());
  scope_ = &nested;

  List<TreeNode*> statements = node->statements();
  for (int i = 0; i < statements.length(); i++) {
    statements[i]->Accept(this);
  }

  scope_ = nested.outer();
}

void ScopeResolver::ImplicitScopeStatement(StatementNode* node) {
  // If a single statement may introduce a new scope entry, be sure to wrap it
  // in a new scope and pop at end.
  if (node->IsVariableDeclarationStatement() || node->IsMethod()) {
    Scope nested(zone(), 0, scope());
    scope_ = &nested;
    node->Accept(this);
    scope_ = nested.outer();
    return;
  }
  node->Accept(this);
}

void ScopeResolver::DoExpressionStatement(ExpressionStatementNode* node) {
  node->expression()->Accept(this);
}

void ScopeResolver::DoLabelledStatement(LabelledStatementNode* node) {
  node->statement()->Accept(this);
}

void ScopeResolver::DoIf(IfNode* node) {
  Scope nested(zone(), 0, scope());
  scope_ = &nested;

  node->condition()->Accept(this);
  ImplicitScopeStatement(node->if_true());
  if (node->has_else()) ImplicitScopeStatement(node->if_false());

  scope_ = nested.outer();
}

void ScopeResolver::DoWhile(WhileNode* node) {
  node->condition()->Accept(this);
  ImplicitScopeStatement(node->body());
}

void ScopeResolver::DoFor(ForNode* node) {
  Scope nested(zone(), 0, scope());
  scope_ = &nested;

  node->initializer()->Accept(this);
  if (node->has_condition()) node->condition()->Accept(this);
  ImplicitScopeStatement(node->body());
  List<TreeNode*> increments = node->increments();
  for (int i = 0; i < increments.length(); i++) {
    increments[i]->Accept(this);
  }

  scope_ = nested.outer();
}

void ScopeResolver::DoForIn(ForInNode* node) {
  Scope nested(zone(), 0, scope());
  scope_ = &nested;

  node->expression()->Accept(this);
  node->var()->Accept(this);
  ImplicitScopeStatement(node->body());

  scope_ = nested.outer();
}

void ScopeResolver::DoDoWhile(DoWhileNode* node) {
  ImplicitScopeStatement(node->body());
  node->condition()->Accept(this);
}

void ScopeResolver::DoSwitch(SwitchNode* node) {
  node->value()->Accept(this);
  List<TreeNode*> cases = node->cases();
  for (int i = 0; i < cases.length(); i++) {
    CaseNode* case_node = cases[i]->AsCase();

    Scope nested(zone(), 0, scope());
    scope_ = &nested;

    case_node->condition()->Accept(this);
    List<TreeNode*> statements = case_node->statements();
    for (int i = 0; i < statements.length(); i++) {
      statements[i]->Accept(this);
    }

    scope_ = nested.outer();
  }
}

void ScopeResolver::DoTry(TryNode* node) {
  node->block()->Accept(this);
  List<TreeNode*> catches = node->catches();
  for (int i = 0; i < catches.length(); i++) {
    catches[i]->AsCatch()->Accept(this);
  }
  if (node->has_finally_block()) {
    node->finally_block()->Accept(this);
  }
}

void ScopeResolver::DoCatch(CatchNode* node) {
  Scope nested(zone(), 0, scope());
  scope_ = &nested;

  if (node->has_exception_name()) {
    node->exception_name()->Accept(this);
  }
  if (node->has_stack_trace_name()) {
    node->stack_trace_name()->Accept(this);
  }
  node->block()->Accept(this);

  scope_ = nested.outer();
}

void ScopeResolver::DoReturn(ReturnNode* node) {
  if (node->has_expression()) node->value()->Accept(this);
}

void ScopeResolver::DoVariableDeclarationStatement(
    VariableDeclarationStatementNode* node) {
  List<VariableDeclarationNode*> declarations = node->declarations();
  for (int i = 0; i < declarations.length(); i++) {
    declarations[i]->Accept(this);
  }
}

void ScopeResolver::DoVariableDeclaration(VariableDeclarationNode* node) {
  if (node->modifiers().is_const()) return;
  if (node->has_initializer()) node->value()->Accept(this);
  DeclarationEntry* entry = new(zone()) DeclarationEntry(node);
  scope()->AddLocalVariable(node->name(), entry);
  node->set_entry(entry);
}

void ScopeResolver::DoFunctionExpression(FunctionExpressionNode* node) {
  node->set_captured(DoFunction(node->parameters(), node->body(), false));
}

void ScopeResolver::DoIdentifier(IdentifierNode* node) {
  ScopeEntry* entry = scope()->Lookup(node);
  if (entry == NULL) {
    DoThis(NULL);
    return;
  }
  ASSERT(entry->IsDeclaration());
  DeclarationEntry* declaration = entry->AsDeclaration();
  VariableDeclarationNode* var = declaration->node()->AsVariableDeclaration();
  ASSERT(var != NULL);
  bool by_value = false;
  // Found, but not in function.
  if (var->entry() == NULL) {
    if (var->modifiers().is_static()) return;
    if (!var->owner()->IsClass()) return;
    DoThis(NULL);
    return;
  } else if (var->modifiers().is_final()) {
    // Owner is set, it's a VariableDeclarationNode for a MethodNode.
    by_value = true;
  }
  MarkCaptured(declaration, by_value);
}

void ScopeResolver::DoParenthesized(ParenthesizedNode* node) {
  node->expression()->Accept(this);
}

void ScopeResolver::DoAssign(AssignNode* node) {
  node->target()->Accept(this);
  node->value()->Accept(this);
}

void ScopeResolver::DoUnary(UnaryNode* node) {
  node->expression()->Accept(this);
}

void ScopeResolver::DoBinary(BinaryNode* node) {
  node->left()->Accept(this);
  node->right()->Accept(this);
}

void ScopeResolver::DoConditional(ConditionalNode* node) {
  node->condition()->Accept(this);
  node->if_true()->Accept(this);
  node->if_false()->Accept(this);
}

void ScopeResolver::DoDot(DotNode* node) {
  node->object()->Accept(this);
}

void ScopeResolver::DoInvoke(InvokeNode* node) {
  node->target()->Accept(this);
  List<ExpressionNode*> arguments = node->arguments();
  for (int i = 0; i < arguments.length(); i++) {
    arguments[i]->Accept(this);
  }
}

void ScopeResolver::DoIndex(IndexNode* node) {
  node->target()->Accept(this);
  node->key()->Accept(this);
}

void ScopeResolver::DoNew(NewNode* node) {
  node->invoke()->Accept(this);
}

void ScopeResolver::DoThis(ThisNode* node) {
  // See if 'this' is in scope.
  ScopeEntry* entry = scope()->Lookup(this_name_);
  if (entry == NULL) return;
  MarkCaptured(entry->AsDeclaration(), true);
}

void ScopeResolver::DoStringInterpolation(StringInterpolationNode* node) {
  List<ExpressionNode*> expressions = node->expressions();
  for (int i = 0; i < expressions.length(); i++) {
    expressions[i]->Accept(this);
  }
}

void ScopeResolver::MarkCaptured(DeclarationEntry* entry, bool by_value) {
  VariableDeclarationNode* var = entry->node()->AsVariableDeclaration();
  ASSERT(var != NULL);
  for (int i = functions_.length() - 1; i >= 0; i--) {
    FunctionMarker* marker = functions_.Get(i);
    if (entry->index() >= marker->index()) break;
    if (by_value) {
      entry->MarkCapturedByValue();
    } else {
      entry->MarkCapturedByReference();
    }
    marker->MarkCaptured(var);
  }
}

void ScopeResolver::FunctionMarker::MarkCaptured(VariableDeclarationNode* var) {
  IdentifierNode* name = var->name();
  if (entries_.Lookup(name->id()) == NULL) {
    entries_.Add(name->id(), var);
  }
}

List<VariableDeclarationNode*> ScopeResolver::FunctionMarker::GetCaptured() {
  return entries_.ToList();
}

List<VariableDeclarationNode*> ScopeResolver::DoFunction(
    List<VariableDeclarationNode*> parameters,
    TreeNode* body,
    bool has_this) {
  FunctionMarker marker(scope()->TotalLocals(), zone());
  functions_.Add(&marker);

  Scope nested(zone(), 0, scope());
  scope_ = &nested;
  if (has_this) {
    VariableDeclarationNode* var = new(zone())
        VariableDeclarationNode(this_name_, NULL, Modifiers());
    DeclarationEntry* entry = new(zone()) DeclarationEntry(var);
    var->set_entry(entry);
    scope()->AddLocalVariable(this_name_, entry);
    entry->set_index(-1);
  }
  for (int i = 0; i < parameters.length(); i++) {
    VariableDeclarationNode* var = parameters[i];
    if (var->modifiers().is_this()) continue;
    DeclarationEntry* entry = new(zone()) DeclarationEntry(var);
    var->set_entry(entry);
    scope()->AddLocalVariable(var->name(), entry);
  }
  if (body != NULL) body->Accept(this);
  scope_ = nested.outer();

  functions_.RemoveLast();
  return marker.GetCaptured();
}

}  // namespace fletch
