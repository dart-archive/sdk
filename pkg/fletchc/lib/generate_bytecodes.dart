// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

main() {
  print("""
// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// WARNING: Generated file, do not edit!

part of fletch.bytecodes;
""");

  print("enum Opcode {");
  doBytecodes((String name, String format, int size, spDiff,
               String formatString) {
    print("  $name,");
  });
  print("}");

  doBytecodes((String name, String format, int size, spDiff,
               String formatString) {
  List<String> fields = <String>[];
  List<String> encode = <String>[];

  for (int i = 0; i < format.length; i++) {
    String code = format[i];
    switch (code) {
      case "B":
        String field = "uint8Argument$i";
        fields.add(field);
        encode.add("        ..addUint8($field)\n");
        break;
      case "I":
        String field = "uint32Argument$i";
        fields.add(field);
        encode.add("        ..addUint32($field)\n");
        break;
      default:
        throw "Unknown format: $code";
    }
  }
print("""

class $name extends Bytecode {
${
  fields.map((a) => '  final int $a;\n').join('')
}  const $name(${fields.map((a) => 'this.$a').join(', ')})
      : super();

  Opcode get opcode => Opcode.$name;

  String get name => '$name';

  String get format => '$format';

  int get size => $size;

  int get spDiff => $spDiff;

  String get formatString => '$formatString';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
${
  encode.join("")
}        ..sendOn(sink);
  }
}""");
  });
}

void doBytecodes(V(String name, String format, int size, spDiff,
                   String formatString)) {
  // Code below was copied from src/shared/bytecodes.h.
  var kVarDiff = "VAR_DIFF";
  /* Name              Format Size   SP-diff  format-string */
  V("LoadLocal0",            "",   1,        1, "load local 0");
  V("LoadLocal1",            "",   1,        1, "load local 1");
  V("LoadLocal2",            "",   1,        1, "load local 2");
  V("LoadLocal",             "B",  2,        1, "load local %d");

  V("LoadBoxed",             "B",  2,        1, "load boxed %d");
  V("LoadStatic",            "I",  5,        1, "load static %d");
  V("LoadStaticInit",        "I",  5,        1, "load static init %d");
  V("LoadField",             "B",  2,        0, "load field %d");

  V("LoadConst",             "I",  5,        1, "load const %d");
  V("LoadConstUnfold",       "I",  5,        1, "load const @%d");

  V("StoreLocal",            "B",  2,        0, "store local %d");
  V("StoreBoxed",            "B",  2,        0, "store boxed %d");
  V("StoreStatic",           "I",  5,        0, "store static %d");
  V("StoreField",            "B",  2,       -1, "store field %d");

  V("LoadLiteralNull",       "",   1,        1, "load literal null");
  V("LoadLiteralTrue",       "",   1,        1, "load literal true");
  V("LoadLiteralFalse",      "",   1,        1, "load literal false");
  V("LoadLiteral0",          "",   1,        1, "load literal 0");
  V("LoadLiteral1",          "",   1,        1, "load literal 1");
  V("LoadLiteral",           "B",  2,        1, "load literal %d");
  V("LoadLiteralWide",       "I",  5,        1, "load literal %d");

  V("InvokeMethod",          "I",  5, kVarDiff, "invoke %d");

  V("InvokeStatic",          "I",  5, kVarDiff, "invoke static %d");
  V("InvokeStaticUnfold",    "I",  5, kVarDiff, "invoke static @%d");
  V("InvokeFactory",         "I",  5, kVarDiff, "invoke factory %d");
  V("InvokeFactoryUnfold",   "I",  5, kVarDiff, "invoke factory @%d");

  V("InvokeNative",          "BB", 3,        1, "invoke native %d %d");
  V("InvokeNativeYield",     "BB", 3,        1, "invoke native yield %d %d");

  V("InvokeTest",            "I",  5,        0, "invoke test %d");

  V("InvokeEq",              "I",  5,       -1, "invoke eq");
  V("InvokeLt",              "I",  5,       -1, "invoke lt");
  V("InvokeLe",              "I",  5,       -1, "invoke le");
  V("InvokeGt",              "I",  5,       -1, "invoke gt");
  V("InvokeGe",              "I",  5,       -1, "invoke ge");

  V("InvokeAdd",             "I",  5,       -1, "invoke add");
  V("InvokeSub",             "I",  5,       -1, "invoke sub");
  V("InvokeMod",             "I",  5,       -1, "invoke mod");
  V("InvokeMul",             "I",  5,       -1, "invoke mul");
  V("InvokeTruncDiv",        "I",  5,       -1, "invoke trunc div");

  V("InvokeBitNot",          "I",  5,        0, "invoke bit not");
  V("InvokeBitAnd",          "I",  5,       -1, "invoke bit and");
  V("InvokeBitOr",           "I",  5,       -1, "invoke bit or");
  V("InvokeBitXor",          "I",  5,       -1, "invoke bit xor");
  V("InvokeBitShr",          "I",  5,       -1, "invoke bit shr");
  V("InvokeBitShl",          "I",  5,       -1, "invoke bit shl");

  V("Pop",                   "",   1,       -1, "pop");
  V("Return",                "BB", 3,       -1, "return %d %d");

  V("BranchLong",            "I",  5,        0, "branch +%d");
  V("BranchIfTrueLong",      "I",  5,       -1, "branch if true +%d");
  V("BranchIfFalseLong",     "I",  5,       -1, "branch if false +%d");

  V("BranchBack",            "B",  2,        0, "branch -%d");
  V("BranchBackIfTrue",      "B",  2,       -1, "branch if true -%d");
  V("BranchBackIfFalse",     "B",  2,       -1, "branch if false -%d");

  V("BranchBackLong",        "I",  5,        0, "branch -%d");
  V("BranchBackIfTrueLong",  "I",  5,       -1, "branch if true -%d");
  V("BranchBackIfFalseLong", "I",  5,       -1, "branch if false -%d");

  V("Allocate",              "I",  5, kVarDiff, "allocate %d");
  V("AllocateUnfold",        "I",  5, kVarDiff, "allocate @%d");
  V("AllocateBoxed",         "",   1,        0, "allocate boxed");

  V("Negate",                "",   1,        0, "negate");

  V("StackOverflowCheck",    "",   5,        0, "stack overflow check");

  V("Throw",                 "",   1,        0, "throw");
  V("SubroutineCall",        "II", 9, kVarDiff, "subroutine call +%d -%d");
  V("SubroutineReturn",      "",   1,       -1, "subroutine return");

  V("ProcessYield",          "",   1,        0, "process yield");
  V("CoroutineChange",       "",   1,       -1, "coroutine change");

  V("Identical",             "",   1,       -1, "identical");
  V("IdenticalNonNumeric",   "",   1,       -1, "identical non numeric");

  V("EnterNoSuchMethod",     "",   1,        3, "enter noSuchMethod");
  V("ExitNoSuchMethod",      "",   1,       -1, "exit noSuchMethod");

  V("FrameSize",             "B",  2, kVarDiff, "frame size %d");

  V("MethodEnd",             "I",  5,        0, "method end %d");
}
