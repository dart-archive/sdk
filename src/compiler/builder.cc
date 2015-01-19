// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdlib.h>

#include "src/shared/assert.h"
#include "src/shared/connection.h"
#include "src/shared/names.h"

#include "src/compiler/builder.h"
#include "src/compiler/os.h"
#include "src/compiler/parser.h"
#include "src/compiler/pretty_printer.h"
#include "src/compiler/scanner.h"
#include "src/compiler/tokens.h"

namespace fletch {

// TODO(kasperl): Move this to tokens.h?
static const Token kKeywordTokens[] = {
#define T(n, s, p) n,
KEYWORD_LIST(T)
#undef T
};

static const char* kNames[] = {
#define N(n, s) s,
NAMES_LIST(N)
#undef N
};

static Names::Id kNameIds[] = {
#define N(n, s) Names::k##n,
NAMES_LIST(N)
#undef N
};

Builder::Builder(Zone* zone, Connection* connection)
    : zone_(zone)
    , connection_(connection)
    , source_(zone)
    , identifier_root_(new(zone) TerminalTrieNode())
    , number_root_(new(zone) TerminalTrieNode())
    , nodes_(zone)
    , registry_(zone)
    , identifiers_(zone)
    , string_registry_(zone)
    , builtins_(List<int>::New(zone, Tokens::kNumberOfBuiltins)) {
  unsigned names = ARRAY_SIZE(kNames);
  for (unsigned i = 0; i < names; i++) {
    Names::Id id = static_cast<Names::Id>(ComputeCanonicalId(kNames[i]));
    ASSERT(id == kNameIds[i]);
  }

  unsigned keywords = ARRAY_SIZE(kKeywordTokens);
  for (unsigned i = 0; i < keywords; i++) {
    Token token = kKeywordTokens[i];
    const char* keyword = Tokens::Syntax(token);
    TerminalTrieNode* node = identifier_root_;
    int c;
    while ((c = *keyword++) != '\0') {
      node = node->Child(zone, c);
    }
    node->is_keyword_ = true;
    node->terminal_ = token;
    if (Tokens::IsIdentifier(token)) {
      builtins_[token - kABSTRACT] = RegisterIdentifier(Tokens::Syntax(token));
    }
  }
}

CompilationUnitNode* Builder::BuildUnit(Location location) {
  Zone zone;
  Scanner scanner(this, &zone);
  scanner.Scan(source_.GetSource(location), location);
  Parser parser(this, scanner.EncodedTokens());
  parser.ParseCompilationUnit();
  CompilationUnitNode* unit = Pop()->AsCompilationUnit();
  ASSERT(nodes_.is_empty());
  return unit;
}

List<TreeNode*> Builder::Nodes() {
  return nodes_.ToList();
}

IdentifierNode* Builder::OperatorName(Token token) {
  // TODO(kasperl): Deal with unary versus binary minus.
  return Canonicalize(Tokens::Syntax(token));
}

IdentifierNode* Builder::BuiltinName(Token token) {
  int id = builtins_[token - kABSTRACT];
  const char* value = LookupIdentifier(id);
  return new(zone()) IdentifierNode(
      id,
      value,
      Location());
}

int Builder::ComputeCanonicalId(const char* name) {
  TerminalTrieNode* node = identifier_root_;
  int c;
  const char* p = name;
  while ((c = *p++) != '\0') {
    node = node->Child(zone(), c);
  }
  if (node->is_keyword_) return -1;
  int terminal = node->terminal_;
  if (terminal < 0) {
    terminal = node->terminal_ = RegisterIdentifier(name);
  }
  return terminal;
}

IdentifierNode* Builder::Canonicalize(const char* name) {
  int terminal = ComputeCanonicalId(name);
  if (terminal < 0) return NULL;
  return new(zone()) IdentifierNode(
      terminal,
      LookupIdentifier(terminal),
      Location());
}

Native Builder::LookupNative(IdentifierNode* name, IdentifierNode* holder) {
  // TODO(kasperl): This is a terrible implementation. Use maps.
#define N(e, c, n) \
  if (Canonicalize(c)->id() == holder->id() && \
      Canonicalize(n)->id() == name->id()) return k##e;
  NATIVES_DO(N)
#undef N
  FATAL1("Cannot find native %s.", name->value());
  return static_cast<Native>(-1);
}

void Builder::DoCompilationUnit(int count) {
  List<TreeNode*> declarations = PopList(count);
  Push(new(zone()) CompilationUnitNode(declarations));
}

void Builder::DoClass(
    bool is_abstract,
    bool has_extends,
    int mixins_count,
    int implements_count,
    int count) {
  List<TreeNode*> declarations = PopList(count);
  List<TreeNode*> implements = PopList(implements_count);
  List<TreeNode*> mixins = PopList(mixins_count);
  TreeNode* super = has_extends ? Pop() : NULL;
  IdentifierNode* name = Pop()->AsIdentifier();
  Push(new(zone()) ClassNode(
      is_abstract, name, super, mixins, implements, declarations));
}

void Builder::DoCombinator(Token token, int count) {
  PopList(count);
  // TODO(ajohnsen): Push combinator.
}

void Builder::DoImport(bool has_prefix, int combinators_count) {
  IdentifierNode* prefix = has_prefix ? Pop()->AsIdentifier() : NULL;
  LiteralStringNode* uri = Pop()->AsLiteralString();
  // TODO(ajohnsen): Add combinators.
  Push(new(zone()) ImportNode(uri, prefix));
}

void Builder::DoExport(int combinators_count) {
  LiteralStringNode* uri = Pop()->AsLiteralString();
  // TODO(ajohnsen): Add combinators.
  Push(new(zone()) ExportNode(uri));
}

void Builder::DoPart() {
  LiteralStringNode* uri = Pop()->AsLiteralString();
  Push(new(zone()) PartNode(uri));
}

void Builder::DoPartOf() {
  TreeNode* name = Pop();
  Push(new(zone()) PartOfNode(name));
}

void Builder::DoTypedef(int parameter_count) {
  List<TreeNode*> parameters = PopList(parameter_count);
  IdentifierNode* name = Pop()->AsIdentifier();
  Push(new(zone()) TypedefNode(name, parameters));
}

void Builder::DoMethod(Modifiers modifiers,
                       int parameter_count,
                       int initializer_count) {
  TreeNode* body = Pop();
  List<TreeNode*> initializers = PopList(initializer_count);
  List<VariableDeclarationNode*> parameters =
      PopVariableDeclarationList(parameter_count);
  TreeNode* name = Pop();
  Push(new(zone()) MethodNode(modifiers, name, parameters, initializers, body));
}

void Builder::DoOperator(Token token,
                         Modifiers modifiers,
                         int parameter_count) {
  TreeNode* body = Pop();
  List<TreeNode*> initializers = PopList(0);  // ???
  List<VariableDeclarationNode*> parameters =
      PopVariableDeclarationList(parameter_count);
  IdentifierNode* name = (token == kSUB && parameter_count == 0) ?
      Canonicalize("unary-") :
      OperatorName(token);
  Push(new(zone()) MethodNode(modifiers, name, parameters, initializers, body));
}

void Builder::DoBlock(int count) {
  List<TreeNode*> statements = PopList(count);
  Push(new(zone()) BlockNode(statements));
}

void Builder::DoVariableDeclarationStatement(Modifiers modifiers, int count) {
  List<VariableDeclarationNode*> declarations =
      PopVariableDeclarationList(count);
  Push(new(zone()) VariableDeclarationStatementNode(modifiers, declarations));
}

void Builder::DoVariableDeclaration(Modifiers modifiers, bool has_initializer) {
  ExpressionNode* value = (has_initializer) ? Pop()->AsExpression() : NULL;
  IdentifierNode* name = Pop()->AsIdentifier();
  Push(new(zone()) VariableDeclarationNode(name, value, modifiers));
}

void Builder::DoIf(bool has_else) {
  StatementNode* if_false = has_else
      ? Pop()->AsStatement()
      : NULL;
  StatementNode* if_true = Pop()->AsStatement();
  ExpressionNode* condition = Pop()->AsExpression();
  Push(new(zone()) IfNode(condition, if_true, if_false));
}

void Builder::DoFor(bool has_condition, int count) {
  StatementNode* body = Pop()->AsStatement();
  List<TreeNode*> increments = PopList(count);
  ExpressionNode* condition = has_condition ? Pop()->AsExpression() : NULL;
  StatementNode* initializer = Pop()->AsStatement();
  Push(new(zone()) ForNode(initializer, condition, increments, body));
}

void Builder::DoForIn(Token token) {
  StatementNode* body = Pop()->AsStatement();
  ExpressionNode* expression = Pop()->AsExpression();
  VariableDeclarationNode* var = Pop()->AsVariableDeclaration();
  Push(new(zone()) ForInNode(token, var, expression, body));
}

void Builder::DoWhile() {
  StatementNode* body = Pop()->AsStatement();
  ExpressionNode* condition = Pop()->AsExpression();
  Push(new(zone()) WhileNode(condition, body));
}

void Builder::DoBreak(bool has_identifier) {
  IdentifierNode* label = has_identifier ? Pop()->AsIdentifier() : NULL;
  Push(new(zone()) BreakNode(label));
}

void Builder::DoContinue(bool has_identifier) {
  IdentifierNode* label = has_identifier ? Pop()->AsIdentifier() : NULL;
  Push(new(zone()) ContinueNode(label));
}

void Builder::DoDoWhile() {
  ExpressionNode* condition = Pop()->AsExpression();
  StatementNode* body = Pop()->AsStatement();
  Push(new(zone()) DoWhileNode(condition, body));
}

void Builder::DoReturn(bool has_expression) {
  ExpressionNode* value = has_expression
      ? Pop()->AsExpression()
      : NULL;
  Push(new(zone()) ReturnNode(value));
}

void Builder::DoAssert() {
  ExpressionNode* condition = Pop()->AsExpression();
  Push(new(zone()) AssertNode(condition));
}

void Builder::DoCase(int count) {
  List<TreeNode*> statements = PopList(count);
  ExpressionNode* condition = Pop()->AsExpression();
  Push(new(zone()) CaseNode(condition, statements));
}

void Builder::DoSwitch(int case_count, int default_statements_count) {
  List<TreeNode*> default_statements = PopList(default_statements_count);
  List<TreeNode*> cases = PopList(case_count);
  ExpressionNode* value = Pop()->AsExpression();
  Push(new(zone()) SwitchNode(value, cases, default_statements));
}

void Builder::DoCatch(bool has_type, int identifiers_count) {
  BlockNode* block = Pop()->AsBlock();
  VariableDeclarationNode* stack_trace_name =
      (identifiers_count == 2) ? Pop()->AsVariableDeclaration() : NULL;
  VariableDeclarationNode* exception_name =
      (identifiers_count >= 1) ? Pop()->AsVariableDeclaration() : NULL;
  TreeNode* type = has_type ? Pop() : NULL;
  Push(new(zone()) CatchNode(type, exception_name, stack_trace_name, block));
}

void Builder::DoTry(int catch_count, bool has_finally) {
  BlockNode* finally_block = has_finally ? Pop()->AsBlock() : NULL;
  List<TreeNode*> catches = PopList(catch_count);
  BlockNode* block = Pop()->AsBlock();
  Push(new(zone()) TryNode(block, catches, finally_block));
}

void Builder::DoLabelledStatement() {
  StatementNode* statement = Pop()->AsStatement();
  IdentifierNode* name = Pop()->AsIdentifier();
  Push(new(zone()) LabelledStatementNode(name, statement));
}

void Builder::DoRethrow() {
  Push(new(zone()) RethrowNode());
}

void Builder::DoThrow() {
  ExpressionNode* expression = Pop()->AsExpression();
  Push(new(zone()) ThrowNode(expression));
}

void Builder::DoAssign(Token token) {
  ExpressionNode* value = Pop()->AsExpression();
  ExpressionNode* target = Pop()->AsExpression();
  Push(new(zone()) AssignNode(token, target, value));
}

void Builder::DoBinary(Token token) {
  ExpressionNode* right = Pop()->AsExpression();
  ExpressionNode* left = Pop()->AsExpression();
  Push(new(zone()) BinaryNode(token, left, right));
}

void Builder::DoUnary(Token token, bool prefix) {
  ExpressionNode* expression = Pop()->AsExpression();
  Push(new(zone()) UnaryNode(token, prefix, expression));
}

void Builder::DoDot() {
  IdentifierNode* name = Pop()->AsIdentifier();
  ExpressionNode* object = Pop()->AsExpression();
  Push(new(zone()) DotNode(object, name));
}

void Builder::DoCascadeReceiver(Token token) {
  ExpressionNode* object = Pop()->AsExpression();
  Push(new(zone()) CascadeReceiverNode(token, object));
}

void Builder::DoCascade() {
  ExpressionNode* expression = Pop()->AsExpression();
  Push(new(zone()) CascadeNode(expression));
}

void Builder::DoInvoke(int count, int named_count) {
  List<ExpressionNode*> arguments = List<ExpressionNode*>::New(zone(), count);
  List<IdentifierNode*> named_arguments =
      List<IdentifierNode*>::New(zone(), named_count);
  int unnamed_count = count - named_count;
  for (int i = count - 1; i >= 0; i--) {
    arguments[i] = Pop()->AsExpression();
    if (i >= unnamed_count) {
      named_arguments[i - unnamed_count] = Pop()->AsIdentifier();
    }
  }
  ExpressionNode* target = Pop()->AsExpression();
  Push(new(zone()) InvokeNode(target, arguments, named_arguments));
}

void Builder::DoIndex() {
  ExpressionNode* key = Pop()->AsExpression();
  ExpressionNode* target = Pop()->AsExpression();
  Push(new(zone()) IndexNode(target, key));
}

void Builder::DoConditional() {
  ExpressionNode* if_false = Pop()->AsExpression();
  ExpressionNode* if_true = Pop()->AsExpression();
  ExpressionNode* condition = Pop()->AsExpression();
  Push(new(zone()) ConditionalNode(condition, if_true, if_false));
}

void Builder::DoIs(bool is_not) {
  TreeNode* type = Pop();
  ExpressionNode* object = Pop()->AsExpression();
  Push(new(zone()) IsNode(is_not, object, type));
}

void Builder::DoAs() {
  TreeNode* type = Pop();
  ExpressionNode* object = Pop()->AsExpression();
  Push(new(zone()) AsNode(object, type));
}

void Builder::DoNew(bool is_const) {
  // TODO(kasperl): Deal with type arguments.
  InvokeNode* invoke = Pop()->AsInvoke();
  Push(new(zone()) NewNode(is_const, invoke));
}

void Builder::DoFunctionExpression(int parameter_count) {
  TreeNode* body = Pop();
  List<VariableDeclarationNode*> parameters =
      PopVariableDeclarationList(parameter_count);
  Push(new(zone()) FunctionExpressionNode(parameters, body));
}

void Builder::DoEmptyStatement() {
  Push(new(zone()) EmptyStatementNode());
}

void Builder::DoExpressionStatement() {
  ExpressionNode* expression = Pop()->AsExpression();
  Push(new(zone()) ExpressionStatementNode(expression));
}

void Builder::DoParenthesizedExpression(Location location) {
  ExpressionNode* expression = Pop()->AsExpression();
  Push(new(zone()) ParenthesizedNode(location, expression));
}

void Builder::DoString(int count) {
  // If one, it's already on the stack.
  if (count == 1) return;
  ListBuilder<char, 256> chars(zone());
  List<TreeNode*> parts = PopList(count);
  for (int i = 0; i < count; i++) {
    LiteralStringNode* node = parts[i]->AsLiteralString();
    const char* value = node->value();
    int length = strlen(value);
    for (int j = 0; j < length; j++) chars.Add(value[j]);
  }
  chars.Add('\0');
  Push(new(zone()) LiteralStringNode(chars.ToList().data()));
}

void Builder::DoStringInterpolation(int count) {
  List<ExpressionNode*> expressions =
      List<ExpressionNode*>::New(zone(), count);
  List<LiteralStringNode*> strings =
      List<LiteralStringNode*>::New(zone(), count + 1);
  strings[count] = Pop()->AsLiteralString();
  for (int i = count - 1; i >= 0; i--) {
    expressions[i] = Pop()->AsExpression();
    strings[i] = Pop()->AsLiteralString();
  }
  Push(new(zone()) StringInterpolationNode(strings, expressions));
}

void Builder::DoThis() {
  Push(new(zone()) ThisNode());
}

void Builder::DoSuper() {
  Push(new(zone()) SuperNode());
}

void Builder::DoNull() {
  Push(new(zone()) NullNode());
}

void Builder::DoBoolean(bool value) {
  Push(new(zone()) LiteralBooleanNode(value));
}

void Builder::DoList(bool is_const, int count) {
  List<ExpressionNode*> elements = PopExpressionList(count);
  Push(new(zone()) LiteralListNode(is_const, elements));
}

void Builder::DoMap(bool is_const, int count) {
  List<ExpressionNode*> keys = List<ExpressionNode*>::New(zone(), count);
  List<ExpressionNode*> values  = List<ExpressionNode*>::New(zone(), count);
  for (int i = count - 1; i >= 0; i--) {
    values[i] = Pop()->AsExpression();
    keys[i] = Pop()->AsExpression();
  }
  Push(new(zone()) LiteralMapNode(is_const, keys, values));
}

void Builder::DoReference(int id) {
  Push(Lookup(id));
}

void Builder::DoIdentifier(int id, Location location) {
  const char* value = LookupIdentifier(id);
  Push(new(zone()) IdentifierNode(id, value, location));
}

void Builder::DoStringReference(int id) {
  Push(LookupString(id));
}

void Builder::DoBuiltin(Token token) {
  ASSERT(Tokens::IsIdentifier(token) && token != kIDENTIFIER);
  DoIdentifier(builtins_[token - kABSTRACT], Location());
}

int Builder::RegisterInteger(int64 value) {
  ASSERT(value >= 0);
  int id = registry_.length();
  registry_.Add(new(zone()) LiteralIntegerNode(value));
  return id;
}

int Builder::RegisterDouble(double value) {
  int id = registry_.length();
  registry_.Add(new(zone()) LiteralDoubleNode(value));
  return id;
}

int Builder::RegisterIdentifier(const char* value) {
  int id = identifiers_.length();
  identifiers_.Add(value);
  return id;
}

int Builder::RegisterString(const char* value) {
  int id = string_registry_.length();
  string_registry_.Add(new(zone()) LiteralStringNode(value));
  return id;
}

void Builder::ReportError(Location location, const char* format, ...) {
  va_list args;
  va_start(args, format);
  ReportError(location, format, args);
  va_end(args);
}

void Builder::ReportError(Location location, const char* format, va_list args) {
  const char* file_path = source()->GetFilePath(location);
  fprintf(stderr, "%s: ", file_path);
  vfprintf(stderr, format, args);
  fprintf(stderr, "\n");
  if (!location.IsInvalid()) {
    int line_length = 0;
    const char* line = source()->GetLine(location, &line_length);
    fprintf(stderr, "%.*s\n", line_length, line);
    const char* src = source()->GetSource(location);
    int offset = src - line;
    fprintf(stderr, "%*s\n", offset + 1, "^");
  }

  if (connection_ != NULL) {
    // TODO(kasperl): Make the protocol for reporting a compile-time
    // error much cleaner.
    if (connection_ != NULL) {
      connection_->Send(Connection::kCompilerError);
      delete connection_;
    }
  }

  exit(1);
}

List<TreeNode*> Builder::PopList(int n) {
  List<TreeNode*> result = List<TreeNode*>::New(zone(), n);
  for (int i = n - 1; i >= 0; i--) result[i] = Pop();
  return result;
}

List<ExpressionNode*> Builder::PopExpressionList(int n) {
  List<ExpressionNode*> result = List<ExpressionNode*>::New(zone(), n);
  for (int i = n - 1; i >= 0; i--) result[i] = Pop()->AsExpression();
  return result;
}

List<VariableDeclarationNode*> Builder::PopVariableDeclarationList(int n) {
  List<VariableDeclarationNode*> result =
      List<VariableDeclarationNode*>::New(zone(), n);
  for (int i = n - 1; i >= 0; i--) result[i] = Pop()->AsVariableDeclaration();
  return result;
}

}  // namespace fletch
