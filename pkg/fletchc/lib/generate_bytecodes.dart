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

  String equals = '';
  if (!fields.isEmpty) {
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
  if (!fields.isEmpty) {
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
    buffer
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

  void INVOKES(V, name, diff, desc) {
    V("Invoke${name}",       true, "I", 5, diff, "invoke ${desc}%d");
    V("Invoke${name}Fast",   true, "I", 5, diff, "invoke fast ${desc}%d");
    V("Invoke${name}Vtable", true, "I", 5, diff, "invoke vtable ${desc}%d");
  }

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

  INVOKES(V, "Method", kVarDiff, "");

  V("InvokeStatic",          true,    "I",  5, kVarDiff, "invoke static %d");
  V("InvokeStaticUnfold",    true,    "I",  5, kVarDiff, "invoke static @%d");
  V("InvokeFactory",         true,    "I",  5, kVarDiff, "invoke factory %d");
  V("InvokeFactoryUnfold",   true,    "I",  5, kVarDiff, "invoke factory @%d");

  V("InvokeNative",          true,    "BB", 3,        1, "invoke native %d %d");
  V("InvokeNativeYield",     true,    "BB", 3,   1, "invoke native yield %d %d");

  V("InvokeSelector",        true,    "I",  5, kVarDiff, "invoke selector");

  INVOKES(V, "Test", 0, "test ");

  INVOKES(V, "Eq", -1, "eq ");
  INVOKES(V, "Lt", -1, "lt ");
  INVOKES(V, "Le", -1, "le ");
  INVOKES(V, "Gt", -1, "gt ");
  INVOKES(V, "Ge", -1, "ge ");

  INVOKES(V, "Add", -1, "add ");
  INVOKES(V, "Sub", -1, "sub ");
  INVOKES(V, "Mod", -1, "mod ");
  INVOKES(V, "Mul", -1, "mul ");
  INVOKES(V, "TruncDiv", -1, "trunc div ");

  INVOKES(V, "BitNot",  0, "bit not ");
  INVOKES(V, "BitAnd", -1, "bit and ");
  INVOKES(V, "BitOr",  -1, "bit or ");
  INVOKES(V, "BitXor", -1, "bit xor ");
  INVOKES(V, "BitShr", -1, "bit shr ");
  INVOKES(V, "BitShl", -1, "bit shl ");

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

  V("MethodEnd",            false,    "I",  5,        0, "method end %d");
}
