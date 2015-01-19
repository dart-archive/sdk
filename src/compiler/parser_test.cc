// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/shared/assert.h"
#include "src/compiler/builder.h"
#include "src/compiler/parser.h"
#include "src/compiler/scanner.h"
#include "src/shared/test_case.h"

namespace fletch {

TreeNode* ParseNode(Zone* zone, const char* input) {
  Builder builder(zone);
  Scanner scanner(&builder, zone);
  scanner.Scan(input, Location());
  Parser parser(&builder, scanner.EncodedTokens());
  parser.ParseExpression();
  List<TreeNode*> nodes = builder.Nodes();
  EXPECT_EQ(1, nodes.length());
  return nodes[0];
}

int ParseNumber(const char* input) {
  Zone zone;
  return ParseNode(&zone, input)->AsLiteralInteger()->value();
}

const char* ParseString(Zone* zone, const char* input) {
  return ParseNode(zone, input)->AsLiteralString()->value();
}

TEST_CASE(SimpleLiterals) {
  EXPECT_EQ(3, ParseNumber("3"));
  EXPECT_EQ(4, ParseNumber("4"));
  EXPECT_EQ(42, ParseNumber("42"));

  Zone zone;
  EXPECT_STREQ("foo", ParseString(&zone, "'foo'"));
  EXPECT_STREQ("bar", ParseString(&zone, "'bar'"));
}

}  // namespace fletch
