// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stdio.h>
#include <stdarg.h>

#include "src/shared/assert.h"
#include "src/shared/bytecodes.h"
#include "src/shared/test_case.h"
#include "src/compiler/builder.h"
#include "src/compiler/compiler.h"
#include "src/compiler/emitter.h"
#include "src/compiler/scanner.h"
#include "src/compiler/string_buffer.h"
#include "src/compiler/tree.h"

namespace fletch {

class TestWriter : public Bytecode::Writer {
 public:
  explicit TestWriter(Zone* zone) : buffer_(zone) { }

  void Write(const char* format, ...) {
    va_list args;
    va_start(args, format);
    buffer_.VPrint(format, args);
    va_end(args);
  }

  const char* ToString() {
    return buffer_.ToString();
  }

 private:
  StringBuffer buffer_;
};

const char* Compile(Zone* zone, const char* source) {
  Builder builder(zone);
  Scanner scanner(&builder, zone);
  Location location = builder.source()->LoadFromBuffer("<test_source>",
                                                       source,
                                                       strlen(source));
  CompilationUnitNode* unit = builder.BuildUnit(location);
  LibraryNode* library =
      new(zone) LibraryNode(unit, List<CompilationUnitNode*>());
  Scope scope(zone, 0, NULL);
  library->set_scope(&scope);
  MethodNode* method = unit->declarations()[0]->AsMethod();
  method->set_owner(library);
  Compiler compiler(zone, &builder, "");
  Emitter emitter(zone, method->parameters().length());
  compiler.CompileMethod(method, &emitter);

  List<uint8> bytes = emitter.GetCode()->bytes();
  int index = 0;
  TestWriter writer(zone);
  Opcode opcode;
  do {
    opcode = static_cast<Opcode>(bytes[index]);
    index += Bytecode::Print(bytes.data() + index, &writer);
    writer.Write(";");
  } while (opcode != kMethodEnd);
  return writer.ToString();
}

TEST_CASE(BlockStructure) {
  Zone zone;

  EXPECT_STREQ(
    "load literal null;load literal null;pop;pop;load literal null;"
    "return 1 0;method end 8;",
    Compile(&zone, "foo() { var x; { var y; } }"));
}

TEST_CASE(ReturnParameter) {
  Zone zone;

  EXPECT_STREQ(
    "load local 1;return 1 1;method end 4;",
    Compile(&zone, "foo(x) { return x; }"));
  EXPECT_STREQ(
    "load local 1;return 1 2;method end 4;",
    Compile(&zone, "foo(x,y) { return y; }"));
}

TEST_CASE(ReturnLiteral) {
  Zone zone;

  EXPECT_STREQ(
    "load literal 42;return 1 0;method end 5;",
    Compile(&zone, "foo() { return 42; }"));
  EXPECT_STREQ(
    "load literal 1234;return 1 0;method end 8;",
    Compile(&zone, "foo() { return 1234; }"));
  EXPECT_STREQ(
    "load literal 12345678;return 1 0;method end 8;",
    Compile(&zone, "foo() { return 12345678; }"));
}

TEST_CASE(PopParameter) {
  Zone zone;

  EXPECT_STREQ(
    "load local 1;pop;load literal null;return 1 1;method end 6;",
    Compile(&zone, "foo(x) { x; }"));
}

TEST_CASE(PopDot) {
  Zone zone;

  EXPECT_STREQ(
    "load local 1;invoke 62720;pop;load literal null;return 1 1;method end 11;",
    Compile(&zone, "foo(x) { x.y; }"));
}

TEST_CASE(PopInvoke) {
  Zone zone;

  EXPECT_STREQ(
    "load local 1;invoke 62464;pop;load literal null;return 1 1;method end 11;",
    Compile(&zone, "foo(x) { x.y(); }"));
  EXPECT_STREQ(
    "load local 1;load literal 1;invoke 62465;pop;load literal null;return 1 1;"
    "method end 12;",
    Compile(&zone, "foo(x) { x.y(1); }"));
  EXPECT_STREQ(
    "load local 1;load literal 1;load literal 2;invoke 62466;pop;"
    "load literal null;return 1 1;method end 14;",
    Compile(&zone, "foo(x) { x.y(1, 2); }"));
}

TEST_CASE(If) {
  Zone zone;

  EXPECT_STREQ(
    "load local 1;branch if false +10;load literal 42;return 1 1;"
    "load literal null;return 1 1;method end 15;",
    Compile(&zone, "foo(x) { if (x) return 42; }"));
  EXPECT_STREQ(
    "load local 1;branch if false +15;load literal 42;"
    "return 1 1;branch +13;load local 1;load literal 1;invoke 62465;pop;"
    "load literal null;return 1 1;method end 28;",
    Compile(&zone, "foo(x) { if (x) return 42; else x.y(1); }"));
}

TEST_CASE(While) {
  Zone zone;

  EXPECT_STREQ(
    "load local 1;branch if false +10;load literal 42;pop;branch -9;"
    "load literal null;return 1 1;method end 15;",
    Compile(&zone, "foo(x) { while (x) 42; }"));
}

TEST_CASE(DoWhile) {
  Zone zone;

  EXPECT_STREQ(
    "load literal 42;pop;load local 1;branch if true -4;load literal null;"
    "return 1 1;method end 10;",
    Compile(&zone, "foo(x) { do { 42; } while (x); }"));
}

TEST_CASE(Binary) {
  Zone zone;

  EXPECT_STREQ(
    "load literal 42;load literal 87;invoke add;return 1 1;method end 12;",
    Compile(&zone, "foo(x) { return 42 + 87; }"));
  EXPECT_STREQ(
    "load literal 1;load literal 2;invoke mul;return 1 1;method end 11;",
    Compile(&zone, "foo(x) { return 1 * 2; }"));
}

TEST_CASE(VariableDeclaration) {
  Zone zone;

  EXPECT_STREQ(
    "load literal 87;load literal 42;store local 1;pop;load local 0;"
    "return 2 0;pop;method end 12;",
    Compile(&zone, "foo() { var x = 87; x = 42; return x; }"));
  EXPECT_STREQ(
    "load literal null;load literal null;load literal 42;store local 1;pop;pop;"
    "pop;load literal null;return 1 0;method end 13;",
    Compile(&zone, "foo() { var x, y; y = 42; }"));
}

TEST_CASE(Closure) {
  Zone zone;

  EXPECT_STREQ(
    "load literal 87;allocate boxed;load local 0;allocate @0;"
    "pop;load boxed 0;return 2 0;pop;method end 16;",
    Compile(&zone, "foo() { var x = 87; (){x;}; return x; }"));
}

TEST_CASE(Finally) {
  Zone zone;

  EXPECT_STREQ(
    "load literal null;load literal null;store local 1;pop;"
    "subroutine call +42 -33;load local 0;return 2 0;branch +15;"
    "subroutine call +24 -15;throw;subroutine call +14 -5;branch +6;"
    "subroutine return;pop;load literal null;return 1 0;method end 53;",
    Compile(&zone, "foo() { try { return; } finally { } }"));
}

}  // namespace fletch
