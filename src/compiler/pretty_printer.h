// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_PRETTY_PRINTER_H_
#define SRC_COMPILER_PRETTY_PRINTER_H_

#include <cstdarg>

#include "src/compiler/list_builder.h"
#include "src/compiler/string_buffer.h"
#include "src/compiler/tree.h"

namespace fletch {

class PrettyPrinter : public TreeVisitor {
 public:
  explicit PrettyPrinter(Zone* zone, bool verbose = false)
      : buffer_(zone),
        verbose_(verbose) {
  }

  const char* Output() { return buffer_.ToString(); }

  void DoLibrary(LibraryNode* node);
  void DoCompilationUnit(CompilationUnitNode* node);
  void DoImport(ImportNode* node);
  void DoExport(ExportNode* node);
  void DoPart(PartNode* node);
  void DoPartOf(PartOfNode* node);
  void DoClass(ClassNode* node);
  void DoTypedef(TypedefNode* node);
  void DoMethod(MethodNode* node);

  void DoBlock(BlockNode* node);
  void DoVariableDeclarationStatement(VariableDeclarationStatementNode* node);
  void DoExpressionStatement(ExpressionStatementNode* node);
  void DoEmptyStatement(EmptyStatementNode* node);
  void DoIf(IfNode* node);
  void DoFor(ForNode* node);
  void DoForIn(ForInNode* node);
  void DoWhile(WhileNode* node);
  void DoDoWhile(DoWhileNode* node);
  void DoBreak(BreakNode* node);
  void DoContinue(ContinueNode* node);
  void DoReturn(ReturnNode* node);
  void DoAssert(AssertNode* node);
  void DoCase(CaseNode* node);
  void DoSwitch(SwitchNode* node);
  void DoCatch(CatchNode* node);
  void DoTry(TryNode* node);
  void DoLabelledStatement(LabelledStatementNode* node);
  void DoRethrow(RethrowNode* node);

  void DoParenthesized(ParenthesizedNode* node);
  void DoAssign(AssignNode* node);
  void DoUnary(UnaryNode* node);
  void DoBinary(BinaryNode* node);
  void DoDot(DotNode* node);
  void DoCascadeReceiver(CascadeReceiverNode* node);
  void DoCascade(CascadeNode* node);
  void DoInvoke(InvokeNode* node);
  void DoIndex(IndexNode* node);
  void DoConditional(ConditionalNode* node);
  void DoIs(IsNode* node);
  void DoAs(AsNode* node);
  void DoNew(NewNode* node);
  void DoIdentifier(IdentifierNode* node);
  void DoThis(ThisNode* node);
  void DoSuper(SuperNode* node);
  void DoNull(NullNode* node);
  void DoStringInterpolation(StringInterpolationNode* node);
  void DoFunctionExpression(FunctionExpressionNode* node);
  void DoLiteralInteger(LiteralIntegerNode* node);
  void DoLiteralDouble(LiteralDoubleNode* node);
  void DoLiteralString(LiteralStringNode* node);
  void DoLiteralBoolean(LiteralBooleanNode* node);
  void DoLiteralList(LiteralListNode* node);
  void DoLiteralMap(LiteralMapNode* node);

 private:
  StringBuffer buffer_;
  bool verbose_;

  StringBuffer* buffer() { return &buffer_; }
  bool verbose() const { return verbose_; }
};

}  // namespace fletch

#endif  // SRC_COMPILER_PRETTY_PRINTER_H_
