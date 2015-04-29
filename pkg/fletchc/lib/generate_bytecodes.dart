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
  doBytecodes((String name, bool isBranching, String format, int size,
               spDiff, String formatString) {
    print("  $name,");
  });
  print("}");

  doBytecodes((String name, bool isBranching, String format, int size,
               spDiff, String formatString) {
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

  String toStringExpression = formatString;
  if (!fields.isEmpty) {
    List<String> parts = formatString.split("%d");
    StringBuffer buffer = new StringBuffer();
    Iterator iterator = fields.iterator;
    for (String part in parts) {
      buffer.write(part);
      if (iterator.moveNext()) {
        buffer.write(r'${');
        buffer.write(iterator.current);
        buffer.write('}');
      }
    }
    toStringExpression = '$buffer';
  }

print("""

class $name extends Bytecode {
${
  fields.map((a) => '  final int $a;\n').join('')
}  const $name(${fields.map((a) => 'this.$a').join(', ')})
      : super();

  Opcode get opcode => Opcode.$name;

  String get name => '$name';

  bool get isBranching => $isBranching;

  String get format => '$format';

  int get size => $size;

  int get stackPointerDifference => $spDiff;

  String get formatString => '$formatString';

  void addTo(Sink<List<int>> sink) {
    buffer
        ..addUint8(opcode.index)
${
  encode.join("")
}        ..sendOn(sink);
  }

  String toString() => '$toStringExpression';
}""");
  });
}

void doBytecodes(V(String name, bool isBranching, String format, int size,
                   spDiff, String formatString)) {
  // Code below was copied from src/shared/bytecodes.h.
  var kVarDiff = "VAR_DIFF";
  /* Name             Branching Format Size   SP-diff  format-string   */
  V("LoadLocal0",           false,    "",   1,        1, "load local 0");
  V("LoadLocal1",           false,    "",   1,        1, "load local 1");
  V("LoadLocal2",           false,    "",   1,        1, "load local 2");
  V("LoadLocal",            false,    "B",  2,        1, "load local %d");

  V("LoadBoxed",            false,    "B",  2,        1, "load boxed %d");
  V("LoadStatic",           false,    "I",  5,        1, "load static %d");
  V("LoadStaticInit",       false,    "I",  5,        1, "load static init %d");
  V("LoadField",            false,    "B",  2,        0, "load field %d");

  V("LoadConst",            false,    "I",  5,        1, "load const %d");
  V("LoadConstUnfold",      false,    "I",  5,        1, "load const @%d");

  V("StoreLocal",           false,    "B",  2,        0, "store local %d");
  V("StoreBoxed",           false,    "B",  2,        0, "store boxed %d");
  V("StoreStatic",          false,    "I",  5,        0, "store static %d");
  V("StoreField",           false,    "B",  2,       -1, "store field %d");

  V("LoadLiteralNull",      false,    "",   1,        1, "load literal null");
  V("LoadLiteralTrue",      false,    "",   1,        1, "load literal true");
  V("LoadLiteralFalse",     false,    "",   1,        1, "load literal false");
  V("LoadLiteral0",         false,    "",   1,        1, "load literal 0");
  V("LoadLiteral1",         false,    "",   1,        1, "load literal 1");
  V("LoadLiteral",          false,    "B",  2,        1, "load literal %d");
  // TODO(ahe): The argument to LoadLiteralWide is probably signed.
  V("LoadLiteralWide",      false,    "I",  5,        1, "load literal %d");

  V("InvokeMethod",          true,    "I",  5, kVarDiff, "invoke %d");
  V("InvokeMethodFast",      true,    "I",  5, kVarDiff, "invoke fast %d");
  V("InvokeMethodVtable",    true,    "I",  5, kVarDiff, "invoke vtable %d");

  V("InvokeStatic",          true,    "I",  5, kVarDiff, "invoke static %d");
  V("InvokeStaticUnfold",    true,    "I",  5, kVarDiff, "invoke static @%d");
  V("InvokeFactory",         true,    "I",  5, kVarDiff, "invoke factory %d");
  V("InvokeFactoryUnfold",   true,    "I",  5, kVarDiff, "invoke factory @%d");

  V("InvokeNative",          true,    "BB", 3,        1, "invoke native %d %d");
  V("InvokeNativeYield",     true,    "BB", 3,   1, "invoke native yield %d %d");

  V("InvokeTest",            true,    "I",  5,        0, "invoke test %d");

  V("InvokeEq",              true,    "I",  5,       -1, "invoke eq");
  V("InvokeLt",              true,    "I",  5,       -1, "invoke lt");
  V("InvokeLe",              true,    "I",  5,       -1, "invoke le");
  V("InvokeGt",              true,    "I",  5,       -1, "invoke gt");
  V("InvokeGe",              true,    "I",  5,       -1, "invoke ge");

  V("InvokeAdd",             true,    "I",  5,       -1, "invoke add");
  V("InvokeSub",             true,    "I",  5,       -1, "invoke sub");
  V("InvokeMod",             true,    "I",  5,       -1, "invoke mod");
  V("InvokeMul",             true,    "I",  5,       -1, "invoke mul");
  V("InvokeTruncDiv",        true,    "I",  5,       -1, "invoke trunc div");

  V("InvokeBitNot",          true,    "I",  5,        0, "invoke bit not");
  V("InvokeBitAnd",          true,    "I",  5,       -1, "invoke bit and");
  V("InvokeBitOr",           true,    "I",  5,       -1, "invoke bit or");
  V("InvokeBitXor",          true,    "I",  5,       -1, "invoke bit xor");
  V("InvokeBitShr",          true,    "I",  5,       -1, "invoke bit shr");
  V("InvokeBitShl",          true,    "I",  5,       -1, "invoke bit shl");

  V("Pop",                  false,    "",   1,       -1, "pop");
  V("Return",                true,    "BB", 3,       -1, "return %d %d");

  V("BranchLong",            true,    "I",  5,        0, "branch +%d");
  V("BranchIfTrueLong",      true,    "I",  5,       -1, "branch if true +%d");
  V("BranchIfFalseLong",     true,    "I",  5,       -1, "branch if false +%d");

  V("BranchBack",            true,    "B",  2,        0, "branch -%d");
  V("BranchBackIfTrue",      true,    "B",  2,       -1, "branch if true -%d");
  V("BranchBackIfFalse",     true,    "B",  2,       -1, "branch if false -%d");

  V("BranchBackLong",        true,    "I",  5,        0, "branch -%d");
  V("BranchBackIfTrueLong",  true,    "I",  5,       -1, "branch if true -%d");
  V("BranchBackIfFalseLong", true,    "I",  5,       -1, "branch if false -%d");

  V("PopAndBranchLong",      true,    "BI", 6,   0, "pop %d and branch long +%d");
  V("PopAndBranchBackLong",  true,    "BI", 6,   0, "pop %d and branch long -%d");

  V("Allocate",             false,    "I",  5, kVarDiff, "allocate %d");
  V("AllocateUnfold",       false,    "I",  5, kVarDiff, "allocate @%d");
  V("AllocateImmutable",    false,    "I",  5, kVarDiff, "allocateim %d");
  V("AllocateImmutableUnfold", false, "I",  5, kVarDiff, "allocateim @%d");
  V("AllocateBoxed",        false,    "",   1,        0, "allocate boxed");

  V("Negate",               false,    "",   1,        0, "negate");

  V("StackOverflowCheck",    true,    "",   5,        0, "stack overflow check");

  V("Throw",                 true,    "",   1,        0, "throw");
  V("SubroutineCall",        true,  "II", 9, kVarDiff, "subroutine call +%d -%d");
  V("SubroutineReturn",      true,    "",   1,       -1, "subroutine return");

  V("ProcessYield",          true,    "",   1,        0, "process yield");
  V("CoroutineChange",       true,    "",   1,       -1, "coroutine change");

  V("Identical",             true,    "",   1,       -1, "identical");
  V("IdenticalNonNumeric",   true,    "",   1,       -1, "identical non numeric");

  V("EnterNoSuchMethod",     true,    "",   1,        3, "enter noSuchMethod");
  V("ExitNoSuchMethod",      true,    "",   1,       -1, "exit noSuchMethod");

  V("FrameSize",            false,    "B",  2, kVarDiff, "frame size %d");

  V("MethodEnd",            false,    "I",  5,        0, "method end %d");
}
