// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/compiler/resolver.h"
#include "src/compiler/scope.h"
#include "src/compiler/tree.h"

namespace fletch {

void TreeVisitor::Do(TreeNode* node) {
  // Do nothing.
}

#define DECLARE(name)                                                        \
void TreeVisitor::Do##name(name##Node* node) {                               \
  Do(node);                                                                  \
}
DO_GENERAL_NODES(DECLARE)
#undef DECLARE

#define DECLARE(name)                                                        \
void TreeVisitor::Do##name(name##Node* node) {                               \
  DoStatement(node);                                                         \
}
DO_STATEMENT_NODES(DECLARE)
#undef DECLARE

#define DECLARE(name)                                                        \
void TreeVisitor::Do##name(name##Node* node) {                               \
  DoExpression(node);                                                        \
}
DO_EXPRESSION_NODES(DECLARE)
#undef DECLARE

LibraryNode::LibraryNode(
    CompilationUnitNode* unit,
    List<CompilationUnitNode*> parts)
    : unit_(unit)
    , parts_(parts)
    , scope_(NULL) {
}

CompilationUnitNode::CompilationUnitNode(List<TreeNode*> declarations)
    : declarations_(declarations) {
}

ImportNode::ImportNode(LiteralStringNode* uri, IdentifierNode* prefix)
    : uri_(uri)
    , prefix_(prefix) {
}

ExportNode::ExportNode(LiteralStringNode* uri)
    : uri_(uri) {
}

PartNode::PartNode(LiteralStringNode* uri)
    : uri_(uri) {
}

PartOfNode::PartOfNode(TreeNode* name)
    : name_(name) {
}

ClassNode::ClassNode(
    bool is_abstract,
    IdentifierNode* name,
    TreeNode* super,
    List<TreeNode*> mixins,
    List<TreeNode*> implements,
    List<TreeNode*> declarations)
    : is_abstract_(is_abstract)
    , name_(name)
    , super_(super)
    , mixins_(mixins)
    , implements_(implements)
    , declarations_(declarations)
    , id_(-1)
    , scope_(NULL)
    , library_(NULL) {
}

int ClassNode::FieldCount(bool include_super) const {
  int count = 0;
  if (include_super && has_super()) {
    count += Resolver::ResolveSuperClass(this)->FieldCount();
  }
  for (int i = 0; i < declarations_.length(); i++) {
    VariableDeclarationStatementNode* statement =
        declarations_[i]->AsVariableDeclarationStatement();
    if (statement != NULL) {
      List<VariableDeclarationNode*> vars = statement->declarations();
      for (int j = 0; j < vars.length(); j++) {
        VariableDeclarationNode* var = vars[j]->AsVariableDeclaration();
        if (!var->modifiers().is_static()) count++;
      }
    }
  }
  return count;
}

Scope* ClassNode::BuildScope(Zone* zone, Scope* outer) const {
  Scope* result = new(zone) Scope(zone, 0, outer);
  result->AddAll(scope());
  return result;
}

MethodNode::MethodNode(
    Modifiers modifiers,
    TreeNode* name,
    List<VariableDeclarationNode*> parameters,
    List<TreeNode*> initializers,
    TreeNode* body)
    : modifiers_(modifiers)
    , name_(name)
    , parameters_(parameters)
    , initializers_(initializers)
    , body_(body)
    , id_(-1)
    , owner_(NULL)
    , link_(NULL) {
}

int MethodNode::OptionalParameterCount() const {
  int result = 0;
  for (int i = parameters_.length() - 1; i >= 0; i--) {
    Modifiers modifiers = parameters_[i]->modifiers();
    if (!modifiers.is_named() && !modifiers.is_positional()) break;
    result++;
  }
  return result;
}

TypedefNode::TypedefNode(
    IdentifierNode* name,
    List<TreeNode*> parameters)
    : name_(name)
    , parameters_(parameters) {
}

Scope* MethodNode::GetOwnerScope() const {
  if (owner() == NULL) return NULL;
  if (owner()->IsClass()) return owner_->AsClass()->scope();
  if (owner()->IsLibrary()) return owner_->AsLibrary()->scope();
  UNIMPLEMENTED();
  return NULL;
}

BlockNode::BlockNode(List<TreeNode*> statements)
    : statements_(statements) {
}

VariableDeclarationNode::VariableDeclarationNode(
    IdentifierNode* name,
    ExpressionNode* value,
    Modifiers modifiers)
    : name_(name)
    , value_(value)
    , modifiers_(modifiers)
    , owner_(NULL)
    , entry_(NULL)
    , setter_id_(-1)
    , index_(-1)
    , link_(NULL) {
}

VariableDeclarationStatementNode::VariableDeclarationStatementNode(
    Modifiers modifiers,
    List<VariableDeclarationNode*> declarations)
    : modifiers_(modifiers)
    , declarations_(declarations) {
}

ExpressionStatementNode::ExpressionStatementNode(ExpressionNode* expression)
    : expression_(expression) {
}

IfNode::IfNode(
    ExpressionNode* condition,
    StatementNode* if_true,
    StatementNode* if_false)
    : condition_(condition)
    , if_true_(if_true)
    , if_false_(if_false) {
}

ForNode::ForNode(
    StatementNode* initializer,
    ExpressionNode* condition,
    List<TreeNode*> increments,
    StatementNode* body)
    : initializer_(initializer)
    , condition_(condition)
    , increments_(increments)
    , body_(body) {
}

ForInNode::ForInNode(
    Token token,
    VariableDeclarationNode* var,
    ExpressionNode* expression,
    StatementNode* body)
    : token_(token)
    , var_(var)
    , expression_(expression)
    , body_(body) {
}

WhileNode::WhileNode(ExpressionNode* condition, StatementNode* body)
    : condition_(condition)
    , body_(body) {
}

DoWhileNode::DoWhileNode(ExpressionNode* condition, StatementNode* body)
    : condition_(condition)
    , body_(body) {
}

BreakNode::BreakNode(IdentifierNode* label)
    : label_(label) {
}

ContinueNode::ContinueNode(IdentifierNode* label)
    : label_(label) {
}

ReturnNode::ReturnNode(ExpressionNode* value)
    : value_(value) {
}

AssertNode::AssertNode(ExpressionNode* condition)
    : condition_(condition) {
}

CaseNode::CaseNode(ExpressionNode* condition, List<TreeNode*> statements)
    : condition_(condition)
    , statements_(statements) {
}

SwitchNode::SwitchNode(
    ExpressionNode* value,
    List<TreeNode*> cases,
    List<TreeNode*> default_statements)
    : value_(value)
    , cases_(cases)
    , default_statements_(default_statements) {
}

CatchNode::CatchNode(
    TreeNode* type,
    VariableDeclarationNode* exception_name,
    VariableDeclarationNode* stack_trace_name,
    BlockNode* block)
    : type_(type)
    , exception_name_(exception_name)
    , stack_trace_name_(stack_trace_name)
    , block_(block) {
}

TryNode::TryNode(
    BlockNode* block,
    List<TreeNode*> catches,
    BlockNode* finally_block)
    : block_(block)
    , catches_(catches)
    , finally_block_(finally_block) {
}

LabelledStatementNode::LabelledStatementNode(
    IdentifierNode* name,
    StatementNode* statement)
    : name_(name)
    , statement_(statement) {
}

RethrowNode::RethrowNode() {
}

ParenthesizedNode::ParenthesizedNode(Location location,
                                     ExpressionNode* expression)
    : location_(location)
    , expression_(expression) {
}

AssignNode::AssignNode(
    Token token,
    ExpressionNode* target,
    ExpressionNode* value)
    : token_(token)
    , target_(target)
    , value_(value) {
}

UnaryNode::UnaryNode(Token token, bool prefix, ExpressionNode* expression)
    : token_(token)
    , prefix_(prefix)
    , expression_(expression) {
}

BinaryNode::BinaryNode(Token token,
                       ExpressionNode* left,
                       ExpressionNode* right)
    : token_(token)
    , left_(left)
    , right_(right) {
}

DotNode::DotNode(ExpressionNode* object, IdentifierNode* name)
    : object_(object)
    , name_(name) {
}

CascadeReceiverNode::CascadeReceiverNode(Token token, ExpressionNode* object)
    : token_(token),
      object_(object) {
}

CascadeNode::CascadeNode(ExpressionNode* expression)
    : expression_(expression) {
}

InvokeNode::InvokeNode(ExpressionNode* target,
                       List<ExpressionNode*> arguments,
                       List<IdentifierNode*> named_arguments)
    : target_(target)
    , arguments_(arguments)
    , named_arguments_(named_arguments) {
}

IndexNode::IndexNode(ExpressionNode* target, ExpressionNode* key)
    : target_(target)
    , key_(key) {
}

ConditionalNode::ConditionalNode(ExpressionNode* condition,
                                 ExpressionNode* if_true,
                                 ExpressionNode* if_false)
    : condition_(condition)
    , if_true_(if_true)
    , if_false_(if_false) {
}

IsNode::IsNode(bool is_not, ExpressionNode* object, TreeNode* type)
    : is_not_(is_not)
    , object_(object)
    , type_(type) {
}

AsNode::AsNode(ExpressionNode* object, TreeNode* type)
    : object_(object)
    , type_(type) {
}

NewNode::NewNode(bool is_const, InvokeNode* invoke)
    : is_const_(is_const)
    , invoke_(invoke) {
}

IdentifierNode::IdentifierNode(int id, const char* value, Location location)
    : id_(id)
    , value_(value)
    , location_(location) {
}

StringInterpolationNode::StringInterpolationNode(
    List<LiteralStringNode*> strings,
    List<ExpressionNode*> expressions)
    : strings_(strings)
    , expressions_(expressions) {
}

FunctionExpressionNode::FunctionExpressionNode(
    List<VariableDeclarationNode*> parameters,
    TreeNode* body)
    : parameters_(parameters)
    , body_(body) {
}

ThrowNode::ThrowNode(ExpressionNode* expression)
    : expression_(expression) {
}

LiteralIntegerNode::LiteralIntegerNode(int64 value)
    : value_(value) {
}

LiteralDoubleNode::LiteralDoubleNode(double value)
    : value_(value) {
}

LiteralStringNode::LiteralStringNode(const char* value)
    : value_(value) {
}

LiteralBooleanNode::LiteralBooleanNode(bool value)
    : value_(value) {
}

LiteralListNode::LiteralListNode(bool is_const, List<ExpressionNode*> elements)
    : is_const_(is_const)
    , elements_(elements) {
}

LiteralMapNode::LiteralMapNode(bool is_const,
                               List<ExpressionNode*> keys,
                               List<ExpressionNode*> values)
    : is_const_(is_const)
    , keys_(keys)
    , values_(values) {
}

}  // namespace fletch
