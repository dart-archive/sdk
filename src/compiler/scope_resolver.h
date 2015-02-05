// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_SCOPE_RESOLVER_H_
#define SRC_COMPILER_SCOPE_RESOLVER_H_

#include "src/compiler/list_builder.h"
#include "src/compiler/map.h"
#include "src/compiler/tree.h"

namespace fletch {

class DeclarationEntry;

class ScopeResolver : private TreeVisitor {
 public:
  explicit ScopeResolver(Zone* zone, Scope* scope, IdentifierNode* this_name);

  void ResolveMethod(MethodNode* node, bool constructor = false);

 private:
  void DoMethod(MethodNode* node);
  void DoBlock(BlockNode* node);
  void DoExpressionStatement(ExpressionStatementNode* node);
  void DoLabelledStatement(LabelledStatementNode* node);
  void DoIf(IfNode* node);
  void DoWhile(WhileNode* node);
  void DoFor(ForNode* node);
  void DoForIn(ForInNode* node);
  void DoDoWhile(DoWhileNode* node);
  void DoSwitch(SwitchNode* node);
  void DoTry(TryNode* node);
  void DoCatch(CatchNode* node);
  void DoReturn(ReturnNode* node);

  void ImplicitScopeStatement(StatementNode* node);

  void DoVariableDeclarationStatement(VariableDeclarationStatementNode* node);
  void DoVariableDeclaration(VariableDeclarationNode* node);

  void DoFunctionExpression(FunctionExpressionNode* node);
  void DoIdentifier(IdentifierNode* node);
  void DoParenthesized(ParenthesizedNode* node);
  void DoAssign(AssignNode* node);
  void DoUnary(UnaryNode* node);
  void DoBinary(BinaryNode* node);
  void DoConditional(ConditionalNode* node);
  void DoDot(DotNode* node);
  void DoInvoke(InvokeNode* node);
  void DoIndex(IndexNode* node);
  void DoNew(NewNode* node);
  void DoThis(ThisNode* node);
  void DoLiteralList(LiteralListNode* node);
  void DoLiteralMap(LiteralMapNode* node);

  void DoStringInterpolation(StringInterpolationNode* node);

  void MarkCaptured(DeclarationEntry* entry, bool by_value);

  class FunctionMarker : public StackAllocated {
   public:
    FunctionMarker(int index, Zone* zone)
        : index_(index)
        , entries_(zone, 0) {
    }

    int index() const { return index_; }

    void MarkCaptured(VariableDeclarationNode* var);
    List<VariableDeclarationNode*> GetCaptured();

   private:
    const int index_;
    IdMap<VariableDeclarationNode*> entries_;
  };

  Zone* const zone_;
  Scope* scope_;
  IdentifierNode* this_name_;
  ListBuilder<FunctionMarker*, 8> functions_;

  List<VariableDeclarationNode*> DoFunction(
      List<VariableDeclarationNode*> parameters,
      TreeNode* body,
      bool has_this);

  Zone* zone() const { return zone_; }
  Scope* scope() const { return scope_; }
};

}  // namespace fletch

#endif  // SRC_COMPILER_SCOPE_RESOLVER_H_

