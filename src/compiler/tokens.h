// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_COMPILER_TOKENS_H_
#define SRC_COMPILER_TOKENS_H_

#include "src/shared/globals.h"
#include "src/compiler/source.h"

namespace fletch {

const int kAssignmentPrecedence   = 1;
const int kCascadePrecedence      = 2;
const int kConditionalPrecedence  = 3;
const int kEqualityPrecedence     = 6;
const int kRelationalPrecedence   = 7;
const int kPostfixPrecedence      = 14;

// List of keywords.
#define KEYWORD_LIST(T)                                        \
  T(kASSERT, "assert", 0)                                      \
  T(kBREAK, "break", 0)                                        \
  T(kCASE, "case", 0)                                          \
  T(kCATCH, "catch", 0)                                        \
  T(kCLASS, "class", 0)                                        \
  T(kCONST, "const", 0)                                        \
  T(kCONTINUE, "continue", 0)                                  \
  T(kDEFAULT, "default", 0)                                    \
  T(kDO, "do", 0)                                              \
  T(kELSE, "else", 0)                                          \
  T(kEXTENDS, "extends", 0)                                    \
  T(kFALSE, "false", 0)                                        \
  T(kFINAL, "final", 0)                                        \
  T(kFINALLY, "finally", 0)                                    \
  T(kFOR, "for", 0)                                            \
  T(kIF, "if", 0)                                              \
  T(kIN, "in", 0)                                              \
  T(kIS, "is", kRelationalPrecedence)                          \
  T(kNEW, "new", 0)                                            \
  T(kNULL, "null", 0)                                          \
  T(kRETHROW, "rethrow", 0)                                    \
  T(kRETURN, "return", 0)                                      \
  T(kSUPER, "super", 0)                                        \
  T(kSWITCH, "switch", 0)                                      \
  T(kTHIS, "this", 0)                                          \
  T(kTHROW, "throw", 0)                                        \
  T(kTRUE, "true", 0)                                          \
  T(kTRY, "try", 0)                                            \
  T(kVAR, "var", 0)                                            \
  T(kVOID, "void", 0)                                          \
  T(kWHILE, "while", 0)                                        \
  T(kWITH, "with", 0)                                          \
                                                               \
  T(kABSTRACT, "abstract", 0)                                  \
  T(kAS, "as", kRelationalPrecedence)                          \
  T(kDYNAMIC, "dynamic", 0)                                    \
  T(kEXPORT, "export", 0)                                      \
  T(kEXTERNAL, "external", 0)                                  \
  T(kFACTORY, "factory", 0)                                    \
  T(kGET, "get", 0)                                            \
  T(kHIDE, "hide", 0)                                          \
  T(kIMPLEMENTS, "implements", 0)                              \
  T(kIMPORT, "import", 0)                                      \
  T(kLIBRARY, "library", 0)                                    \
  T(kNATIVE, "native", 0)                                      \
  T(kOF, "of", 0)                                              \
  T(kON, "on", 0)                                              \
  T(kOPERATOR, "operator", 0)                                  \
  T(kPART, "part", 0)                                          \
  T(kSET, "set", 0)                                            \
  T(kSHOW, "show", 0)                                          \
  T(kSTATIC, "static", 0)                                      \
  T(kTYPEDEF, "typedef", 0)                                    \

// List of tokens.
#define TOKEN_LIST(T)                                          \
  T(kEOF, "EOF", 0)                                            \
  T(kINTEGER, "integer", 0)                                    \
  T(kDOUBLE, "double", 0)                                      \
  T(kIDENTIFIER, "identifier", 0)                              \
  T(kSTRING, "string", 0)                                      \
  T(kSTRING_INTERPOLATION, "", 0)                              \
  T(kSTRING_INTERPOLATION_END, "", 0)                          \
  T(kCOMMA, ",", 0)                                            \
                                                               \
  T(kLPAREN, "(", kPostfixPrecedence)                          \
  T(kRPAREN, ")", 0)                                           \
  T(kLBRACK, "[", kPostfixPrecedence)                          \
  T(kRBRACK, "]", 0)                                           \
  T(kLBRACE, "{", 0)                                           \
  T(kRBRACE, "}", 0)                                           \
  T(kARROW, "=>", 0)                                           \
  T(kCOLON, ":", 0)                                            \
  T(kSEMICOLON, ";", 0)                                        \
  T(kAT, "@", 0)                                               \
  T(kHASH, "#", 0)                                             \
  T(kPERIOD, ".", kPostfixPrecedence)                          \
  T(kINCREMENT, "++", kPostfixPrecedence)                      \
  T(kDECREMENT, "--", kPostfixPrecedence)                      \
                                                               \
  T(kINDEX, "[]", 0)                                           \
  T(kASSIGN_INDEX, "[]=", 0)                                   \
                                                               \
  /* Assignment operators. */                                  \
  T(kASSIGN, "=", kAssignmentPrecedence)                       \
  T(kASSIGN_OR, "|=", kAssignmentPrecedence)                   \
  T(kASSIGN_XOR, "^=", kAssignmentPrecedence)                  \
  T(kASSIGN_AND, "&=", kAssignmentPrecedence)                  \
  T(kASSIGN_SHL, "<<=", kAssignmentPrecedence)                 \
  T(kASSIGN_SHR, ">>=", kAssignmentPrecedence)                 \
  T(kASSIGN_ADD, "+=", kAssignmentPrecedence)                  \
  T(kASSIGN_SUB, "-=", kAssignmentPrecedence)                  \
  T(kASSIGN_MUL, "*=", kAssignmentPrecedence)                  \
  T(kASSIGN_TRUNCDIV, "~/=", kAssignmentPrecedence)            \
  T(kASSIGN_DIV, "/=", kAssignmentPrecedence)                  \
  T(kASSIGN_MOD, "%=", kAssignmentPrecedence)                  \
                                                               \
  T(kCASCADE, "..", kCascadePrecedence)                        \
                                                               \
  T(kOR, "||", 4)                                              \
  T(kAND, "&&", 5)                                             \
  T(kBIT_OR, "|", 8)                                           \
  T(kBIT_XOR, "^", 9)                                          \
  T(kBIT_AND, "&", 10)                                         \
  T(kBIT_NOT, "~", 0)                                          \
                                                               \
  /* Shift operators. */                                       \
  T(kSHL, "<<", 11)                                            \
  T(kSHR, ">>", 11)                                            \
  T(kGT_START, ">", 11)                                        \
                                                               \
  /* Additive operators. */                                    \
  T(kADD, "+", 12)                                             \
  T(kSUB, "-", 12)                                             \
                                                               \
  /* Multiplicative operators */                               \
  T(kMUL, "*", 13)                                             \
  T(kDIV, "/", 13)                                             \
  T(kTRUNCDIV, "~/", 13)                                       \
  T(kMOD, "%", 13)                                             \
                                                               \
  T(kNOT, "!", 0)                                              \
  T(kCONDITIONAL, "?", kConditionalPrecedence)                 \
                                                               \
  /* Equality operators. */                                    \
  T(kEQ, "==", kEqualityPrecedence)                            \
  T(kNE, "!=", kEqualityPrecedence)                            \
                                                               \
  /* Relational operators. */                                  \
  T(kLT, "<", kRelationalPrecedence)                           \
  T(kGT, ">", kRelationalPrecedence)                           \
  T(kLTE, "<=", kRelationalPrecedence)                         \
  T(kGTE, ">=", kRelationalPrecedence)                         \
                                                               \
  KEYWORD_LIST(T)                                              \

enum Token {
#define T(n, s, p) n,
TOKEN_LIST(T)
#undef T
};

class TokenInfo {
 public:
  TokenInfo(uint32 value, Location location)
      : value_(value)
      , location_(location) {
  }

  TokenInfo() : value_(0), location_() {
  }

  Token token() const { return static_cast<Token>(value_ & 0xFF); }
  int index() const { return static_cast<int>(value_) >> 8; }

  Location location() const { return location_; }

 private:
  uint32 value_;
  Location location_;
};

class Tokens {
 public:
  static inline bool IsIdentifier(Token token);

  static int Precedence(Token token) { return precedence_[token]; }
  static const char* Syntax(Token token) { return syntax_[token]; }

  static const int kNumberOfBuiltins = kTYPEDEF - kABSTRACT + 1;

 private:
  static int precedence_[];
  static const char* syntax_[];
};

bool Tokens::IsIdentifier(Token token) {
  return (token == kIDENTIFIER)
      || ((token >= kABSTRACT) && (token <= kTYPEDEF));
}

}  // namespace fletch

#endif  // SRC_COMPILER_TOKENS_H_
