// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_BUILDER_H_
#define SRC_COMPILER_BUILDER_H_

#include "src/compiler/list_builder.h"
#include "src/compiler/tokens.h"
#include "src/compiler/tree.h"
#include "src/compiler/trie.h"
#include "src/compiler/zone.h"

#include "src/shared/natives.h"

namespace fletch {

class Connection;

class TerminalTrieNode : public TrieNode<TerminalTrieNode> {
 public:
  TerminalTrieNode(Zone* zone, int id)
    : TrieNode(id),
      terminal_(-1),
      is_keyword_(false) {
  }

  TerminalTrieNode()
    : TrieNode(0),
      terminal_(-1),
      is_keyword_(false) {
  }

  int terminal_;
  bool is_keyword_;
};

class Builder : public StackAllocated {
 public:
  Builder(Zone* zone, Connection* connection = NULL);

  Zone* zone() const { return zone_; }
  Source* source() { return &source_; }

  TerminalTrieNode* identifier_trie() const { return identifier_root_; }
  TerminalTrieNode* number_trie() const { return number_root_; }

  CompilationUnitNode* BuildUnit(Location location);

  List<TreeNode*> Nodes();
  List<TreeNode*> Registry() { return registry_.ToList(); }
  TreeNode* Lookup(int id) { return registry_.Get(id); }
  const char* LookupIdentifier(int id) { return identifiers_.Get(id); }
  LiteralStringNode* LookupString(int id) { return string_registry_.Get(id); }

  IdentifierNode* OperatorName(Token token);
  IdentifierNode* BuiltinName(Token token);

  int ComputeCanonicalId(const char* name);
  IdentifierNode* Canonicalize(const char* name);

  Native LookupNative(IdentifierNode* name, IdentifierNode* holder);

  void DoCompilationUnit(int count);
  void DoClass(bool is_abstract,
               bool has_extends,
               int mixins_count,
               int implements_count,
               int count);
  void DoCombinator(Token token, int count);
  void DoImport(bool has_prefix, int combinators_count);
  void DoExport(int combinators_count);
  void DoPart();
  void DoPartOf();
  void DoTypedef(int parameter_count);
  void DoMethod(Modifiers modifiers,
                int parameter_count,
                int initializer_count);
  void DoOperator(Token token, Modifiers modifiers, int parameter_count);

  void DoBlock(int count);
  void DoVariableDeclarationStatement(Modifiers modifiers, int count);
  void DoVariableDeclaration(Modifiers modifers, bool has_initializer);
  void DoIf(bool has_else);
  void DoFor(bool has_condition, int count);
  void DoForIn(Token token);
  void DoWhile();
  void DoDoWhile();
  void DoBreak(bool has_identifier);
  void DoContinue(bool has_identifier);
  void DoReturn(bool has_expression);
  void DoAssert();
  void DoCase(int count);
  void DoSwitch(int cases_count, int default_statements_count);
  void DoCatch(bool has_type, int identifiers_count);
  void DoTry(int catch_count, bool has_finally);
  void DoLabelledStatement();
  void DoRethrow();
  void DoThrow();

  void DoAssign(Token token);
  void DoBinary(Token token);
  void DoUnary(Token token, bool prefix);
  void DoDot();
  void DoCascadeReceiver(Token token);
  void DoCascade();
  void DoInvoke(int count, int named_count);
  void DoIndex();
  void DoConditional();
  void DoIs(bool is_not);
  void DoAs();
  void DoNew(bool is_const);
  void DoFunctionExpression(int parameter_count);

  void DoReference(int id);
  void DoIdentifier(int id, Location location);
  void DoStringReference(int id);
  void DoBuiltin(Token token);

  void DoEmptyStatement();
  void DoExpressionStatement();
  void DoParenthesizedExpression(Location location);

  void DoThis();
  void DoSuper();
  void DoNull();
  void DoBoolean(bool value);
  void DoList(bool is_const, int count);
  void DoMap(bool is_const, int count);

  void DoString(int count);
  void DoStringInterpolation(int count);

  int RegisterInteger(int64 value);
  int RegisterDouble(double value);
  int RegisterIdentifier(const char* value);
  int RegisterString(const char* value);

  void PushIdentifier(IdentifierNode* node) { nodes_.Add(node); }

  void ReportError(Location location, const char* format, ...);
  void ReportError(Location location, const char* format, va_list args);

 private:
  Zone* const zone_;
  Connection* const connection_;
  Source source_;
  TerminalTrieNode* const identifier_root_;
  TerminalTrieNode* const number_root_;
  ListBuilder<TreeNode*, 64> nodes_;
  ListBuilder<TreeNode*, 1024> registry_;
  ListBuilder<const char*, 1024> identifiers_;
  ListBuilder<LiteralStringNode*, 1024> string_registry_;
  List<int> builtins_;

  TreeNode* Top() const { return nodes_.last(); }
  TreeNode* Pop() { return nodes_.RemoveLast(); }
  void Push(TreeNode* node) { nodes_.Add(node); }
  List<TreeNode*> PopList(int n);
  List<ExpressionNode*> PopExpressionList(int n);
  List<VariableDeclarationNode*> PopVariableDeclarationList(int n);
};

}  // namespace fletch

#endif  // SRC_COMPILER_BUILDER_H_
