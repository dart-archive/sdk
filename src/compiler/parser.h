// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_PARSER_H_
#define SRC_COMPILER_PARSER_H_

#include "src/compiler/list.h"
#include "src/compiler/scanner.h"
#include "src/compiler/zone.h"

namespace fletch {

class Builder;

class Parser : public StackAllocated {
 public:
  Parser(Builder* builder, List<TokenInfo> tokens);

  Builder* builder() const { return builder_; }

  void ParseCompilationUnit();
  void ParseToplevelDeclaration();
  void ParseImport();
  void ParseExport();
  int ParseCombinators();
  void ParsePart();
  void ParseClass();
  int ParseExtends(bool require_with);
  int ParseImplements();
  void ParseTypedef();
  void ParseMember();
  void ParseField();
  void ParseMethod(Modifiers modifiers);
  void ParseOperator(Modifiers modifiers);
  Modifiers ParseMethodBody(Modifiers modifiers);

  void ParseFormalParameter(Token token);
  int ParseFormalParameters();
  int ParseInitializers();

  void ParseBlock();
  void ParseStatement();
  void ParseVariableDeclarationStatement();
  void ParseVariableDeclarationStatementRest(
      Modifiers modifiers,
      bool skip_first);

  void ParseIf();
  void ParseFor();
  void ParseForInRest(Token token);
  void ParseWhile();
  void ParseDoWhile();
  void ParseBreak();
  void ParseContinue();
  void ParseReturn();
  void ParseAssert();
  void ParseSwitch();
  void ParseTry();

  void ParseExpression();
  void ParseExpressionWithoutCascade();
  void ParseThrow();
  void ParsePrecedence(int precedence,
                       bool allow_function = true,
                       bool allow_cascade = true);
  void ParseCascadeRest();
  void ParsePostfixRest();
  void ParseInvokeRest();
  void ParseIndexRest();
  void ParseConditionalRest();
  void ParseIsRest();
  void ParseAsRest();

  void ParseUnary(bool allow_function);
  void ParsePrimary(bool allow_function);
  void ParseNew(bool is_const);
  void ParseFunctionExpression();

  void ParseIdentifier();
  void ParseQualified();
  void ParseFullyQualified();

  void ParseList(bool typed, bool is_const);
  void ParseMap(bool typed, bool is_const);
  void ParseInteger();
  void ParseDouble();
  void ParseStringNoInterpolation();
  void ParseString();
  void ParseSymbolLiteral();

  void SkipOptionalType();
  void SkipType();
  void SkipQualified();
  void SkipFullyQualified();
  void SkipIdentifier();
  void SkipOptionalTypeAnnotation();
  void SkipMetadata();
  void SkipFormalParameters();

  Token PeekAfterType();
  Token PeekAfterFormalParameters();
  Token PeekAfterIdentifier();
  Token PeekNext();
  bool PeekIsNamedArgument();
  bool PeekIsMemberStart();
  bool PeekIsGetter();
  bool PeekIsSetter();
  bool PeekIsRedirectingFactoryConstructor();

  bool IsFunctionExpression();
  bool IsLabelledStatement();

 private:
  Builder* const builder_;
  TokenStream stream_;
  Token peek_;

  TokenStream* stream() { return &stream_; }
  void RefreshPeek() { peek_ = stream_.Current(); }

  inline void Advance();
  void Expect(Token token);
  bool Optional(Token token);

  void Error(const char* format, ...);

  friend class Lookahead;
};

}  // namespace fletch

#endif  // SRC_COMPILER_PARSER_H_
