// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <cstdlib>
#include <cstdarg>

#include "src/shared/assert.h"
#include "src/compiler/builder.h"
#include "src/compiler/parser.h"

namespace fletch {

class Lookahead : public StackAllocated {
 public:
  explicit Lookahead(Parser* parser)
      : parser_(parser), saved_(parser->stream()->position()) { }

  ~Lookahead() {
    parser_->stream()->RewindTo(saved_);
    parser_->RefreshPeek();
  }

 private:
  Parser* const parser_;
  const int saved_;
};

Parser::Parser(Builder* builder, List<TokenInfo> tokens)
    : builder_(builder)
    , stream_(tokens) {
  RefreshPeek();
}

void Parser::Advance() {
  stream_.Advance();
  RefreshPeek();
}

void Parser::Expect(Token token) {
  if (peek_ != token) {
    Error("Expected '%s' but found '%s'.",
          Tokens::Syntax(token),
          Tokens::Syntax(peek_));
  }
  Advance();
}

bool Parser::Optional(Token token) {
  if (peek_ != token) return false;
  Advance();
  return true;
}

void Parser::ParseCompilationUnit() {
  if (Optional(kLIBRARY)) {
    SkipFullyQualified();
    Expect(kSEMICOLON);
  }

  int count = 0;
  while (peek_ != kEOF) {
    ParseToplevelDeclaration();
    count++;
  }
  builder()->DoCompilationUnit(count);
}

void Parser::ParseToplevelDeclaration() {
  while (peek_ == kAT) SkipMetadata();
  switch (peek_) {
    case kCLASS:
    case kABSTRACT:
      ParseClass();
      break;

    case kIMPORT:
      ParseImport();
      break;

    case kEXPORT:
      ParseExport();
      break;

    case kPART:
      ParsePart();
      break;

    case kTYPEDEF:
      ParseTypedef();
      break;

    default:
      ParseMember();
      break;
  }
}

void Parser::ParseImport() {
  Expect(kIMPORT);
  ParseStringNoInterpolation();
  bool has_prefix = Optional(kAS);
  if (has_prefix) {
    ParseIdentifier();
  }
  int combinator_count = ParseCombinators();
  Expect(kSEMICOLON);
  builder()->DoImport(has_prefix, combinator_count);
}

void Parser::ParseExport() {
  Expect(kEXPORT);
  ParseStringNoInterpolation();
  int combinator_count = ParseCombinators();
  Expect(kSEMICOLON);
  builder()->DoExport(combinator_count);
}

int Parser::ParseCombinators() {
  int combinator_count = 0;
  Token token = peek_;
  while (token == kSHOW || token == kHIDE) {
    Advance();
    int count = 0;
    do {
      ParseIdentifier();
      count++;
    } while (Optional(kCOMMA));
    builder()->DoCombinator(token, count);
    combinator_count++;
    token = peek_;
  }
  return combinator_count;
}

void Parser::ParsePart() {
  Expect(kPART);
  if (Optional(kOF)) {
    ParseFullyQualified();
    Expect(kSEMICOLON);
    builder()->DoPartOf();
    return;
  }
  ParseStringNoInterpolation();
  Expect(kSEMICOLON);
  builder()->DoPart();
}

void Parser::ParseClass() {
  bool is_abstract = Optional(kABSTRACT);
  Expect(kCLASS);
  if (peek_ != kIDENTIFIER) {
    Error("Class name must be an identifier");
  }
  ParseIdentifier();
  SkipOptionalTypeAnnotation();
  bool has_extends = false;
  int mixins_count = 0;
  int implements_count = 0;
  int member_count = 0;
  if (Optional(kASSIGN)) {
    has_extends = true;
    mixins_count = ParseExtends(true);
    implements_count = ParseImplements();
    Expect(kSEMICOLON);
  } else {
    if (Optional(kEXTENDS)) {
      has_extends = true;
      mixins_count = ParseExtends(false);
    }
    implements_count = ParseImplements();
    Expect(kLBRACE);
    while (!Optional(kRBRACE)) {
      ParseMember();
      member_count++;
    }
  }
  builder()->DoClass(
      is_abstract, has_extends, mixins_count, implements_count, member_count);
}

int Parser::ParseExtends(bool require_with) {
  ParseQualified();
  SkipOptionalTypeAnnotation();
  int mixins_count = 0;
  if (require_with || peek_ == kWITH) {
    Expect(kWITH);
    do {
      ParseQualified();
      SkipOptionalTypeAnnotation();
      mixins_count++;
    } while (Optional(kCOMMA));
  }
  return mixins_count;
}

int Parser::ParseImplements() {
  int implements_count = 0;
  if (Optional(kIMPLEMENTS)) {
    do {
      ParseQualified();
      SkipOptionalTypeAnnotation();
      implements_count++;
    } while (Optional(kCOMMA));
  }
  return implements_count;
}

void Parser::ParseTypedef() {
  if (PeekIsMemberStart()) {
    ParseMember();
    return;
  }
  Expect(kTYPEDEF);
  SkipOptionalType();
  ParseIdentifier();
  SkipOptionalTypeAnnotation();
  int parameter_count = ParseFormalParameters();
  Expect(kSEMICOLON);
  builder()->DoTypedef(parameter_count);
}

void Parser::ParseMember() {
  while (peek_ == kAT) SkipMetadata();

  Modifiers modifiers;
  if (!PeekIsMemberStart() && Optional(kEXTERNAL)) modifiers.set_external();
  while (!PeekIsMemberStart()) {
    if (Optional(kSTATIC)) {
      modifiers.set_static();
    } else if (Optional(kFINAL)) {
      modifiers.set_final();
    } else if (Optional(kCONST)) {
      modifiers.set_const();
    } else if (Optional(kFACTORY)) {
      modifiers.set_factory();
    } else {
      break;
    }
  }

  SkipOptionalType();

  if (peek_ == kOPERATOR && !PeekIsMemberStart()) {
    ParseOperator(modifiers);
  } else if (PeekIsGetter()) {
    Advance();
    modifiers.set_get();
    ParseIdentifier();
    modifiers = ParseMethodBody(modifiers);
    builder()->DoMethod(modifiers, 0, 0);
  } else if (PeekIsSetter()) {
    Advance();
    modifiers.set_set();
    ParseIdentifier();
    Expect(kLPAREN);
    ParseFormalParameter(kEOF);
    Expect(kRPAREN);
    modifiers = ParseMethodBody(modifiers);
    builder()->DoMethod(modifiers, 1, 0);
  } else if (modifiers.is_factory() &&
             PeekAfterFormalParameters() == kASSIGN) {
    ParseQualified();
    int count = ParseFormalParameters();
    Expect(kASSIGN);
    ParseFullyQualified();
    Expect(kSEMICOLON);
    builder()->DoReturn(true);
    builder()->DoMethod(modifiers, count, 0);
  } else {
    if (peek_ == kVAR) {
      Advance();
      ParseVariableDeclarationStatementRest(modifiers, false);
      return;
    }
    if (Tokens::IsIdentifier(peek_)) {
      if (PeekAfterIdentifier() == kPERIOD) {
        ParseQualified();
        ParseMethod(modifiers);
      } else {
        ParseIdentifier();
        if (peek_ == kLPAREN) {
          ParseMethod(modifiers);
        } else {
          ParseVariableDeclarationStatementRest(modifiers, true);
        }
      }
    } else {
      Error("Bad declaration name '%s'.", Tokens::Syntax(peek_));
    }
  }
}

void Parser::ParseMethod(Modifiers modifiers) {
  int parameter_count = ParseFormalParameters();
  int initializer_count = 0;
  if (peek_ == kCOLON) {
    initializer_count = ParseInitializers();
  }
  modifiers = ParseMethodBody(modifiers);
  builder()->DoMethod(modifiers, parameter_count, initializer_count);
}

void Parser::ParseOperator(Modifiers modifiers) {
  Expect(kOPERATOR);
  Token token = kEOF;
  switch (peek_) {
    case kBIT_OR:
    case kBIT_XOR:
    case kBIT_AND:
    case kBIT_NOT:

    case kINDEX:
    case kASSIGN_INDEX:

    case kSHL:
    case kSHR:

    case kADD:
    case kSUB:
    case kMUL:
    case kDIV:
    case kTRUNCDIV:
    case kMOD:

    case kEQ:
    case kLT:
    case kGT:
    case kLTE:
    case kGTE:
      token = peek_;
      Advance();
      break;

    case kGT_START:
      Advance();
      Expect(kGT);
      token = kSHR;
      break;

    default:
      Error("Bad operator name '%s'.", Tokens::Syntax(peek_));
      break;
  }
  int parameter_count = ParseFormalParameters();
  modifiers = ParseMethodBody(modifiers);
  builder()->DoOperator(token, modifiers, parameter_count);
}

Modifiers Parser::ParseMethodBody(Modifiers modifiers) {
  if (Optional(kNATIVE)) {
    // TODO(kasperl): Right now, we allow native methods to
    // be on one of two forms:
    //
    //   (1)  foo(...) native;
    //   (2)  bar(...) native catch (error) { ... }
    //
    // We should generalize this a bit.
    modifiers.set_native();
    if (Optional(kCATCH)) {
      Expect(kLPAREN);
      if (!Tokens::IsIdentifier(peek_)) {
        Error("Expect identifier in native catch block.");
        return modifiers;
      }
      int id = stream_.CurrentIndex();
      if (id != builder()->ComputeCanonicalId("error")) {
        Error("Identifier in native catch block must be named 'error'.");
        return modifiers;
      }
      Advance();
      Expect(kRPAREN);
    } else {
      Expect(kSEMICOLON);
      builder()->DoEmptyStatement();
      return modifiers;
    }
  }

  if (peek_ == kLBRACE) {
    ParseBlock();
  } else if (peek_ == kARROW) {
    Advance();
    ParseExpression();
    Expect(kSEMICOLON);
  } else {
    Expect(kSEMICOLON);
    builder()->DoEmptyStatement();
  }
  return modifiers;
}

void Parser::ParseFormalParameter(Token token) {
  Modifiers modifiers;
  if (peek_ == kVAR) {
    Advance();
  } else {
    if (Optional(kFINAL)) modifiers.set_final();
    SkipOptionalType();
    if (Optional(kTHIS)) {
      modifiers.set_this();
      Expect(kPERIOD);
    }
  }
  ParseIdentifier();
  // Skip function type parameters.
  if (peek_ == kLPAREN) {
    int delta = stream_.CurrentIndex();
    ASSERT(delta > 0);
    stream_.Skip(delta);
    RefreshPeek();
    Expect(kRPAREN);
  }
  if (token == kASSIGN) {
    modifiers.set_positional();
  } else if (token == kCOLON) {
    modifiers.set_named();
  }
  if (token != kEOF && Optional(token)) {
    ParseExpression();
    builder()->DoVariableDeclaration(modifiers, true);
  } else {
    builder()->DoVariableDeclaration(modifiers, false);
  }
}

int Parser::ParseFormalParameters() {
  int count = 0;
  Expect(kLPAREN);
  while (!Optional(kRPAREN)) {
    if (count != 0) Expect(kCOMMA);
    if (Optional(kLBRACE)) {
      do {
        ParseFormalParameter(kCOLON);
        count++;
      } while (Optional(kCOMMA));
      Expect(kRBRACE);
    } else if (Optional(kLBRACK)) {
      do {
        ParseFormalParameter(kASSIGN);
        count++;
      } while (Optional(kCOMMA));
      Expect(kRBRACK);
    } else {
      ParseFormalParameter(kEOF);
      count++;
    }
  }
  return count;
}

int Parser::ParseInitializers() {
  Expect(kCOLON);
  int count = 0;
  do {
    if (peek_ == kSUPER) {
      ParseExpression();
    } else {
      if (Optional(kTHIS)) {
        builder()->DoThis();
        if (count == 0 && peek_ == kLPAREN) {
          ParseInvokeRest();
          return 1;
        }
        Expect(kPERIOD);
        ParseIdentifier();
        builder()->DoDot();
        if (count == 0 && peek_ == kLPAREN) {
          ParseInvokeRest();
          return 1;
        }
      } else {
        ParseIdentifier();
      }
      Expect(kASSIGN);
      ParsePrecedence(kConditionalPrecedence, false, false);
      while (peek_ == kCASCADE) ParseCascadeRest();
      builder()->DoAssign(kASSIGN);
    }
    count++;
  } while (Optional(kCOMMA));
  return count;
}

void Parser::ParseBlock() {
  int count = 0;
  Expect(kLBRACE);
  while (peek_ != kRBRACE && peek_ != kEOF) {
    ParseStatement();
    count++;
  }
  Expect(kRBRACE);
  builder()->DoBlock(count);
}

void Parser::ParseStatement() {
  switch (peek_) {
    case kLBRACE:
      ParseBlock();
      return;

    case kBREAK:
      ParseBreak();
      return;

    case kCONTINUE:
      ParseContinue();
      return;

    case kVAR:
      ParseVariableDeclarationStatement();
      return;

    case kRETURN:
      ParseReturn();
      return;

    case kIF:
      ParseIf();
      return;

    case kFOR:
      ParseFor();
      return;

    case kWHILE:
      ParseWhile();
      return;

    case kDO:
      ParseDoWhile();
      return;

    case kASSERT:
      ParseAssert();
      return;

    case kSWITCH:
      ParseSwitch();
      return;

    case kTRY:
      ParseTry();
      return;

    case kFINAL:
      ParseVariableDeclarationStatement();
      return;

    case kCONST:
      {
        // Peek after 'const' and see if it's a member start.
        Lookahead lookahead(this);
        Advance();
        if (!PeekIsMemberStart()) break;
      }
      ParseVariableDeclarationStatement();
      return;

    case kSEMICOLON:
      Advance();
      builder()->DoEmptyStatement();
      return;

    case kRETHROW:
      Advance();
      Expect(kSEMICOLON);
      builder()->DoRethrow();
      return;

    case kVOID:
      SkipOptionalType();
      ParseIdentifier();
      ParseMethod(Modifiers());
      return;

    case kIDENTIFIER:
    case kABSTRACT:
    case kAS:
    case kDYNAMIC:
    case kEXPORT:
    case kEXTERNAL:
    case kFACTORY:
    case kGET:
    case kHIDE:
    case kIMPLEMENTS:
    case kIMPORT:
    case kLIBRARY:
    case kNATIVE:
    case kOF:
    case kON:
    case kOPERATOR:
    case kPART:
    case kSET:
    case kSHOW:
    case kSTATIC:
    case kTYPEDEF:
      if (IsLabelledStatement()) {
        ParseIdentifier();
        Expect(kCOLON);
        ParseStatement();
        builder()->DoLabelledStatement();
        return;
      } else {
        Token token = PeekAfterFormalParameters();
        if (token == kLBRACE || token == kARROW) {
          ParseIdentifier();
          ParseMethod(Modifiers());
          return;
        }
        token = PeekAfterType();
        if (Tokens::IsIdentifier(token)) {
          SkipOptionalType();
          ParseIdentifier();
          if (peek_ == kLPAREN) {
            ParseMethod(Modifiers());
          } else {
            ParseVariableDeclarationStatementRest(Modifiers(), true);
          }
          return;
        }
      }
      break;

    default:
      break;
  }
  ParseExpression();
  Expect(kSEMICOLON);
  builder()->DoExpressionStatement();
}

void Parser::ParseVariableDeclarationStatement() {
  Modifiers modifiers;
  if (peek_ == kVAR) {
    Advance();
  } else {
    if (Optional(kFINAL)) {
      modifiers.set_final();
    } else if (Optional(kCONST)) {
      modifiers.set_const();
    }
    SkipOptionalType();
  }
  ParseVariableDeclarationStatementRest(modifiers, false);
}

void Parser::ParseVariableDeclarationStatementRest(
    Modifiers modifiers,
    bool skip_first) {
  int count = 0;
  do {
    if (count > 0 || !skip_first) ParseIdentifier();
    bool has_initializer = false;
    if (Optional(kASSIGN)) {
      ParseExpression();
      has_initializer = true;
    }
    count++;
    builder()->DoVariableDeclaration(modifiers, has_initializer);
  } while (Optional(kCOMMA));
  Expect(kSEMICOLON);
  builder()->DoVariableDeclarationStatement(modifiers, count);
}

void Parser::ParseIf() {
  Expect(kIF);
  Expect(kLPAREN);
  ParseExpression();
  Expect(kRPAREN);
  ParseStatement();
  bool has_else = false;
  if (Optional(kELSE)) {
    has_else = true;
    ParseStatement();
  }
  builder()->DoIf(has_else);
}

void Parser::ParseFor() {
  Expect(kFOR);
  Expect(kLPAREN);

  Token token = peek_;
  if (token == kFINAL ||
      token == kVAR ||
      Tokens::IsIdentifier(PeekAfterType())) {
    if (token == kFINAL || token == kVAR) Advance();
    if (token != kVAR) {
      SkipOptionalType();
      // Downgrade types to kVAR.
      if (token != kFINAL) token = kVAR;
    }
    if (Tokens::IsIdentifier(peek_) && PeekAfterIdentifier() == kIN) {
      ParseIdentifier();
      builder()->DoVariableDeclaration(Modifiers(), false);
      ParseForInRest(token);
      return;
    }
    Modifiers modifiers;
    modifiers.set_by_value();
    if (token == kFINAL) modifiers.set_final();
    ParseVariableDeclarationStatementRest(modifiers, false);
  } else {
    if (PeekAfterType() == kIDENTIFIER) {
      SkipOptionalType();
    }
    if (Tokens::IsIdentifier(peek_) && PeekAfterIdentifier() == kIN) {
      ParseIdentifier();
      builder()->DoVariableDeclaration(Modifiers(), false);
      ParseForInRest(kEOF);
      return;
    }
    if (peek_ != kSEMICOLON) {
      ParseExpression();
      builder()->DoExpressionStatement();
    } else {
      builder()->DoEmptyStatement();
    }
    Expect(kSEMICOLON);
  }
  bool has_condition = false;
  if (peek_ != kSEMICOLON) {
    has_condition = true;
    ParseExpression();
  }
  Expect(kSEMICOLON);
  int count = 0;
  if (peek_ != kRPAREN) {
    do {
      ParseExpression();
      count++;
    } while (Optional(kCOMMA));
  }
  Expect(kRPAREN);
  ParseStatement();
  builder()->DoFor(has_condition, count);
}

void Parser::ParseForInRest(Token token) {
  Expect(kIN);
  ParseExpression();
  Expect(kRPAREN);
  ParseStatement();
  builder()->DoForIn(token);
}

void Parser::ParseWhile() {
  Expect(kWHILE);
  Expect(kLPAREN);
  ParseExpression();
  Expect(kRPAREN);
  ParseStatement();
  builder()->DoWhile();
}

void Parser::ParseDoWhile() {
  Expect(kDO);
  ParseStatement();
  Expect(kWHILE);
  Expect(kLPAREN);
  ParseExpression();
  Expect(kRPAREN);
  Expect(kSEMICOLON);
  builder()->DoDoWhile();
}

void Parser::ParseBreak() {
  Expect(kBREAK);
  bool has_identifier = false;
  if (peek_ != kSEMICOLON) {
    has_identifier = true;
    ParseIdentifier();
  }
  Expect(kSEMICOLON);
  builder()->DoBreak(has_identifier);
}

void Parser::ParseContinue() {
  Expect(kCONTINUE);
  bool has_identifier = false;
  if (peek_ != kSEMICOLON) {
    has_identifier = true;
    ParseIdentifier();
  }
  Expect(kSEMICOLON);
  builder()->DoContinue(has_identifier);
}

void Parser::ParseReturn() {
  Expect(kRETURN);
  bool has_expression = false;
  if (peek_ != kSEMICOLON) {
    has_expression = true;
    ParseExpression();
  }
  Expect(kSEMICOLON);
  builder()->DoReturn(has_expression);
}

void Parser::ParseAssert() {
  Expect(kASSERT);
  Expect(kLPAREN);
  ParseExpression();
  Expect(kRPAREN);
  Expect(kSEMICOLON);
  builder()->DoAssert();
}

void Parser::ParseSwitch() {
  Expect(kSWITCH);
  Expect(kLPAREN);
  ParseExpression();
  Expect(kRPAREN);
  Expect(kLBRACE);
  int count = 0;
  while (Optional(kCASE)) {
    ParseExpression();
    Expect(kCOLON);
    int statement_count = 0;
    while (peek_ != kCASE &&
           peek_ != kDEFAULT &&
           peek_ != kRBRACE &&
           peek_ != kEOF) {
      ParseStatement();
      statement_count++;
    }
    builder()->DoCase(statement_count);
    count++;
  }
  int statement_count = 0;
  if (Optional(kDEFAULT)) {
    Expect(kCOLON);
    while (peek_ != kRBRACE &&
           peek_ != kEOF) {
      ParseStatement();
      statement_count++;
    }
  }
  Expect(kRBRACE);
  builder()->DoSwitch(count, statement_count);
}

void Parser::ParseTry() {
  Expect(kTRY);
  ParseBlock();
  int catch_count = 0;
  while (peek_ == kCATCH || peek_ == kON) {
    bool has_type = false;
    if (Optional(kON)) {
      ParseQualified();
      SkipOptionalTypeAnnotation();
      has_type = true;
    }
    int identifiers_count = 0;
    if (!has_type || peek_ == kCATCH) {
      Expect(kCATCH);
      Expect(kLPAREN);
      ParseIdentifier();
      builder()->DoVariableDeclaration(Modifiers(), false);
      identifiers_count++;
      if (Optional(kCOMMA)) {
        ParseIdentifier();
        builder()->DoVariableDeclaration(Modifiers(), false);
        identifiers_count++;
      }
      Expect(kRPAREN);
    }
    ParseBlock();
    builder()->DoCatch(has_type, identifiers_count);
    catch_count++;
  }
  bool has_finally = false;
  if (catch_count == 0 || peek_ == kFINALLY) {
    Expect(kFINALLY);
    ParseBlock();
    has_finally = true;
  }
  builder()->DoTry(catch_count, has_finally);
}

void Parser::ParseExpression() {
  if (peek_ == kTHROW) {
    ParseThrow();
  } else {
    ParsePrecedence(kAssignmentPrecedence);
  }
}

void Parser::ParseExpressionWithoutCascade() {
  if (peek_ == kTHROW) {
    ParseThrow();
  } else {
    ParsePrecedence(kAssignmentPrecedence, true, false);
  }
}

void Parser::ParseThrow() {
  Expect(kTHROW);
  ParseExpressionWithoutCascade();
  builder()->DoThrow();
}

void Parser::ParsePrecedence(int precedence,
                             bool allow_function,
                             bool allow_cascade) {
  ParseUnary(allow_function);
  Token token = peek_;
  int next = Tokens::Precedence(token);
  for (int level = next; level >= precedence; --level) {
    while (level == next) {
      if (token == kCASCADE) {
        if (!allow_cascade) return;
        ParseCascadeRest();
      } else if (level == kAssignmentPrecedence) {
        // Right associative, so we recurse at the same precedence level.
        Advance();
        ParsePrecedence(level, allow_function, allow_cascade);
        builder()->DoAssign(token);
      } else if (level == kPostfixPrecedence) {
        ParsePostfixRest();
      } else if (token == kCONDITIONAL) {
        ParseConditionalRest();
      } else if (token == kIS) {
        ParseIsRest();
      } else if (token == kAS) {
        ParseAsRest();
      } else {
        // Rewrite kGT_START into kSHR.
        if (token == kGT_START) {
          Advance();
          token = kSHR;
        }
        // Left associative, so we recurse at the next higher
        // precedence level.
        Advance();
        ParsePrecedence(level + 1);
        builder()->DoBinary(token);
      }
      token = peek_;
      next = Tokens::Precedence(token);
      // We don't allow (a == b == c) or (a < b < c) so we ontinue the outer
      // loop if we have matched one equality or relational operator.
      if (level == kEqualityPrecedence || level == kRelationalPrecedence) {
        break;
      }
    }
  }
}

void Parser::ParseCascadeRest() {
  Expect(kCASCADE);
  Token token = peek_;
  builder()->DoCascadeReceiver(token);
  if (Tokens::IsIdentifier(token)) {
    ParseIdentifier();
    builder()->DoDot();
  } else if (token == kLBRACK) {
    ParseIndexRest();
  } else {
    Error("Expected identifier or '[' in cascade but found '%s'",
          Tokens::Syntax(token));
  }
  token = peek_;
  while (token == kPERIOD ||
         token == kLBRACK ||
         token == kLPAREN) {
    ParsePostfixRest();
    token = peek_;
  }
  if (Tokens::Precedence(token) == kAssignmentPrecedence) {
    Advance();
    ParseExpressionWithoutCascade();
    builder()->DoAssign(token);
  }
  builder()->DoCascade();
}

void Parser::ParsePostfixRest() {
  Token token = peek_;
  ASSERT(Tokens::Precedence(token) == kPostfixPrecedence);
  if (token == kLPAREN) {
    ParseInvokeRest();
  } else if (token == kPERIOD) {
    Advance();
    ParseIdentifier();
    builder()->DoDot();
  } else if (token == kLBRACK) {
    ParseIndexRest();
  } else {
    ASSERT(token == kINCREMENT || token == kDECREMENT);
    Advance();
    builder()->DoUnary(token, false);
  }
}

void Parser::ParseConditionalRest() {
  Expect(kCONDITIONAL);
  ParseExpressionWithoutCascade();
  Expect(kCOLON);
  ParseExpressionWithoutCascade();
  builder()->DoConditional();
}

void Parser::ParseIsRest() {
  Expect(kIS);
  bool is_not = Optional(kNOT);
  ParseQualified();
  SkipOptionalTypeAnnotation();
  builder()->DoIs(is_not);
}

void Parser::ParseAsRest() {
  Expect(kAS);
  ParseQualified();
  SkipOptionalTypeAnnotation();
  builder()->DoAs();
}

void Parser::ParseInvokeRest() {
  if (peek_ != kLPAREN) Error("Expected '('");
  int count = 0;
  int named_count = 0;
  Expect(kLPAREN);
  while (!Optional(kRPAREN)) {
    if (PeekIsNamedArgument()) {
      while (!Optional(kRPAREN)) {
        if (count != 0) Expect(kCOMMA);
        ParseIdentifier();
        Expect(kCOLON);
        ParseExpression();
        count++;
        named_count++;
      }
      break;
    }
    if (count != 0) Expect(kCOMMA);
    ParseExpression();
    count++;
  }
  // TODO(ajohnsen): Add named arguments.
  builder()->DoInvoke(count, named_count);
}

void Parser::ParseIndexRest() {
  ASSERT(peek_ == kLBRACK);
  Advance();
  ParseExpression();
  Expect(kRBRACK);
  builder()->DoIndex();
}

void Parser::ParseUnary(bool allow_function) {
  Token token = peek_;
  switch (token) {
    case kNOT:        // !
    case kSUB:        // -
    case kBIT_NOT:    // ~
    case kINCREMENT:  // ++
    case kDECREMENT:  // --
      // Right associative, so we recurse at the same precedence level.
      Advance();
      ParsePrecedence(kPostfixPrecedence);
      builder()->DoUnary(token, true);
      break;

    default:
      ParsePrimary(allow_function);
      break;
  }
}

void Parser::ParsePrimary(bool allow_function) {
  switch (peek_) {
    case kIDENTIFIER:
      ParseIdentifier();
      break;

    case kABSTRACT:
    case kAS:
    case kDYNAMIC:
    case kEXPORT:
    case kEXTERNAL:
    case kFACTORY:
    case kGET:
    case kHIDE:
    case kIMPLEMENTS:
    case kIMPORT:
    case kLIBRARY:
    case kNATIVE:
    case kOF:
    case kON:
    case kOPERATOR:
    case kPART:
    case kSET:
    case kSHOW:
    case kSTATIC:
    case kTYPEDEF:
      ParseIdentifier();
      break;

    case kLT:
      SkipOptionalTypeAnnotation();
      if (peek_ == kLBRACE) {
        ParseMap(true, false);
      } else {
        ParseList(true, false);
      }
      break;

    case kLBRACE:
      ParseMap(false, false);
      break;

    case kINDEX:
    case kLBRACK:
      ParseList(false, false);
      break;

    case kFALSE:
    case kTRUE:
      builder()->DoBoolean(peek_ == kTRUE);
      Advance();
      break;

    case kNULL:
      builder()->DoNull();
      Advance();
      break;

    case kTHIS:
      builder()->DoThis();
      Advance();
      break;

    case kSUPER:
      builder()->DoSuper();
      Advance();
      break;

    case kLPAREN:
      if (allow_function && IsFunctionExpression()) {
        ParseFunctionExpression();
      } else {
        Location location = stream_.CurrentLocation();
        Advance();
        ParseExpression();
        Expect(kRPAREN);
        builder()->DoParenthesizedExpression(location);
      }
      break;

    case kNEW:
      ParseNew(false);
      break;

    case kCONST:
      ParseNew(true);
      break;

    case kINTEGER:
      ParseInteger();
      break;

    case kDOUBLE:
      ParseDouble();
      break;

    case kSTRING:
    case kSTRING_INTERPOLATION:
      ParseString();
      break;

    case kHASH:
      ParseSymbolLiteral();
      break;

    default:
      Error("Bad expression '%s'.", Tokens::Syntax(peek_));
      break;
  }
}

void Parser::ParseNew(bool is_const) {
  ASSERT((is_const && (peek_ == kCONST)) || (!is_const && (peek_ == kNEW)));
  Advance();

  if (is_const) {
    bool typed = false;
    if (peek_ == kLT) {
      SkipOptionalTypeAnnotation();
      typed = true;
    }
    if (peek_ == kLBRACK || peek_ == kINDEX) {
      ParseList(typed, true);
      return;
    } else if (peek_ == kLBRACE) {
      ParseMap(typed, true);
      return;
    }
  }

  ParseFullyQualified();
  ParseInvokeRest();
  builder()->DoNew(is_const);
}

void Parser::ParseFunctionExpression() {
  int count = ParseFormalParameters();
  if (peek_ == kLBRACE) {
    ParseBlock();
  } else {
    Expect(kARROW);
    ParseExpression();
  }
  builder()->DoFunctionExpression(count);
}

void Parser::ParseIdentifier() {
  if (!Tokens::IsIdentifier(peek_)) {
    Error("Expected identifier but found '%s'.", Tokens::Syntax(peek_));
  }
  if (peek_ == kIDENTIFIER) {
    builder()->DoIdentifier(stream_.CurrentIndex(), stream_.CurrentLocation());
  } else {
    builder()->DoBuiltin(peek_);
  }
  Advance();
}

void Parser::ParseQualified() {
  ParseIdentifier();
  if (Optional(kPERIOD)) {
    ParseIdentifier();
    builder()->DoDot();
  }
}

void Parser::ParseFullyQualified() {
  // TODO(ajohnsen): Use just one node?
  ParseIdentifier();
  SkipOptionalTypeAnnotation();
  while (Optional(kPERIOD)) {
    ParseIdentifier();
    SkipOptionalTypeAnnotation();
    builder()->DoDot();
  }
}

void Parser::ParseList(bool typed, bool is_const) {
  if (peek_ == kINDEX) {
    Advance();
    builder()->DoList(is_const, 0);
    return;
  }
  ASSERT(peek_ == kLBRACK);
  Advance();
  int count = 0;
  do {
    if (peek_ == kRBRACK) break;
    ParseExpression();
    count++;
  } while (Optional(kCOMMA));
  Expect(kRBRACK);
  builder()->DoList(is_const, count);
}

void Parser::ParseMap(bool typed, bool is_const) {
  ASSERT(peek_ == kLBRACE);
  Advance();
  int count = 0;
  do {
    if (peek_ == kRBRACE) break;
    ParseExpression();
    Expect(kCOLON);
    ParseExpression();
    count++;
  } while (Optional(kCOMMA));
  Expect(kRBRACE);
  builder()->DoMap(is_const, count);
}

void Parser::ParseInteger() {
  ASSERT(peek_ == kINTEGER);
  builder()->DoReference(stream_.CurrentIndex());
  Advance();
}

void Parser::ParseDouble() {
  ASSERT(peek_ == kDOUBLE);
  builder()->DoReference(stream_.CurrentIndex());
  Advance();
}

void Parser::ParseStringNoInterpolation() {
  ASSERT(peek_ == kSTRING);
  int count = 0;
  while (peek_ == kSTRING) {
    builder()->DoStringReference(stream_.CurrentIndex());
    Advance();
    count++;
  }
  builder()->DoString(count);
}

void Parser::ParseString() {
  ASSERT(peek_ == kSTRING_INTERPOLATION || peek_ == kSTRING);
  int string_count = 0;
  int count = 0;
  while (true) {
    if (peek_ == kSTRING) {
      ParseStringNoInterpolation();
      string_count++;
      continue;
    }
    if (peek_ == kSTRING_INTERPOLATION) {
      string_count++;
      builder()->DoStringReference(stream_.CurrentIndex());
      Advance();
      builder()->DoString(string_count);
      string_count = 0;
      ParseExpression();
      count++;
      continue;
    }
    if (count > 0 && peek_ == kSTRING_INTERPOLATION_END) {
      builder()->DoStringReference(stream_.CurrentIndex());
      Advance();
      builder()->DoString(1);
      string_count++;
      continue;
    }
    break;
  }
  builder()->DoString(string_count);
  if (count > 0) {
    builder()->DoStringInterpolation(count);
  }
}

void Parser::ParseSymbolLiteral() {
  Expect(kHASH);
  builder()->PushIdentifier(builder()->Canonicalize("Symbol"));
  int count = 0;
  while (Tokens::IsIdentifier(peek_)) {
    const char* value;
    if (peek_ == kIDENTIFIER) {
      int id = stream_.CurrentIndex();
      value = builder()->LookupIdentifier(id);
    } else {
      value = Tokens::Syntax(peek_);
    }
    int id = builder()->RegisterString(value);
    builder()->DoStringReference(id);
    Advance();
    count++;
    if (!Optional(kPERIOD)) break;
    id = builder()->RegisterString(builder()->Canonicalize(".")->value());
    builder()->DoStringReference(id);
    count++;
  }
  builder()->DoString(count);
  builder()->DoInvoke(1, 0);
  builder()->DoNew(true);
}

void Parser::SkipOptionalType() {
  if (peek_ == kVOID) {
    Advance();
  } else {
    // It's a type if it's followed by an identifier, this, or operator.
    Token next = PeekAfterType();
    if (next == kTHIS || next == kOPERATOR || Tokens::IsIdentifier(next)) {
      SkipType();
    }
  }
}

void Parser::SkipType() {
  if (Optional(kVOID) || Optional(kDYNAMIC)) {
    return;
  } else {
    SkipQualified();
    if (Optional(kLT)) {
      do {
        SkipType();
      } while (Optional(kCOMMA));
      if (!Optional(kGT_START)) Expect(kGT);
    }
  }
}

void Parser::SkipQualified() {
  SkipIdentifier();
  if (Optional(kPERIOD)) {
    SkipIdentifier();
  }
}

void Parser::SkipFullyQualified() {
  do {
    SkipIdentifier();
  } while (Optional(kPERIOD));
}

void Parser::SkipIdentifier() {
  if (Tokens::IsIdentifier(peek_)) {
    Advance();
  } else {
    Error("Expected identifier but found '%s'.", Tokens::Syntax(peek_));
  }
}

void Parser::SkipOptionalTypeAnnotation() {
  if (peek_ == kLT) {
    int delta = stream_.CurrentIndex();
    ASSERT(delta > 0);
    stream_.Skip(delta);
    RefreshPeek();
    Expect(kGT);
  }
}

void Parser::SkipMetadata() {
  Expect(kAT);
  SkipFullyQualified();
  if (peek_ == kLPAREN) SkipFormalParameters();
}

void Parser::SkipFormalParameters() {
  ASSERT(peek_ == kLPAREN);
  int delta = stream_.CurrentIndex();
  stream_.Skip(delta);
  RefreshPeek();
  ASSERT(peek_ == kRPAREN);
  Advance();
}

Token Parser::PeekAfterType() {
  if (peek_ != kIDENTIFIER && peek_ != kDYNAMIC && peek_ != kNATIVE) {
    return kEOF;
  }
  Lookahead lookahead(this);
  Advance();
  if (peek_ == kPERIOD) {
    Advance();
    if (peek_ != kIDENTIFIER) return kEOF;
    Advance();
  }
  if (peek_ == kLT) {
    int delta = stream_.CurrentIndex();
    if (delta == -1) return kEOF;
    stream_.Skip(delta);
    RefreshPeek();
    ASSERT(peek_ == kGT);
    Advance();
  }
  return peek_;
}

Token Parser::PeekAfterFormalParameters() {
  ASSERT(Tokens::IsIdentifier(peek_));
  Lookahead lookahead(this);
  SkipQualified();
  if (peek_ != kLPAREN) return kEOF;
  int delta = stream_.CurrentIndex();
  stream_.Skip(delta);
  RefreshPeek();
  ASSERT(peek_ == kRPAREN);
  Advance();
  return peek_;
}

Token Parser::PeekAfterIdentifier() {
  ASSERT(Tokens::IsIdentifier(peek_));
  Lookahead lookahead(this);
  Advance();
  return peek_;
}

Token Parser::PeekNext() {
  Lookahead lookahead(this);
  Advance();
  return peek_;
}

bool Parser::PeekIsNamedArgument() {
  Lookahead lookahead(this);
  Optional(kCOMMA);
  if (!Tokens::IsIdentifier(peek_)) return false;
  Advance();
  return peek_ == kCOLON;
}

bool Parser::PeekIsMemberStart() {
  Lookahead lookahead(this);
  SkipOptionalType();
  if (!Tokens::IsIdentifier(peek_)) return false;
  Advance();
  if (peek_ == kSEMICOLON || peek_ == kASSIGN || peek_ == kLPAREN) return true;
  return false;
}

bool Parser::PeekIsGetter() {
  Lookahead lookahead(this);
  if (!Optional(kGET)) return false;
  if (!Tokens::IsIdentifier(peek_)) return false;
  return true;
}

bool Parser::PeekIsSetter() {
  Lookahead lookahead(this);
  if (!Optional(kSET)) return false;
  if (!Tokens::IsIdentifier(peek_)) return false;
  return true;
}

bool Parser::IsFunctionExpression() {
  ASSERT(peek_ == kLPAREN);
  Lookahead lookahead(this);
  int delta = stream_.CurrentIndex();
  if (delta == -1) return false;
  stream_.Skip(delta);
  RefreshPeek();
  ASSERT(peek_ == kRPAREN);
  Advance();
  return (peek_ == kLBRACE || peek_ == kARROW);
}

bool Parser::IsLabelledStatement() {
  ASSERT(Tokens::IsIdentifier(peek_));
  Lookahead lookahead(this);
  Advance();
  return (peek_ == kCOLON);
}

void Parser::Error(const char* format, ...) {
  va_list args;
  va_start(args, format);
  builder()->ReportError(stream_.CurrentLocation(), format, args);
  va_end(args);
}

}  // namespace fletch
