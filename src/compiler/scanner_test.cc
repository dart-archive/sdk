// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/compiler/scanner.h"
#include "src/compiler/string_buffer.h"
#include "src/shared/test_case.h"

namespace fletch {

struct TokenData {
  Token token;
  int index;
  const char* value;
};

List<TokenData> Scan(Zone* zone, const char* input) {
  Builder builder(zone);
  Scanner scanner(&builder, zone);
  scanner.Scan(input, Location());
  TokenStream stream(scanner.EncodedTokens());
  ListBuilder<TokenData, 4> tokens(zone);
  while (true) {
    Token token = stream.Current();
    int index = stream.CurrentIndex();
    const char* value = NULL;
    if (token == kSTRING ||
        token == kSTRING_INTERPOLATION ||
        token == kSTRING_INTERPOLATION_END) {
      value = builder.LookupString(index)->value();
    } else if (token == kINTEGER) {
      StringBuffer buffer(zone);
      buffer.Print("%d", builder.Lookup(index)->AsLiteralInteger()->value());
      value = buffer.ToString();
    } else if (token == kDOUBLE) {
      StringBuffer buffer(zone);
      buffer.Print("%F", builder.Lookup(index)->AsLiteralDouble()->value());
      value = buffer.ToString();
    } else if (token == kIDENTIFIER) {
      value = builder.LookupIdentifier(index);
    }
    TokenData current = { token, index, value };
    tokens.Add(current);
    if (token == kEOF) {
      return tokens.ToList();
    }
    stream.Advance();
  }
}

TEST_CASE(SimpleTokens) {
  Zone zone;
  List<TokenData> tokens = Scan(&zone, " 1234 xyz ");
  EXPECT_EQ(3, tokens.length());
  EXPECT_EQ(kINTEGER, tokens[0].token);
  EXPECT_STREQ("1234", tokens[0].value);
  EXPECT_EQ(kIDENTIFIER, tokens[1].token);
  EXPECT_STREQ("xyz", tokens[1].value);
  EXPECT_EQ(kEOF, tokens[2].token);

  tokens = Scan(&zone, "1\t 2\n3");
  EXPECT_EQ(4, tokens.length());
  EXPECT_EQ(kINTEGER, tokens[0].token);
  EXPECT_STREQ("1", tokens[0].value);
  EXPECT_EQ(kINTEGER, tokens[1].token);
  EXPECT_STREQ("2", tokens[1].value);
  EXPECT_EQ(kINTEGER, tokens[2].token);
  EXPECT_STREQ("3", tokens[2].value);
  EXPECT_EQ(kEOF, tokens[3].token);

  tokens = Scan(&zone, "if for while");
  EXPECT_EQ(4, tokens.length());
  EXPECT_EQ(kIF, tokens[0].token);
  EXPECT_EQ(kFOR, tokens[1].token);
  EXPECT_EQ(kWHILE, tokens[2].token);
  EXPECT_EQ(kEOF, tokens[3].token);

  tokens = Scan(&zone, "1 == 2 => 3");
  EXPECT_EQ(6, tokens.length());
  EXPECT_EQ(kINTEGER, tokens[0].token);
  EXPECT_STREQ("1", tokens[0].value);
  EXPECT_EQ(kEQ, tokens[1].token);
  EXPECT_EQ(kINTEGER, tokens[2].token);
  EXPECT_STREQ("2", tokens[2].value);
  EXPECT_EQ(kARROW, tokens[3].token);
  EXPECT_EQ(kINTEGER, tokens[4].token);
  EXPECT_STREQ("3", tokens[4].value);
  EXPECT_EQ(kEOF, tokens[5].token);

  tokens = Scan(&zone, "as 1 with 2 xxx");
  EXPECT_EQ(6, tokens.length());
  EXPECT_EQ(kAS, tokens[0].token);
  EXPECT_EQ(kINTEGER, tokens[1].token);
  EXPECT_STREQ("1", tokens[1].value);
  EXPECT_EQ(kWITH, tokens[2].token);
  EXPECT_EQ(kINTEGER, tokens[3].token);
  EXPECT_STREQ("2", tokens[3].value);
  EXPECT_EQ(kIDENTIFIER, tokens[4].token);
  EXPECT_STREQ("xxx", tokens[4].value);
  EXPECT_EQ(kEOF, tokens[5].token);

  tokens = Scan(&zone, "'foo' 'bar'");
  EXPECT_EQ(3, tokens.length());
  EXPECT_EQ(kSTRING, tokens[0].token);
  EXPECT_STREQ("foo", tokens[0].value);
  EXPECT_EQ(kSTRING, tokens[1].token);
  EXPECT_STREQ("bar", tokens[1].value);
  EXPECT_EQ(kEOF, tokens[2].token);

  tokens = Scan(&zone, ".. ...");
  EXPECT_EQ(4, tokens.length());
  EXPECT_EQ(kCASCADE, tokens[0].token);
  EXPECT_EQ(kCASCADE, tokens[1].token);
  EXPECT_EQ(kPERIOD, tokens[2].token);
  EXPECT_EQ(kEOF, tokens[3].token);

  tokens = Scan(&zone, "$ $0");
  EXPECT_EQ(3, tokens.length());
  EXPECT_EQ(kIDENTIFIER, tokens[0].token);
  EXPECT_STREQ("$", tokens[0].value);
  EXPECT_EQ(kIDENTIFIER, tokens[1].token);
  EXPECT_STREQ("$0", tokens[1].value);
  EXPECT_EQ(kEOF, tokens[2].token);

  tokens = Scan(&zone, "0xA");
  EXPECT_EQ(2, tokens.length());
  EXPECT_EQ(kINTEGER, tokens[0].token);
  EXPECT_STREQ("10", tokens[0].value);
  EXPECT_EQ(kEOF, tokens[1].token);

  tokens = Scan(&zone, "1.x");
  EXPECT_EQ(4, tokens.length());
  EXPECT_EQ(kINTEGER, tokens[0].token);
  EXPECT_STREQ("1", tokens[0].value);
  EXPECT_EQ(kPERIOD, tokens[1].token);
  EXPECT_EQ(kIDENTIFIER, tokens[2].token);
  EXPECT_STREQ("x", tokens[2].value);
  EXPECT_EQ(kEOF, tokens[3].token);

  tokens = Scan(&zone, "0.5e-3 1e+0 1e1");
  EXPECT_EQ(4, tokens.length());
  EXPECT_EQ(kDOUBLE, tokens[0].token);
  EXPECT_STREQ("0.000500", tokens[0].value);
  EXPECT_EQ(kDOUBLE, tokens[1].token);
  EXPECT_STREQ("1.000000", tokens[1].value);
  EXPECT_EQ(kDOUBLE, tokens[2].token);
  EXPECT_STREQ("10.000000", tokens[2].value);
  EXPECT_EQ(kEOF, tokens[3].token);

  tokens = Scan(&zone, "&= |= ^=");
  EXPECT_EQ(4, tokens.length());
  EXPECT_EQ(kASSIGN_AND, tokens[0].token);
  EXPECT_EQ(kASSIGN_OR, tokens[1].token);
  EXPECT_EQ(kASSIGN_XOR, tokens[2].token);
  EXPECT_EQ(kEOF, tokens[3].token);

  tokens = Scan(&zone, "[] []=");
  EXPECT_EQ(3, tokens.length());
  EXPECT_EQ(kINDEX, tokens[0].token);
  EXPECT_EQ(kASSIGN_INDEX, tokens[1].token);
  EXPECT_EQ(kEOF, tokens[2].token);
}

TEST_CASE(GreaterThan) {
  Zone zone;
  List<TokenData> tokens = Scan(&zone, ">>");
  EXPECT_EQ(3, tokens.length());
  EXPECT_EQ(kGT_START, tokens[0].token);
  EXPECT_EQ(kGT, tokens[1].token);
  EXPECT_EQ(kEOF, tokens[2].token);

  tokens = Scan(&zone, "X<Y<Z>>");
  EXPECT_EQ(8, tokens.length());
  EXPECT_EQ(kIDENTIFIER, tokens[0].token);
  EXPECT_EQ(kLT, tokens[1].token);
  EXPECT_EQ(5, tokens[1].index);
  EXPECT_EQ(kIDENTIFIER, tokens[2].token);
  EXPECT_EQ(kLT, tokens[3].token);
  EXPECT_EQ(2, tokens[3].index);
  EXPECT_EQ(kIDENTIFIER, tokens[4].token);
  EXPECT_EQ(kGT_START, tokens[5].token);
  EXPECT_EQ(kGT, tokens[6].token);
  EXPECT_EQ(kEOF, tokens[7].token);

  tokens = Scan(&zone, ">= >>=");
  EXPECT_EQ(3, tokens.length());
  EXPECT_EQ(kGTE, tokens[0].token);
  EXPECT_EQ(kASSIGN_SHR, tokens[1].token);
  EXPECT_EQ(kEOF, tokens[2].token);
}

TEST_CASE(ForwardReferences) {
  Zone zone;
  List<TokenData> tokens = Scan(&zone, "(");
  EXPECT_EQ(2, tokens.length());
  EXPECT_EQ(kLPAREN, tokens[0].token);
  EXPECT_EQ(-1, tokens[0].index);
  EXPECT_EQ(kEOF, tokens[1].token);

  tokens = Scan(&zone, "()");
  EXPECT_EQ(3, tokens.length());
  EXPECT_EQ(kLPAREN, tokens[0].token);
  EXPECT_EQ(1, tokens[0].index);
  EXPECT_EQ(kRPAREN, tokens[1].token);
  EXPECT_EQ(-1, tokens[1].index);
  EXPECT_EQ(kEOF, tokens[2].token);

  tokens = Scan(&zone, "((()))");
  EXPECT_EQ(7, tokens.length());
  EXPECT_EQ(kLPAREN, tokens[0].token);
  EXPECT_EQ(5, tokens[0].index);
  EXPECT_EQ(kLPAREN, tokens[1].token);
  EXPECT_EQ(3, tokens[1].index);
  EXPECT_EQ(kLPAREN, tokens[2].token);
  EXPECT_EQ(1, tokens[2].index);
  EXPECT_EQ(kRPAREN, tokens[3].token);
  EXPECT_EQ(kRPAREN, tokens[4].token);
  EXPECT_EQ(kRPAREN, tokens[5].token);
  EXPECT_EQ(kEOF, tokens[6].token);

  tokens = Scan(&zone, ")()");
  EXPECT_EQ(4, tokens.length());
  EXPECT_EQ(kRPAREN, tokens[0].token);
  EXPECT_EQ(kLPAREN, tokens[1].token);
  EXPECT_EQ(1, tokens[1].index);
  EXPECT_EQ(kRPAREN, tokens[2].token);
  EXPECT_EQ(kEOF, tokens[3].token);

  tokens = Scan(&zone, "(()");
  EXPECT_EQ(4, tokens.length());
  EXPECT_EQ(kLPAREN, tokens[0].token);
  EXPECT_EQ(-1, tokens[0].index);
  EXPECT_EQ(kLPAREN, tokens[1].token);
  EXPECT_EQ(1, tokens[1].index);
  EXPECT_EQ(kRPAREN, tokens[2].token);
  EXPECT_EQ(kEOF, tokens[3].token);

  tokens = Scan(&zone, "<{[()]}>");
  EXPECT_EQ(9, tokens.length());
  EXPECT_EQ(kLT, tokens[0].token);
  EXPECT_EQ(7, tokens[0].index);
  EXPECT_EQ(kLBRACE, tokens[1].token);
  EXPECT_EQ(5, tokens[1].index);
  EXPECT_EQ(kLBRACK, tokens[2].token);
  EXPECT_EQ(-1, tokens[2].index);
  EXPECT_EQ(kLPAREN, tokens[3].token);
  EXPECT_EQ(1, tokens[3].index);
  EXPECT_EQ(kRPAREN, tokens[4].token);
  EXPECT_EQ(kRBRACK, tokens[5].token);
  EXPECT_EQ(kRBRACE, tokens[6].token);
  EXPECT_EQ(kGT, tokens[7].token);
  EXPECT_EQ(kEOF, tokens[8].token);

  tokens = Scan(&zone, "<(>)");
  EXPECT_EQ(5, tokens.length());
  EXPECT_EQ(kLT, tokens[0].token);
  EXPECT_EQ(-1, tokens[0].index);
  EXPECT_EQ(kLPAREN, tokens[1].token);
  EXPECT_EQ(2, tokens[1].index);
  EXPECT_EQ(kGT, tokens[2].token);
  EXPECT_EQ(kRPAREN, tokens[3].token);
  EXPECT_EQ(kEOF, tokens[4].token);

  tokens = Scan(&zone, "(<)>");
  EXPECT_EQ(5, tokens.length());
  EXPECT_EQ(kLPAREN, tokens[0].token);
  EXPECT_EQ(2, tokens[0].index);
  EXPECT_EQ(kLT, tokens[1].token);
  EXPECT_EQ(-1, tokens[1].index);
  EXPECT_EQ(kRPAREN, tokens[2].token);
  EXPECT_EQ(kGT, tokens[3].token);
  EXPECT_EQ(kEOF, tokens[4].token);

  tokens = Scan(&zone, "< << <<= >");
  EXPECT_EQ(5, tokens.length());
  EXPECT_EQ(kLT, tokens[0].token);
  EXPECT_EQ(3, tokens[0].index);
  EXPECT_EQ(kSHL, tokens[1].token);
  EXPECT_EQ(-1, tokens[1].index);
  EXPECT_EQ(kASSIGN_SHL, tokens[2].token);
  EXPECT_EQ(-1, tokens[2].index);
  EXPECT_EQ(kGT, tokens[3].token);
  EXPECT_EQ(kEOF, tokens[4].token);
}

TEST_CASE(StringLiterals) {
  Zone zone;
  List<TokenData> tokens = Scan(&zone, "r'\\'4");
  EXPECT_EQ(3, tokens.length());
  EXPECT_EQ(kSTRING, tokens[0].token);
  EXPECT_EQ(kINTEGER, tokens[1].token);
  EXPECT_STREQ("4", tokens[1].value);
  EXPECT_EQ(kEOF, tokens[2].token);

  tokens = Scan(&zone, "r'\\'4");
  EXPECT_EQ(3, tokens.length());
  EXPECT_EQ(kSTRING, tokens[0].token);
  EXPECT_EQ(kINTEGER, tokens[1].token);
  EXPECT_STREQ("4", tokens[1].value);
  EXPECT_EQ(kEOF, tokens[2].token);

  tokens = Scan(&zone, "''x");
  EXPECT_EQ(3, tokens.length());
  EXPECT_EQ(kSTRING, tokens[0].token);
  EXPECT_STREQ("", tokens[0].value);
  EXPECT_EQ(kIDENTIFIER, tokens[1].token);
  EXPECT_STREQ("x", tokens[1].value);
  EXPECT_EQ(kEOF, tokens[2].token);

  tokens = Scan(&zone, "'''x'''");
  EXPECT_EQ(2, tokens.length());
  EXPECT_EQ(kSTRING, tokens[0].token);
  EXPECT_STREQ("x", tokens[0].value);
  EXPECT_EQ(kEOF, tokens[1].token);

  tokens = Scan(&zone, "''''''");
  EXPECT_EQ(2, tokens.length());
  EXPECT_EQ(kSTRING, tokens[0].token);
  EXPECT_STREQ("", tokens[0].value);
  EXPECT_EQ(kEOF, tokens[1].token);

  tokens = Scan(&zone, "'''\"\n\"'''");
  EXPECT_EQ(2, tokens.length());
  EXPECT_EQ(kSTRING, tokens[0].token);
  EXPECT_STREQ("\"\n\"", tokens[0].value);
  EXPECT_EQ(kEOF, tokens[1].token);

  tokens = Scan(&zone, "'\\n'");
  EXPECT_EQ(2, tokens.length());
  EXPECT_EQ(kSTRING, tokens[0].token);
  EXPECT_STREQ("\n", tokens[0].value);
  EXPECT_EQ(kEOF, tokens[1].token);

  tokens = Scan(&zone, "'x\\b\\f\\n\\r\\t\\v'");
  EXPECT_EQ(2, tokens.length());
  EXPECT_EQ(kSTRING, tokens[0].token);
  EXPECT_STREQ("x\b\f\n\r\t\v", tokens[0].value);
  EXPECT_EQ(kEOF, tokens[1].token);
}

TEST_CASE(StringInterpolation) {
  Zone zone;
  List<TokenData> tokens = Scan(&zone, "r'$x'");
  EXPECT_EQ(2, tokens.length());
  EXPECT_EQ(kSTRING, tokens[0].token);
  EXPECT_STREQ("$x", tokens[0].value);
  EXPECT_EQ(kEOF, tokens[1].token);

  tokens = Scan(&zone, "'$x'");
  EXPECT_EQ(4, tokens.length());
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[0].token);
  EXPECT_STREQ("", tokens[0].value);
  EXPECT_EQ(kIDENTIFIER, tokens[1].token);
  EXPECT_STREQ("x", tokens[1].value);
  EXPECT_EQ(kSTRING_INTERPOLATION_END, tokens[2].token);
  EXPECT_STREQ("", tokens[2].value);
  EXPECT_EQ(kEOF, tokens[3].token);

  tokens = Scan(&zone, "'$x$y'");
  EXPECT_EQ(6, tokens.length());
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[0].token);
  EXPECT_STREQ("", tokens[0].value);
  EXPECT_EQ(kIDENTIFIER, tokens[1].token);
  EXPECT_STREQ("x", tokens[1].value);
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[2].token);
  EXPECT_STREQ("", tokens[2].value);
  EXPECT_EQ(kIDENTIFIER, tokens[3].token);
  EXPECT_STREQ("y", tokens[3].value);
  EXPECT_EQ(kSTRING_INTERPOLATION_END, tokens[4].token);
  EXPECT_STREQ("", tokens[4].value);
  EXPECT_EQ(kEOF, tokens[5].token);

  tokens = Scan(&zone, "'''re$xtr sr'''");
  EXPECT_EQ(4, tokens.length());
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[0].token);
  EXPECT_STREQ("re", tokens[0].value);
  EXPECT_EQ(kIDENTIFIER, tokens[1].token);
  EXPECT_STREQ("xtr", tokens[1].value);
  EXPECT_EQ(kSTRING_INTERPOLATION_END, tokens[2].token);
  EXPECT_STREQ(" sr", tokens[2].value);
  EXPECT_EQ(kEOF, tokens[3].token);

  tokens = Scan(&zone, "'$a|$b|$c'");
  EXPECT_EQ(8, tokens.length());
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[0].token);
  EXPECT_STREQ("", tokens[0].value);
  EXPECT_EQ(kIDENTIFIER, tokens[1].token);
  EXPECT_STREQ("a", tokens[1].value);
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[2].token);
  EXPECT_STREQ("|", tokens[2].value);
  EXPECT_EQ(kIDENTIFIER, tokens[3].token);
  EXPECT_STREQ("b", tokens[3].value);
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[4].token);
  EXPECT_STREQ("|", tokens[4].value);
  EXPECT_EQ(kIDENTIFIER, tokens[5].token);
  EXPECT_STREQ("c", tokens[5].value);
  EXPECT_EQ(kSTRING_INTERPOLATION_END, tokens[6].token);
  EXPECT_STREQ("", tokens[6].value);
  EXPECT_EQ(kEOF, tokens[7].token);

  tokens = Scan(&zone, "'${x}'");
  EXPECT_EQ(4, tokens.length());
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[0].token);
  EXPECT_STREQ("", tokens[0].value);
  EXPECT_EQ(kIDENTIFIER, tokens[1].token);
  EXPECT_STREQ("x", tokens[1].value);
  EXPECT_EQ(kSTRING_INTERPOLATION_END, tokens[2].token);
  EXPECT_STREQ("", tokens[2].value);
  EXPECT_EQ(kEOF, tokens[3].token);

  tokens = Scan(&zone, "'${3 5}'");
  EXPECT_EQ(5, tokens.length());
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[0].token);
  EXPECT_STREQ("", tokens[0].value);
  EXPECT_EQ(kINTEGER, tokens[1].token);
  EXPECT_STREQ("3", tokens[1].value);
  EXPECT_EQ(kINTEGER, tokens[2].token);
  EXPECT_STREQ("5", tokens[2].value);
  EXPECT_EQ(kSTRING_INTERPOLATION_END, tokens[3].token);
  EXPECT_STREQ("", tokens[3].value);
  EXPECT_EQ(kEOF, tokens[4].token);

  tokens = Scan(&zone, "'${'hej'}'");
  EXPECT_EQ(4, tokens.length());
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[0].token);
  EXPECT_STREQ("", tokens[0].value);
  EXPECT_EQ(kSTRING, tokens[1].token);
  EXPECT_STREQ("hej", tokens[1].value);
  EXPECT_EQ(kSTRING_INTERPOLATION_END, tokens[2].token);
  EXPECT_STREQ("", tokens[2].value);
  EXPECT_EQ(kEOF, tokens[3].token);

  tokens = Scan(&zone, "'${'${'x'}'}'");
  EXPECT_EQ(6, tokens.length());
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[0].token);
  EXPECT_STREQ("", tokens[0].value);
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[1].token);
  EXPECT_STREQ("", tokens[1].value);
  EXPECT_EQ(kSTRING, tokens[2].token);
  EXPECT_STREQ("x", tokens[2].value);
  EXPECT_EQ(kSTRING_INTERPOLATION_END, tokens[3].token);
  EXPECT_STREQ("", tokens[3].value);
  EXPECT_EQ(kSTRING_INTERPOLATION_END, tokens[4].token);
  EXPECT_STREQ("", tokens[4].value);
  EXPECT_EQ(kEOF, tokens[5].token);

  tokens = Scan(&zone, "'${{}}'");
  EXPECT_EQ(5, tokens.length());
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[0].token);
  EXPECT_STREQ("", tokens[0].value);
  EXPECT_EQ(kLBRACE, tokens[1].token);
  EXPECT_EQ(kRBRACE, tokens[2].token);
  EXPECT_EQ(kSTRING_INTERPOLATION_END, tokens[3].token);
  EXPECT_STREQ("", tokens[3].value);
  EXPECT_EQ(kEOF, tokens[4].token);

  tokens = Scan(&zone, "'${ }'");
  EXPECT_EQ(3, tokens.length());
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[0].token);
  EXPECT_STREQ("", tokens[0].value);
  EXPECT_EQ(kSTRING_INTERPOLATION_END, tokens[1].token);
  EXPECT_STREQ("", tokens[1].value);
  EXPECT_EQ(kEOF, tokens[2].token);

  tokens = Scan(&zone, "'${<)}'");
  EXPECT_EQ(5, tokens.length());
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[0].token);
  EXPECT_STREQ("", tokens[0].value);
  EXPECT_EQ(kLT, tokens[1].token);
  EXPECT_EQ(kRPAREN, tokens[2].token);
  EXPECT_EQ(kSTRING_INTERPOLATION_END, tokens[3].token);
  EXPECT_STREQ("", tokens[3].value);
  EXPECT_EQ(kEOF, tokens[4].token);

  tokens = Scan(&zone, "'$y''$x'");
  EXPECT_EQ(7, tokens.length());
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[0].token);
  EXPECT_STREQ("", tokens[0].value);
  EXPECT_EQ(kIDENTIFIER, tokens[1].token);
  EXPECT_STREQ("y", tokens[1].value);
  EXPECT_EQ(kSTRING_INTERPOLATION_END, tokens[2].token);
  EXPECT_STREQ("", tokens[2].value);
  EXPECT_EQ(kSTRING_INTERPOLATION, tokens[3].token);
  EXPECT_STREQ("", tokens[3].value);
  EXPECT_EQ(kIDENTIFIER, tokens[4].token);
  EXPECT_STREQ("x", tokens[4].value);
  EXPECT_EQ(kSTRING_INTERPOLATION_END, tokens[5].token);
  EXPECT_STREQ("", tokens[5].value);
  EXPECT_EQ(kEOF, tokens[6].token);
}

TEST_CASE(MultilineComments) {
  Zone zone;
  List<TokenData> tokens = Scan(&zone, "1 /* \n */ 2");
  EXPECT_EQ(3, tokens.length());
  EXPECT_EQ(kINTEGER, tokens[0].token);
  EXPECT_STREQ("1", tokens[0].value);
  EXPECT_EQ(kINTEGER, tokens[1].token);
  EXPECT_STREQ("2", tokens[1].value);
  EXPECT_EQ(kEOF, tokens[2].token);
}

}  // namespace fletch
