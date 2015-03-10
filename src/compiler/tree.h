// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_TREE_H_
#define SRC_COMPILER_TREE_H_

#include "src/compiler/allocation.h"
#include "src/compiler/list.h"
#include "src/compiler/tokens.h"

#include "src/shared/bytecodes.h"

namespace fletch {

class LibraryElement;
class Scope;
class DeclarationEntry;
class TreeNode;

#define DO_GENERAL_NODES(V)                                                  \
  V(Library)                                                                 \
  V(CompilationUnit)                                                         \
  V(Import)                                                                  \
  V(Export)                                                                  \
  V(Part)                                                                    \
  V(PartOf)                                                                  \
  V(Class)                                                                   \
  V(Typedef)                                                                 \
  V(Method)                                                                  \
  V(Statement)                                                               \
  V(Expression)                                                              \
  V(VariableDeclaration)                                                     \

#define DO_STATEMENT_NODES(V)                                                \
  V(Block)                                                                   \
  V(VariableDeclarationStatement)                                            \
  V(EmptyStatement)                                                          \
  V(ExpressionStatement)                                                     \
  V(If)                                                                      \
  V(For)                                                                     \
  V(ForIn)                                                                   \
  V(While)                                                                   \
  V(DoWhile)                                                                 \
  V(Break)                                                                   \
  V(Continue)                                                                \
  V(Return)                                                                  \
  V(Assert)                                                                  \
  V(Case)                                                                    \
  V(Switch)                                                                  \
  V(Catch)                                                                   \
  V(Try)                                                                     \
  V(LabelledStatement)                                                       \
  V(Rethrow)                                                                 \

#define DO_EXPRESSION_NODES(V)                                               \
  V(Parenthesized)                                                           \
  V(Assign)                                                                  \
  V(Unary)                                                                   \
  V(Binary)                                                                  \
  V(Dot)                                                                     \
  V(CascadeReceiver)                                                         \
  V(Cascade)                                                                 \
  V(Invoke)                                                                  \
  V(Index)                                                                   \
  V(Conditional)                                                             \
  V(Is)                                                                      \
  V(As)                                                                      \
  V(New)                                                                     \
  V(Identifier)                                                              \
  V(This)                                                                    \
  V(Super)                                                                   \
  V(Null)                                                                    \
  V(StringInterpolation)                                                     \
  V(FunctionExpression)                                                      \
  V(Throw)                                                                   \
  V(LiteralInteger)                                                          \
  V(LiteralDouble)                                                           \
  V(LiteralString)                                                           \
  V(LiteralBoolean)                                                          \
  V(LiteralList)                                                             \
  V(LiteralMap)                                                              \

#define DO_NODES(V)                                                          \
  DO_GENERAL_NODES(V)                                                        \
  DO_STATEMENT_NODES(V)                                                      \
  DO_EXPRESSION_NODES(V)                                                     \

#define DECLARE(name) class name##Node;
DO_NODES(DECLARE)
#undef DECLARE

class TreeVisitor : public StackAllocated {
 public:
  virtual ~TreeVisitor() {}
  virtual void Do(TreeNode* node);
#define DECLARE(name) virtual void Do##name(name##Node* node);
DO_NODES(DECLARE)
#undef DECLARE
};

class TreeNode : public ZoneAllocated {
 public:
  virtual ~TreeNode() {}
  virtual void Accept(TreeVisitor* visitor) = 0;

#define DECLARE(name)                                                        \
  virtual bool Is##name() const { return false; }                            \
  virtual name##Node* As##name() { return NULL; }
DO_NODES(DECLARE)
#undef DECLARE
};

#define IMPLEMENTS(name)                                                     \
  virtual void Accept(TreeVisitor* visitor) { visitor->Do##name(this); }     \
  virtual bool Is##name() const { return true; }                             \
  virtual name##Node* As##name() { return this; }

class Modifiers {
 public:
  enum Kind {
    kCONST        = 1 << 0,
    kFINAL        = 1 << 1,
    kSTATIC       = 1 << 2,
    kEXTERNAL     = 1 << 3,
    kFACTORY      = 1 << 4,
    kGET          = 1 << 5,
    kSET          = 1 << 6,
    kTHIS         = 1 << 7,
    kPOSITIONAL   = 1 << 8,
    kNAMED        = 1 << 9,
    kNATIVE       = 1 << 10,
    // Internal markers.
    kCONSTRUCTOR  = 1 << 11,
    kBY_VALUE     = 1 << 12,
  };

  Modifiers() : value_(0) {}

  void set_const() { value_ |= kCONST; }
  bool is_const() const { return (value_ & kCONST) != 0; }

  void set_final() { value_ |= kFINAL; }
  bool is_final() const { return (value_ & kFINAL) != 0; }

  void set_static() { value_ |= kSTATIC; }
  bool is_static() const { return (value_ & kSTATIC) != 0; }

  void set_external() { value_ |= kEXTERNAL; }
  bool is_external() const { return (value_ & kEXTERNAL) != 0; }

  void set_factory() { value_ |= kFACTORY; }
  bool is_factory() const { return (value_ & kFACTORY) != 0; }

  void set_get() { value_ |= kGET; }
  bool is_get() const { return (value_ & kGET) != 0; }

  void set_set() { value_ |= kSET; }
  bool is_set() const { return (value_ & kSET) != 0; }

  void set_constructor() { value_ |= kCONSTRUCTOR; }
  bool is_constructor() const { return (value_ & kCONSTRUCTOR) != 0; }

  void set_this() { value_ |= kTHIS; }
  bool is_this() const { return (value_ & kTHIS) != 0; }

  void set_positional() { value_ |= kPOSITIONAL; }
  bool is_positional() const { return (value_ & kPOSITIONAL) != 0; }

  void set_named() { value_ |= kNAMED; }
  bool is_named() const { return (value_ & kNAMED) != 0; }

  void set_native() { value_ |= kNATIVE; }
  bool is_native() const { return (value_ & kNATIVE) != 0; }

  void set_by_value() { value_ |= kBY_VALUE; }
  bool is_by_value() const { return (value_ & kBY_VALUE) != 0; }

 private:
  int value_;
};

class LibraryNode : public TreeNode {
 public:
  explicit LibraryNode(
      CompilationUnitNode* unit,
      List<CompilationUnitNode*> parts);
  IMPLEMENTS(Library)

  CompilationUnitNode* unit() const { return unit_; }

  List<CompilationUnitNode*> parts() const { return parts_; }

  void set_scope(Scope* value) { scope_ = value; }
  Scope* scope() const { return scope_; }

 private:
  CompilationUnitNode* const unit_;
  const List<CompilationUnitNode*> parts_;
  Scope* scope_;
};

class CompilationUnitNode : public TreeNode {
 public:
  explicit CompilationUnitNode(List<TreeNode*> declarations);
  IMPLEMENTS(CompilationUnit)

  List<TreeNode*> declarations() const { return declarations_; }

 private:
  const List<TreeNode*> declarations_;
};

class ImportNode : public TreeNode {
 public:
  explicit ImportNode(LiteralStringNode* uri, IdentifierNode* prefix);
  IMPLEMENTS(Import)

  LiteralStringNode* uri() const { return uri_; }

  bool has_prefix() const { return prefix_ != NULL; }
  IdentifierNode* prefix() const { return prefix_; }

 private:
  LiteralStringNode* const uri_;
  IdentifierNode* const prefix_;
};

class ExportNode : public TreeNode {
 public:
  explicit ExportNode(LiteralStringNode* uri);
  IMPLEMENTS(Export)

  LiteralStringNode* uri() const { return uri_; }

 private:
  LiteralStringNode* const uri_;
};

class PartNode : public TreeNode {
 public:
  explicit PartNode(LiteralStringNode* uri);
  IMPLEMENTS(Part)

  LiteralStringNode* uri() const { return uri_; }

 private:
  LiteralStringNode* const uri_;
};

class PartOfNode : public TreeNode {
 public:
  explicit PartOfNode(TreeNode* name);
  IMPLEMENTS(PartOf)

  TreeNode* name() const { return name_; }

 private:
  TreeNode* const name_;
};

class ClassNode : public TreeNode {
 public:
  ClassNode(bool is_abstract,
            IdentifierNode* name,
            TreeNode* super,
            List<TreeNode*> mixins,
            List<TreeNode*> implements,
            List<TreeNode*> declarations);
  IMPLEMENTS(Class)

  int FieldCount(bool include_super = true) const;

  bool is_abstract() const { return is_abstract_; }
  bool has_super() const { return super_ != NULL; }
  bool has_mixins() const { return mixins_.length() > 0; }

  IdentifierNode* name() const { return name_; }
  TreeNode* super() const { return super_; }
  List<TreeNode*> mixins() const { return mixins_; }
  List<TreeNode*> implements() const { return implements_; }
  List<TreeNode*> declarations() const { return declarations_; }

  // TODO(kasperl): Not sure if this is the right model yet.
  int id() const { return id_; }
  void set_id(int value) { id_ = value; }

  Scope* scope() const { return scope_; }
  void set_scope(Scope* scope) { scope_ = scope; }

  LibraryNode* library() const { return library_; }
  void set_library(LibraryNode* value) { library_ = value; }

  Scope* BuildScope(Zone* zone, Scope* outer) const;

 private:
  const bool is_abstract_;
  IdentifierNode* const name_;
  TreeNode* const super_;
  const List<TreeNode*> mixins_;
  const List<TreeNode*> implements_;
  const List<TreeNode*> declarations_;
  int id_;
  Scope* scope_;
  LibraryNode* library_;
};

class TypedefNode : public TreeNode {
 public:
  TypedefNode(IdentifierNode* name,
              List<TreeNode*> parameters);
  IMPLEMENTS(Typedef)

  IdentifierNode* name() const { return name_; }
  List<TreeNode*> parameters() const { return parameters_; }

 private:
  IdentifierNode* const name_;
  const List<TreeNode*> parameters_;
};

class MethodNode : public TreeNode {
 public:
  MethodNode(Modifiers modifiers,
             TreeNode* name,
             List<VariableDeclarationNode*> parameters,
             List<TreeNode*> initializers,
             TreeNode* body);
  IMPLEMENTS(Method)

  Modifiers modifiers() const { return modifiers_; }
  TreeNode* name() const { return name_; }
  List<VariableDeclarationNode*> parameters() const { return parameters_; }
  List<TreeNode*> initializers() const { return initializers_; }
  TreeNode* body() const { return body_; }

  int OptionalParameterCount() const;

  TreeNode* owner() const { return owner_; }
  void set_owner(TreeNode* value) { owner_ = value; }

  List<VariableDeclarationNode*> captured() const { return captured_; }
  void set_captured(List<VariableDeclarationNode*> value) { captured_ = value; }

  virtual Scope* GetOwnerScope() const;

  // TODO(kasperl): Not sure if this is the right model yet.
  int id() const { return id_; }
  void set_id(int value) { id_ = value; }

  TreeNode* link() const { return link_; }
  void set_link(TreeNode* value) { link_ = value; }

 private:
  const Modifiers modifiers_;
  TreeNode* const name_;
  const List<VariableDeclarationNode*> parameters_;
  const List<TreeNode*> initializers_;
  TreeNode* const body_;
  int id_;
  TreeNode* owner_;
  List<VariableDeclarationNode*> captured_;

  // Hack.
  TreeNode* link_;
};

class StatementNode : public TreeNode {
 public:
  IMPLEMENTS(Statement)
};

class BlockNode : public StatementNode {
 public:
  explicit BlockNode(List<TreeNode*> statements);
  IMPLEMENTS(Block)

  List<TreeNode*> statements() const { return statements_; }

 private:
  const List<TreeNode*> statements_;
};

class VariableDeclarationStatementNode : public StatementNode {
 public:
  explicit VariableDeclarationStatementNode(
      Modifiers modifiers,
      List<VariableDeclarationNode*> declarations);
  IMPLEMENTS(VariableDeclarationStatement)

  Modifiers modifiers() const { return modifiers_; }

  List<VariableDeclarationNode*> declarations() const { return declarations_; }

 private:
  Modifiers modifiers_;
  const List<VariableDeclarationNode*> declarations_;
};

class VariableDeclarationNode : public TreeNode {
 public:
  VariableDeclarationNode(IdentifierNode* name,
                          ExpressionNode* value,
                          Modifiers modifiers);
  IMPLEMENTS(VariableDeclaration)

  bool has_initializer() const { return value_ != NULL; }

  IdentifierNode* name() const { return name_; }
  ExpressionNode* value() const { return value_; }
  Modifiers modifiers() const { return modifiers_; }

  TreeNode* owner() const { return owner_; }
  void set_owner(TreeNode* value) { owner_ = value; }

  DeclarationEntry* entry() const { return entry_; }
  void set_entry(DeclarationEntry* value) { entry_ = value; }

  // TODO(kasperl): Not sure if this is the right model yet.
  int setter_id() const { return setter_id_; }
  void set_setter_id(int value) { setter_id_ = value; }

  int index() const { return index_; }
  void set_index(int value) { index_ = value; }

  TreeNode* link() const { return link_; }
  void set_link(TreeNode* value) { link_ = value; }

 private:
  IdentifierNode* const name_;
  ExpressionNode* const value_;
  Modifiers modifiers_;
  TreeNode* owner_;
  DeclarationEntry* entry_;
  int setter_id_;
  int index_;

  // Hack.
  TreeNode* link_;
};

class EmptyStatementNode : public StatementNode {
 public:
  EmptyStatementNode() { }
  IMPLEMENTS(EmptyStatement)
};

class ExpressionStatementNode : public StatementNode {
 public:
  explicit ExpressionStatementNode(ExpressionNode* expression);
  IMPLEMENTS(ExpressionStatement)

  ExpressionNode* expression() const { return expression_; }

 private:
  ExpressionNode* const expression_;
};

class IfNode : public StatementNode {
 public:
  IfNode(ExpressionNode* condition,
         StatementNode* if_true,
         StatementNode* if_false);
  IMPLEMENTS(If)

  bool has_else() const { return if_false_ != NULL; }

  ExpressionNode* condition() const { return condition_; }
  StatementNode* if_true() const { return if_true_; }
  StatementNode* if_false() const { return if_false_; }

 private:
  ExpressionNode* const condition_;
  StatementNode* const if_true_;
  StatementNode* const if_false_;
};

class ForNode : public StatementNode {
 public:
  ForNode(StatementNode* initializer,
          ExpressionNode* condition,
          List<TreeNode*> increments,
          StatementNode* body);
  IMPLEMENTS(For)

  bool has_condition() const { return condition_ != NULL; }

  StatementNode* initializer() const { return initializer_; }
  ExpressionNode* condition() const { return condition_; }
  List<TreeNode*> increments() const { return increments_; }
  StatementNode* body() const { return body_; }

 private:
  StatementNode* const initializer_;
  ExpressionNode* const condition_;
  const List<TreeNode*> increments_;
  StatementNode* const body_;
};

class ForInNode : public StatementNode {
 public:
  ForInNode(Token token,
            VariableDeclarationNode* var,
            ExpressionNode* expression,
            StatementNode* body);
  IMPLEMENTS(ForIn)

  Token token() const { return token_; }
  VariableDeclarationNode* var() const { return var_; }
  ExpressionNode* expression() const { return expression_; }
  StatementNode* body() const { return body_; }

 private:
  const Token token_;
  VariableDeclarationNode* const var_;
  ExpressionNode* const expression_;
  StatementNode* const body_;
};

class WhileNode : public StatementNode {
 public:
  WhileNode(ExpressionNode* condition, StatementNode* body);
  IMPLEMENTS(While)

  ExpressionNode* condition() const { return condition_; }
  StatementNode* body() const { return body_; }

 private:
  ExpressionNode* const condition_;
  StatementNode* const body_;
};

class DoWhileNode : public StatementNode {
 public:
  DoWhileNode(ExpressionNode* condition, StatementNode* body);
  IMPLEMENTS(DoWhile)

  ExpressionNode* condition() const { return condition_; }
  StatementNode* body() const { return body_; }

 private:
  ExpressionNode* const condition_;
  StatementNode* const body_;
};

class BreakNode : public StatementNode {
 public:
  explicit BreakNode(IdentifierNode* label);
  IMPLEMENTS(Break)

  bool has_label() const { return label_ != NULL; }
  IdentifierNode* label() const { return label_; }

 private:
  IdentifierNode* const label_;
};

class ContinueNode: public StatementNode {
 public:
  explicit ContinueNode(IdentifierNode* label);
  IMPLEMENTS(Continue)

  bool has_label() const { return label_ != NULL; }
  IdentifierNode* label() const { return label_; }

 private:
  IdentifierNode* const label_;
};

class ReturnNode : public StatementNode {
 public:
  explicit ReturnNode(ExpressionNode* value);
  IMPLEMENTS(Return)

  bool has_expression() const { return value_ != NULL; }

  ExpressionNode* value() const { return value_; }

 private:
  ExpressionNode* const value_;
};

class AssertNode : public StatementNode {
 public:
  explicit AssertNode(ExpressionNode* condition);
  IMPLEMENTS(Assert)

  ExpressionNode* condition() const { return condition_; }

 private:
  ExpressionNode* const condition_;
};

class CaseNode : public StatementNode {
 public:
  explicit CaseNode(ExpressionNode* condition, List<TreeNode*> statements);
  IMPLEMENTS(Case)

  ExpressionNode* condition() const { return condition_; }
  List<TreeNode*> statements() const { return statements_; }

 private:
  ExpressionNode* const condition_;
  const List<TreeNode*> statements_;
};

class SwitchNode : public StatementNode {
 public:
  explicit SwitchNode(ExpressionNode* value,
                      List<TreeNode*> cases,
                      List<TreeNode*> default_statements);
  IMPLEMENTS(Switch)

  ExpressionNode* value() const { return value_; }
  List<TreeNode*> cases() const { return cases_; }
  List<TreeNode*> default_statements() const { return default_statements_; }

 private:
  ExpressionNode* const value_;
  const List<TreeNode*> cases_;
  const List<TreeNode*> default_statements_;
};

class CatchNode : public StatementNode {
 public:
  explicit CatchNode(TreeNode* type,
                     VariableDeclarationNode* exception_name,
                     VariableDeclarationNode* stack_trace_name,
                     BlockNode* block);
  IMPLEMENTS(Catch)

  bool has_type() const { return type_ != NULL; }
  TreeNode* type() const { return type_; }
  bool has_exception_name() const { return exception_name_ != NULL; }
  VariableDeclarationNode* exception_name() const { return exception_name_; }
  bool has_stack_trace_name() const { return stack_trace_name_ != NULL; }
  VariableDeclarationNode* stack_trace_name() const {
    return stack_trace_name_;
  }
  BlockNode* block() const { return block_; }

 private:
  TreeNode* const type_;
  VariableDeclarationNode* const exception_name_;
  VariableDeclarationNode* const stack_trace_name_;
  BlockNode* const block_;
};

class TryNode : public StatementNode {
 public:
  explicit TryNode(BlockNode* block,
                   List<TreeNode*> catches,
                   BlockNode* finally_block);
  IMPLEMENTS(Try)

  BlockNode* block() const { return block_; }
  List<TreeNode*> catches() const { return catches_; }
  bool has_finally_block() const { return finally_block_ != NULL; }
  BlockNode* finally_block() const { return finally_block_; }

 private:
  BlockNode* const block_;
  const List<TreeNode*> catches_;
  BlockNode* const finally_block_;
};

class LabelledStatementNode : public StatementNode {
 public:
  LabelledStatementNode(IdentifierNode* name, StatementNode* statement);
  IMPLEMENTS(LabelledStatement)

  IdentifierNode* name() const { return name_; }
  StatementNode* statement() const { return statement_; }

 private:
  IdentifierNode* const name_;
  StatementNode* const statement_;
};

class RethrowNode : public StatementNode {
 public:
  RethrowNode();
  IMPLEMENTS(Rethrow)
};

class ExpressionNode : public TreeNode {
 public:
  IMPLEMENTS(Expression)

  virtual Location location() const { return Location(); }
};

class ParenthesizedNode : public ExpressionNode {
 public:
  explicit ParenthesizedNode(Location location, ExpressionNode* expression);
  IMPLEMENTS(Parenthesized);

  Location location() const { return location_; }
  ExpressionNode* expression() const { return expression_; }

 private:
  const Location location_;
  ExpressionNode* const expression_;
};

class AssignNode : public ExpressionNode {
 public:
  AssignNode(Token token, ExpressionNode* target, ExpressionNode* value);
  IMPLEMENTS(Assign);

  Token token() const { return token_; }
  ExpressionNode* target() const { return target_; }
  ExpressionNode* value() const { return value_; }

 private:
  Token token_;
  ExpressionNode* const target_;
  ExpressionNode* const value_;
};

class UnaryNode : public ExpressionNode {
 public:
  UnaryNode(Token token, bool prefix, ExpressionNode* expression);
  IMPLEMENTS(Unary);

  Token token() const { return token_; }
  bool prefix() const { return prefix_; }
  ExpressionNode* expression() const { return expression_; }

 private:
  const Token token_;
  const bool prefix_;
  ExpressionNode* const expression_;
};

class BinaryNode : public ExpressionNode {
 public:
  BinaryNode(Token token, ExpressionNode* left, ExpressionNode* right);
  IMPLEMENTS(Binary);

  Token token() const { return token_; }
  ExpressionNode* left() const { return left_; }
  ExpressionNode* right() const { return right_; }

 private:
  Token token_;
  ExpressionNode* const left_;
  ExpressionNode* const right_;
};

class DotNode : public ExpressionNode {
 public:
  DotNode(ExpressionNode* object, IdentifierNode* name);
  IMPLEMENTS(Dot)

  ExpressionNode* object() const { return object_; }
  IdentifierNode* name() const { return name_; }

 private:
  ExpressionNode* const object_;
  IdentifierNode* const name_;
};

class CascadeReceiverNode : public ExpressionNode {
 public:
  explicit CascadeReceiverNode(Token token, ExpressionNode* object);
  IMPLEMENTS(CascadeReceiver)

  Token token() const { return token_; }
  ExpressionNode* object() const { return object_; }

 private:
  const Token token_;
  ExpressionNode* const object_;
};

class CascadeNode : public ExpressionNode {
 public:
  explicit CascadeNode(ExpressionNode* expression);
  IMPLEMENTS(Cascade)

  ExpressionNode* expression() const { return expression_; }

 private:
  ExpressionNode* const expression_;
};

class InvokeNode : public ExpressionNode {
 public:
  InvokeNode(ExpressionNode* target,
             List<ExpressionNode*> arguments,
             List<IdentifierNode*> named_arguments);
  IMPLEMENTS(Invoke)

  ExpressionNode* target() const { return target_; }
  List<ExpressionNode*> arguments() const { return arguments_; }
  List<IdentifierNode*> named_arguments() const { return named_arguments_; }

 private:
  ExpressionNode* const target_;
  const List<ExpressionNode*> arguments_;
  const List<IdentifierNode*> named_arguments_;
};

class IndexNode : public ExpressionNode {
 public:
  IndexNode(ExpressionNode* target, ExpressionNode* key);
  IMPLEMENTS(Index)

  ExpressionNode* target() const { return target_; }
  ExpressionNode* key() const { return key_; }

  Location location() const { return target_->location(); }

 private:
  ExpressionNode* const target_;
  ExpressionNode* const key_;
};

class ConditionalNode : public ExpressionNode {
 public:
  ConditionalNode(ExpressionNode* condition,
                  ExpressionNode* if_true,
                  ExpressionNode* if_false);
  IMPLEMENTS(Conditional)

  ExpressionNode* condition() const { return condition_; }
  ExpressionNode* if_true() const { return if_true_; }
  ExpressionNode* if_false() const { return if_false_; }

 private:
  ExpressionNode* const condition_;
  ExpressionNode* const if_true_;
  ExpressionNode* const if_false_;
};

class IsNode: public ExpressionNode {
 public:
  IsNode(bool is_not, ExpressionNode* object, TreeNode* type);
  IMPLEMENTS(Is)

  bool is_not() const { return is_not_; }
  ExpressionNode* object() const { return object_; }
  TreeNode* type() const { return type_; }

 private:
  const bool is_not_;
  ExpressionNode* const object_;
  TreeNode* const type_;
};

class AsNode: public ExpressionNode {
 public:
  AsNode(ExpressionNode* object, TreeNode* type);
  IMPLEMENTS(As)

  ExpressionNode* object() const { return object_; }
  TreeNode* type() const { return type_; }

 private:
  ExpressionNode* const object_;
  TreeNode* const type_;
};

class NewNode : public ExpressionNode {
 public:
  NewNode(bool is_const, InvokeNode* invoke);
  IMPLEMENTS(New)

  bool is_const() const { return is_const_; }
  InvokeNode* invoke() const { return invoke_; }

 private:
  const bool is_const_;
  InvokeNode* const invoke_;
};

class IdentifierNode : public ExpressionNode {
 public:
  IdentifierNode(int id, const char* value, Location location);
  IMPLEMENTS(Identifier)

  int id() const { return id_; }
  const char* value() const { return value_; }
  Location location() const { return location_; }

 private:
  const int id_;
  const char* const value_;
  const Location location_;
};

class ThisNode : public ExpressionNode {
 public:
  ThisNode() { }
  IMPLEMENTS(This)
};

class SuperNode : public ExpressionNode {
 public:
  SuperNode() { }
  IMPLEMENTS(Super)
};

class NullNode : public ExpressionNode {
 public:
  NullNode() { }
  IMPLEMENTS(Null)
};

class StringInterpolationNode : public ExpressionNode {
 public:
  StringInterpolationNode(List<LiteralStringNode*> strings,
                          List<ExpressionNode*> expressions);
  IMPLEMENTS(StringInterpolation)

  List<LiteralStringNode*> strings() const { return strings_; }
  List<ExpressionNode*> expressions() const { return expressions_; }

 private:
  const List<LiteralStringNode*> strings_;
  const List<ExpressionNode*> expressions_;
};

class FunctionExpressionNode : public ExpressionNode {
 public:
  FunctionExpressionNode(List<VariableDeclarationNode*> parameters,
                         TreeNode* body);
  IMPLEMENTS(FunctionExpression)

  List<VariableDeclarationNode*> parameters() const { return parameters_; }
  TreeNode* body() const { return body_; }

  List<VariableDeclarationNode*> captured() const { return captured_; }
  void set_captured(List<VariableDeclarationNode*> value) { captured_ = value; }

 private:
  const List<VariableDeclarationNode*> parameters_;
  TreeNode* const body_;
  List<VariableDeclarationNode*> captured_;
};

class ThrowNode : public ExpressionNode {
 public:
  explicit ThrowNode(ExpressionNode* expression);
  IMPLEMENTS(Throw)

  ExpressionNode* expression() const { return expression_; }

 private:
  ExpressionNode* const expression_;
};

class LiteralIntegerNode : public ExpressionNode {
 public:
  explicit LiteralIntegerNode(int64 value);
  IMPLEMENTS(LiteralInteger)

  int64 value() const { return value_; }

  bool IsLarge() const { return value_ < 0 || value_ > kLoadLiteralWideLimit; }

 private:
  const int64 value_;
};

class LiteralDoubleNode : public ExpressionNode {
 public:
  explicit LiteralDoubleNode(double value);
  IMPLEMENTS(LiteralDouble)

  double value() const { return value_; }

 private:
  const double value_;
};

class LiteralStringNode : public ExpressionNode {
 public:
  explicit LiteralStringNode(const char* value);
  IMPLEMENTS(LiteralString)

  const char* value() const { return value_; }

 private:
  const char* const value_;
};

class LiteralBooleanNode : public ExpressionNode {
 public:
  explicit LiteralBooleanNode(bool value);
  IMPLEMENTS(LiteralBoolean)

  bool value() const { return value_; }

 private:
  const bool value_;
};

class LiteralListNode : public ExpressionNode {
 public:
  LiteralListNode(bool is_const, List<ExpressionNode*> elements);
  IMPLEMENTS(LiteralList)

  bool is_const() const { return is_const_; }
  List<ExpressionNode*> elements() const { return elements_; }

 private:
  const bool is_const_;
  const List<ExpressionNode*> elements_;
};

class LiteralMapNode : public ExpressionNode {
 public:
  LiteralMapNode(bool is_const,
                 List<ExpressionNode*> keys,
                 List<ExpressionNode*> values);
  IMPLEMENTS(LiteralMap)

  bool is_const() const { return is_const_; }
  List<ExpressionNode*> keys() const { return keys_; }
  List<ExpressionNode*> values() const { return values_; }

 private:
  const bool is_const_;
  const List<ExpressionNode*> keys_;
  const List<ExpressionNode*> values_;
};

#undef IMPLEMENTS

}  // namespace fletch

#endif  // SRC_COMPILER_TREE_H_
