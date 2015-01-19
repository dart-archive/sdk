// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/compiler/pretty_printer.h"

namespace fletch {

void PrettyPrinter::DoLibrary(LibraryNode* node) {
  node->unit()->Accept(this);
}

void PrettyPrinter::DoCompilationUnit(CompilationUnitNode* node) {
  List<TreeNode*> declarations = node->declarations();
  for (int i = 0; i < declarations.length(); i++) {
    if (i != 0) buffer()->Print("\n");
    declarations[i]->Accept(this);
  }
}

void PrettyPrinter::DoImport(ImportNode* node) {
  buffer()->Print("import ");
  node->uri()->Accept(this);
  if (node->has_prefix()) {
    buffer()->Print(" as ");
    node->prefix()->Accept(this);
  }
  buffer()->Print(";");
}

void PrettyPrinter::DoExport(ExportNode* node) {
  buffer()->Print("export ");
  node->uri()->Accept(this);
  buffer()->Print(";");
}

void PrettyPrinter::DoPart(PartNode* node) {
  buffer()->Print("part ");
  node->uri()->Accept(this);
  buffer()->Print(";");
}

void PrettyPrinter::DoPartOf(PartOfNode* node) {
  buffer()->Print("part of ");
  node->name()->Accept(this);
  buffer()->Print(";");
}

void PrettyPrinter::DoClass(ClassNode* node) {
  if (node->is_abstract()) buffer()->Print("abstract ");
  buffer()->Print("class %s ", node->name()->value());
  if (node->has_super()) {
    buffer()->Print("extends ");
    node->super()->Accept(this);
    buffer()->Print(" ");
    if (node->has_mixins()) {
      List<TreeNode*> mixins = node->mixins();
      for (int i = 0; i < mixins.length(); i++) {
        buffer()->Print((i == 0) ? "with " : ",");
        mixins[i]->Accept(this);
      }
      buffer()->Print(" ");
    }
  }
  List<TreeNode*> implements = node->implements();
  for (int i = 0; i < implements.length(); i++) {
    buffer()->Print((i == 0) ? "implements " : ",");
    implements[i]->Accept(this);
  }
  buffer()->Print("{\n");
  List<TreeNode*> declarations = node->declarations();
  for (int i = 0; i < declarations.length(); i++) {
    declarations[i]->Accept(this);
    buffer()->Print("\n");
  }
  buffer()->Print("}");
}

void PrettyPrinter::DoTypedef(TypedefNode* node) {
  buffer()->Print("typedef %s(", node->name()->value());
  List<TreeNode*> parameters = node->parameters();
  for (int i = 0; i < parameters.length(); i++) {
    if (i != 0) buffer()->Print(",");
    parameters[i]->AsVariableDeclaration()->name()->Accept(this);
  }
  buffer()->Print(");");
  if (verbose()) buffer()->Print("\n");
}

void PrettyPrinter::DoMethod(MethodNode* node) {
  // TODO(ajohnsen): Cleanup this method.
  if (node->modifiers().is_static()) buffer()->Print("static ");
  if (node->modifiers().is_const()) buffer()->Print("const ");
  if (node->modifiers().is_factory()) buffer()->Print("factory ");
  if (node->modifiers().is_get()) {
    buffer()->Print("get ");
    node->name()->Accept(this);
  } else {
    if (node->modifiers().is_set()) buffer()->Print("set ");
    node->name()->Accept(this);
    buffer()->Print("(");
    List<VariableDeclarationNode*> parameters = node->parameters();
    Token token = kEOF;
    for (int i = 0; i < parameters.length(); i++) {
      VariableDeclarationNode* var = parameters[i];
      Modifiers modifiers = var->modifiers();
      if (modifiers.is_named()) {
        if (token != kRBRACE) {
          if (token != kEOF) buffer()->Print("%s", Tokens::Syntax(token));
          if (i != 0) buffer()->Print(",");
          buffer()->Print("{");
        } else {
          if (i != 0) buffer()->Print(",");
        }
        token = kRBRACE;
      } else if (modifiers.is_positional()) {
        if (token != kRBRACK) {
          if (token != kEOF) buffer()->Print("%s", Tokens::Syntax(token));
          if (i != 0) buffer()->Print(",");
          buffer()->Print("[");
        } else {
          if (i != 0) buffer()->Print(",");
        }
        token = kRBRACK;
      } else {
        if (i != 0) buffer()->Print(",");
      }
      var->name()->Accept(this);
      if (var->has_initializer()) {
        if (modifiers.is_named()) buffer()->Print(":");
        if (modifiers.is_positional()) buffer()->Print("=");
        var->value()->Accept(this);
      }
    }
    if (token != kEOF) buffer()->Print("%s", Tokens::Syntax(token));
    buffer()->Print(")");
    if (verbose()) buffer()->Print(" ");
    List<TreeNode*> initializers = node->initializers();
    if (!initializers.is_empty()) {
      buffer()->Print(":");
      if (verbose()) buffer()->Print(" ");
      for (int i = 0; i < initializers.length(); i++) {
        if (i != 0) {
          buffer()->Print(",");
          if (verbose()) buffer()->Print(" ");
        }
        initializers[i]->Accept(this);
      }
    }
  }
  if (node->body()->IsExpression()) {
    buffer()->Print("=>");
    node->body()->Accept(this);
    buffer()->Print(";");
  } else if (node->body()->IsReturn()) {
    buffer()->Print("=");
    node->body()->AsReturn()->value()->Accept(this);
    buffer()->Print(";");
  } else {
    node->body()->Accept(this);
  }
  if (verbose()) buffer()->Print("\n");
}

void PrettyPrinter::DoBlock(BlockNode* node) {
  buffer()->Print("{");
  if (verbose()) buffer()->Print("\n");
  List<TreeNode*> statements = node->statements();
  for (int i = 0; i < statements.length(); i++) {
    if (verbose()) buffer()->Print("  ");
    statements[i]->Accept(this);
    if (verbose()) buffer()->Print("\n");
  }
  buffer()->Print("}");
}

void PrettyPrinter::DoVariableDeclarationStatement(
    VariableDeclarationStatementNode* node) {
  if (node->modifiers().is_static()) buffer()->Print("static ");
  if (node->modifiers().is_const()) {
    buffer()->Print("const ");
  } else if (node->modifiers().is_final()) {
    buffer()->Print("final ");
  } else {
    buffer()->Print("var ");
  }
  List<VariableDeclarationNode*> declarations = node->declarations();
  for (int i = 0; i < declarations.length(); i++) {
    if (i != 0) buffer()->Print(",");
    VariableDeclarationNode* variable = declarations[i];
    buffer()->Print("%s", variable->name()->value());
    if (variable->has_initializer()) {
      buffer()->Print("=");
      variable->value()->Accept(this);
    }
  }
  buffer()->Print(";");
}

void PrettyPrinter::DoEmptyStatement(EmptyStatementNode* node) {
  buffer()->Print(";");
}

void PrettyPrinter::DoExpressionStatement(ExpressionStatementNode* node) {
  node->expression()->Accept(this);
  buffer()->Print(";");
}

void PrettyPrinter::DoIf(IfNode* node) {
  buffer()->Print("if(");
  node->condition()->Accept(this);
  buffer()->Print(")");
  node->if_true()->Accept(this);
  if (node->has_else()) {
    buffer()->Print("else ");
    node->if_false()->Accept(this);
  }
}

void PrettyPrinter::DoFor(ForNode* node) {
  buffer()->Print("for(");
  node->initializer()->Accept(this);
  if (node->has_condition()) node->condition()->Accept(this);
  buffer()->Print(";");
  List<TreeNode*> increments = node->increments();
  for (int i = 0; i < increments.length(); i++) {
    if (i != 0) buffer()->Print(",");
    increments[i]->Accept(this);
  }
  buffer()->Print(")");
  node->body()->Accept(this);
}

void PrettyPrinter::DoForIn(ForInNode* node) {
  buffer()->Print("for(");
  if (node->token() != kEOF) {
    buffer()->Print("%s ", Tokens::Syntax(node->token()));
  }
  node->var()->name()->Accept(this);
  buffer()->Print(" in ");
  node->expression()->Accept(this);
  buffer()->Print(")");
  node->body()->Accept(this);
}

void PrettyPrinter::DoWhile(WhileNode* node) {
  buffer()->Print("while(");
  node->condition()->Accept(this);
  buffer()->Print(")");
  node->body()->Accept(this);
}

void PrettyPrinter::DoDoWhile(DoWhileNode* node) {
  buffer()->Print("do");
  node->body()->Accept(this);
  buffer()->Print("while(");
  node->condition()->Accept(this);
  buffer()->Print(");");
}

void PrettyPrinter::DoBreak(BreakNode* node) {
  buffer()->Print("break");
  if (node->has_label()) buffer()->Print(" %s", node->label()->value());
  buffer()->Print(";");
}

void PrettyPrinter::DoContinue(ContinueNode* node) {
  buffer()->Print("continue");
  if (node->has_label()) buffer()->Print(" %s", node->label()->value());
  buffer()->Print(";");
}

void PrettyPrinter::DoReturn(ReturnNode* node) {
  buffer()->Print("return");
  if (node->value() != NULL) {
    buffer()->Print(" ");
    node->value()->Accept(this);
  }
  buffer()->Print(";");
}

void PrettyPrinter::DoAssert(AssertNode* node) {
  buffer()->Print("assert(");
  node->condition()->Accept(this);
  buffer()->Print(");");
}

void PrettyPrinter::DoCase(CaseNode* node) {
  buffer()->Print("case ");
  node->condition()->Accept(this);
  buffer()->Print(":");
  List<TreeNode*> statements = node->statements();
  for (int i = 0; i < statements.length(); i++) {
    if (verbose()) buffer()->Print("  ");
    statements[i]->Accept(this);
    if (verbose()) buffer()->Print("\n");
  }
}

void PrettyPrinter::DoSwitch(SwitchNode* node) {
  buffer()->Print("switch(");
  node->value()->Accept(this);
  buffer()->Print("){");
  List<TreeNode*> cases = node->cases();
  for (int i = 0; i < cases.length(); i++) {
    cases[i]->Accept(this);
  }
  List<TreeNode*> statements = node->default_statements();
  buffer()->Print("default:");
  for (int i = 0; i < statements.length(); i++) {
    if (verbose()) buffer()->Print("  ");
    statements[i]->Accept(this);
    if (verbose()) buffer()->Print("\n");
  }
  buffer()->Print("}");
}

void PrettyPrinter::DoCatch(CatchNode* node) {
  if (node->has_type()) {
    buffer()->Print("on ");
    node->type()->Accept(this);
    buffer()->Print(" ");
  }
  if (node->has_exception_name()) {
    buffer()->Print("catch(");
    node->exception_name()->name()->Accept(this);
    if (node->has_stack_trace_name()) {
      buffer()->Print(",");
      node->stack_trace_name()->name()->Accept(this);
    }
    buffer()->Print(")");
  }
  node->block()->Accept(this);
}

void PrettyPrinter::DoTry(TryNode* node) {
  buffer()->Print("try");
  node->block()->Accept(this);
  List<TreeNode*> catches = node->catches();
  for (int i = 0; i < catches.length(); i++) {
    catches[i]->Accept(this);
  }
  if (node->has_finally_block()) {
    buffer()->Print("finally");
    node->finally_block()->Accept(this);
  }
}

void PrettyPrinter::DoLabelledStatement(LabelledStatementNode* node) {
  node->name()->Accept(this);
  buffer()->Print(":");
  node->statement()->Accept(this);
}

void PrettyPrinter::DoRethrow(RethrowNode* node) {
  buffer()->Print("rethrow;");
}

void PrettyPrinter::DoParenthesized(ParenthesizedNode* node) {
  buffer()->Print("(");
  node->expression()->Accept(this);
  buffer()->Print(")");
}

void PrettyPrinter::DoAssign(AssignNode* node) {
  node->target()->Accept(this);
  buffer()->Print("%s", Tokens::Syntax(node->token()));
  node->value()->Accept(this);
}

void PrettyPrinter::DoUnary(UnaryNode* node) {
  const char* syntax = Tokens::Syntax(node->token());
  buffer()->Print("(");
  if (node->prefix()) {
    buffer()->Print("%s", syntax);
  }
  node->expression()->Accept(this);
  if (!node->prefix()) {
    buffer()->Print("%s", syntax);
  }
  buffer()->Print(")");
}

void PrettyPrinter::DoBinary(BinaryNode* node) {
  buffer()->Print("(");
  node->left()->Accept(this);
  buffer()->Print("%s", Tokens::Syntax(node->token()));
  node->right()->Accept(this);
  buffer()->Print(")");
}

void PrettyPrinter::DoDot(DotNode* node) {
  node->object()->Accept(this);
  buffer()->Print(".%s", node->name()->value());
}

void PrettyPrinter::DoCascadeReceiver(CascadeReceiverNode* node) {
  node->object()->Accept(this);
  if (Tokens::IsIdentifier(node->token())) {
    buffer()->Print(".");
  } else {
    buffer()->Print("..");
  }
}

void PrettyPrinter::DoCascade(CascadeNode* node) {
  node->expression()->Accept(this);
}

void PrettyPrinter::DoInvoke(InvokeNode* node) {
  node->target()->Accept(this);
  buffer()->Print("(");
  List<ExpressionNode*> arguments = node->arguments();
  List<IdentifierNode*> named_arguments = node->named_arguments();
  int unnamed_count = arguments.length() - named_arguments.length();
  for (int i = 0; i < arguments.length(); i++) {
    if (i != 0) buffer()->Print(",");
    if (i >= unnamed_count) {
      named_arguments[i - unnamed_count]->Accept(this);
      buffer()->Print(":");
    }
    arguments[i]->Accept(this);
  }
  buffer()->Print(")");
}

void PrettyPrinter::DoIndex(IndexNode* node) {
  node->target()->Accept(this);
  buffer()->Print("[");
  node->key()->Accept(this);
  buffer()->Print("]");
}

void PrettyPrinter::DoConditional(ConditionalNode* node) {
  node->condition()->Accept(this);
  buffer()->Print("?");
  node->if_true()->Accept(this);
  buffer()->Print(":");
  node->if_false()->Accept(this);
}

void PrettyPrinter::DoIs(IsNode* node) {
  node->object()->Accept(this);
  buffer()->Print((node->is_not()) ? " is! " : " is ");
  node->type()->Accept(this);
}

void PrettyPrinter::DoAs(AsNode* node) {
  node->object()->Accept(this);
  buffer()->Print(" as ");
  node->type()->Accept(this);
}

void PrettyPrinter::DoNew(NewNode* node) {
  if (node->is_const()) {
    buffer()->Print("const ");
  } else {
    buffer()->Print("new ");
  }
  node->invoke()->Accept(this);
}

void PrettyPrinter::DoIdentifier(IdentifierNode* node) {
  buffer()->Print("%s", node->value());
}

void PrettyPrinter::DoThis(ThisNode* node) {
  buffer()->Print("this");
}

void PrettyPrinter::DoSuper(SuperNode* node) {
  buffer()->Print("super");
}

void PrettyPrinter::DoNull(NullNode* node) {
  buffer()->Print("null");
}

void PrettyPrinter::DoStringInterpolation(StringInterpolationNode* node) {
  List<LiteralStringNode*> strings = node->strings();
  List<ExpressionNode*> expressions = node->expressions();
  buffer()->Print("'%s", strings[0]->value());
  int length = expressions.length();
  for (int i = 0; i < length; i++) {
    buffer()->Print("${");
    expressions[i]->Accept(this);
    buffer()->Print("}%s", strings[i + 1]->value());
  }
  buffer()->Print("'");
}

void PrettyPrinter::DoFunctionExpression(FunctionExpressionNode* node) {
  buffer()->Print("(");
  List<VariableDeclarationNode*> parameters = node->parameters();
  for (int i = 0; i < parameters.length(); i++) {
    if (i != 0) buffer()->Print(",");
    parameters[i]->Accept(this);
  }
  buffer()->Print(")");
  if (node->body()->IsExpression()) {
    buffer()->Print("=>");
  }
  node->body()->Accept(this);
}

void PrettyPrinter::DoLiteralInteger(LiteralIntegerNode* node) {
  buffer()->Print("%d", node->value());
}

void PrettyPrinter::DoLiteralDouble(LiteralDoubleNode* node) {
  buffer()->Print("%F", node->value());
}

void PrettyPrinter::DoLiteralString(LiteralStringNode* node) {
  buffer()->Print("'%s'", node->value());
}

void PrettyPrinter::DoLiteralBoolean(LiteralBooleanNode* node) {
  if (node->value()) {
    buffer()->Print("true");
  } else {
    buffer()->Print("false");
  }
}

void PrettyPrinter::DoLiteralList(LiteralListNode* node) {
  buffer()->Print("[");
  List<ExpressionNode*> elements = node->elements();
  for (int i = 0; i < elements.length(); i++) {
    if (i != 0) buffer()->Print(",");
    elements[i]->Accept(this);
  }
  buffer()->Print("]");
}

void PrettyPrinter::DoLiteralMap(LiteralMapNode* node) {
  buffer()->Print("{");
  List<ExpressionNode*> keys = node->keys();
  List<ExpressionNode*> values = node->values();
  for (int i = 0; i < keys.length(); i++) {
    if (i != 0) buffer()->Print(",");
    keys[i]->Accept(this);
    buffer()->Print(":");
    values[i]->Accept(this);
  }
  buffer()->Print("}");
}

}  // namespace fletch
