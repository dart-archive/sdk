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
  if (fields.isNotEmpty) {
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

  String equals = '';
  if (fields.isNotEmpty) {
    StringBuffer equalsBuffer =
        new StringBuffer('\n\n  operator==(Bytecode other) {\n');
    equalsBuffer.writeln('    if (!(super==(other))) return false;');
    equalsBuffer.writeln('    $name rhs = other;');
    for (String field in fields) {
      equalsBuffer.writeln('    if ($field != rhs.$field) return false;');
    }
    equalsBuffer.writeln('    return true;');
    equalsBuffer.write('  }');
    equals = '$equalsBuffer';
  }

  String hashCode = '';
  if (fields.isNotEmpty) {
    StringBuffer hashCodeBuffer =
        new StringBuffer('\n\n  int get hashCode {\n');
    hashCodeBuffer.writeln('    int value = super.hashCode;');
    for (String field in fields) {
      hashCodeBuffer.writeln('    value += $field;');
    }
    hashCodeBuffer.writeln('    return value;');
    hashCodeBuffer.write('  }');
    hashCode = '$hashCodeBuffer';
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
    new BytecodeBuffer()
        ..addUint8(opcode.index)
${
  encode.join("")
}        ..sendOn(sink);
  }

  String toString() => '$toStringExpression';$equals$hashCode
}""");
  });
}

void doBytecodes(V(String name, bool isBranching, String format, int size,
                   spDiff, String formatString)) {
  // Code below was copied from src/shared/bytecodes.h.
  var kVarDiff = "VAR_DIFF";

  void INVOKE(V, name, diff, desc, suffix, type) {
    V("Invoke${name}${suffix}", true, "I", 5, diff, "invoke ${type}${desc}%d");
  }

  void INVOKES_DO(V, suffix, type) {
    INVOKE(V, "Method", kVarDiff, "method ", suffix, type);
    INVOKE(V, "Test", 0, "test ", suffix, type);

    INVOKE(V, "Eq", -1, "eq ", suffix, type);
    INVOKE(V, "Lt", -1, "lt ", suffix, type);
    INVOKE(V, "Le", -1, "le ", suffix, type);
    INVOKE(V, "Gt", -1, "gt ", suffix, type);
    INVOKE(V, "Ge", -1, "ge ", suffix, type);

    INVOKE(V, "Add", -1, "add ", suffix, type);
    INVOKE(V, "Sub", -1, "sub ", suffix, type);
    INVOKE(V, "Mod", -1, "mod ", suffix, type);
    INVOKE(V, "Mul", -1, "mul ", suffix, type);
    INVOKE(V, "TruncDiv", -1, "trunc div ", suffix, type);

    INVOKE(V, "BitNot",  0, "bit not ", suffix, type);
    INVOKE(V, "BitAnd", -1, "bit and ", suffix, type);
    INVOKE(V, "BitOr",  -1, "bit or ", suffix, type);
    INVOKE(V, "BitXor", -1, "bit xor ", suffix, type);
    INVOKE(V, "BitShr", -1, "bit shr ", suffix, type);
    INVOKE(V, "BitShl", -1, "bit shl ", suffix, type);

    INVOKE(V, "Static", kVarDiff, "static ", suffix, type);
    INVOKE(V, "Factory", kVarDiff, "factory ", suffix, type);
  }

  /* Name             Branching Format Size   SP-diff  format-string   */
  V("LoadLocal0",           false,    "",   1,        1, "load local 0");
  V("LoadLocal1",           false,    "",   1,        1, "load local 1");
  V("LoadLocal2",           false,    "",   1,        1, "load local 2");
  V("LoadLocal",            false,    "B",  2,        1, "load local %d");
  V("LoadLocalWide",        false,    "I",  5,        1, "load local %d");

  V("LoadBoxed",            false,    "B",  2,        1, "load boxed %d");
  V("LoadStatic",           false,    "I",  5,        1, "load static %d");
  V("LoadStaticInit",       false,    "I",  5,        1, "load static init %d");
  V("LoadField",            false,    "B",  2,        0, "load field %d");
  V("LoadFieldWide",        false,    "I",  5,        0, "load field %d");

  V("StoreLocal",           false,    "B",  2,        0, "store local %d");
  V("StoreBoxed",           false,    "B",  2,        0, "store boxed %d");
  V("StoreStatic",          false,    "I",  5,        0, "store static %d");
  V("StoreField",           false,    "B",  2,       -1, "store field %d");
  V("StoreFieldWide",       false,    "I",  5,       -1, "store field %d");

  V("LoadLiteralNull",      false,    "",   1,        1, "load literal null");
  V("LoadLiteralTrue",      false,    "",   1,        1, "load literal true");
  V("LoadLiteralFalse",     false,    "",   1,        1, "load literal false");
  V("LoadLiteral0",         false,    "",   1,        1, "load literal 0");
  V("LoadLiteral1",         false,    "",   1,        1, "load literal 1");
  V("LoadLiteral",          false,    "B",  2,        1, "load literal %d");
  // TODO(ahe): The argument to LoadLiteralWide is probably signed.
  V("LoadLiteralWide",      false,    "I",  5,        1, "load literal %d");

  INVOKES_DO(V, "", "");
  V("Allocate",             false,    "I",  5, kVarDiff, "allocate %d");
  V("AllocateImmutable",    false,    "I",  5, kVarDiff, "allocateim %d");
  V("LoadConst",            false,    "I",  5,        1, "load const %d");

  V("InvokeNoSuchMethod",   true, "I", 5, kVarDiff, "invoke no such method %d");
  V("InvokeTestNoSuchMethod", true, "I", 5, 0, "invoke test no such method %d");

  V("InvokeNative",          true,    "BB", 3,        1, "invoke native %d %d");
  V("InvokeNativeYield",     true,    "BB", 3,   1, "invoke native yield %d %d");

  V("InvokeSelector",        true,    "I",  5, kVarDiff, "invoke selector");

  V("Pop",                  false,    "",   1,       -1, "pop");
  V("Return",                true,    "BB", 3,       -1, "return %d %d");
  V("ReturnWide",            true,    "IB", 6,       -1, "return %d %d");
  V("ReturnNull",            true,    "BB", 3,        0, "return null %d %d");

  V("BranchWide",            true,    "I",  5,        0, "branch +%d");
  V("BranchIfTrueWide",      true,    "I",  5,       -1, "branch if true +%d");
  V("BranchIfFalseWide",     true,    "I",  5,       -1, "branch if false +%d");

  V("BranchBack",            true,    "B",  2,        0, "branch -%d");
  V("BranchBackIfTrue",      true,    "B",  2,       -1, "branch if true -%d");
  V("BranchBackIfFalse",     true,    "B",  2,       -1, "branch if false -%d");

  V("BranchBackWide",        true,    "I",  5,        0, "branch -%d");
  V("BranchBackIfTrueWide",  true,    "I",  5,       -1, "branch if true -%d");
  V("BranchBackIfFalseWide", true,    "I",  5,       -1, "branch if false -%d");

  V("PopAndBranchWide",      true,    "BI", 6,        0, "pop %d and branch +%d");
  V("PopAndBranchBackWide",  true,    "BI", 6,        0, "pop %d and branch -%d");

  V("AllocateBoxed",        false,    "",   1,        0, "allocate boxed");

  V("Negate",               false,    "",   1,        0, "negate");

  V("StackOverflowCheck",    true,   "I",   5,      0, "stack overflow check %d");

  V("Throw",                 true,    "",   1,        0, "throw");
  V("SubroutineCall",        true,  "II", 9, kVarDiff, "subroutine call +%d -%d");
  V("SubroutineReturn",      true,    "",   1,       -1, "subroutine return");

  V("ProcessYield",          true,    "",   1,        0, "process yield");
  V("CoroutineChange",       true,    "",   1,       -1, "coroutine change");

  V("Identical",             true,    "",   1,       -1, "identical");
  V("IdenticalNonNumeric",   true,    "",   1,       -1, "identical non numeric");

  V("EnterNoSuchMethod",     true,    "B",  2, kVarDiff, "enter noSuchMethod +%d");
  V("ExitNoSuchMethod",      true,    "",   1,       -1, "exit noSuchMethod");

  V("FrameSize",            false,    "B",  2, kVarDiff, "frame size %d");

  INVOKES_DO(V, "Unfold", "unfold ");
  V("AllocateUnfold",       false,    "I",  5, kVarDiff, "allocate @%d");
  V("AllocateImmutableUnfold", false, "I",  5, kVarDiff, "allocateim @%d");
  V("LoadConstUnfold",      false,    "I",  5,        1, "load const @%d");

  V("MethodEnd",            false,    "I",  5,        0, "method end %d");
}
