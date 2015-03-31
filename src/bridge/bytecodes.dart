// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of session;

class Bytecode {
  final String name;
  final int size;

  static const int CHAR_CODE_B = 98;
  static const int CHAR_CODE_I = 105;
  static const int CHAR_CODE_M = 109;

  const Bytecode(this.name, this.size);

  String bytecodeToString(int index, List<int> bytecodes, ProgramModel model) {
    StringBuffer buffer = new StringBuffer();
    buffer.write("${index.toString().padLeft(4)}: ");
    var parts = name.split("%");
    buffer.write(parts[0]);
    var argumentIndex = index + 1;
    for (var i = 1; i < parts.length; ++i) {
      var part = parts[i];
      switch (part.codeUnitAt(0)) {
        case CHAR_CODE_B:
          buffer.write(bytecodes[argumentIndex++]);
          break;
        case CHAR_CODE_I:
          buffer.write(readInt32FromBuffer(bytecodes, argumentIndex));
          argumentIndex += 4;
          break;
        case CHAR_CODE_M:
          var encodedSelector = readInt32FromBuffer(bytecodes, argumentIndex);
          var selector = new Selector(encodedSelector);
          var methodName = model.methodNameMap[selector.id];
          buffer.write((methodName != null) ? methodName : encodedSelector);
          argumentIndex += 4;
          break;
        default:
          throw "Unknown bytecode formatting directive.";
      }
      buffer.write(part.substring(1));
    }
    return buffer.toString();
  }
}

const List<Bytecode> _bytecodes = const [
  const Bytecode("load local 0", 1),
  const Bytecode("load local 1", 1),
  const Bytecode("load local 2", 1),
  const Bytecode("load local %b", 2),
  const Bytecode("load boxed %b", 2),
  const Bytecode("load static %i", 5),
  const Bytecode("load static init %i", 5),
  const Bytecode("load field %b", 2),
  const Bytecode("load const %i", 5),
  const Bytecode("load const @%i", 5),
  const Bytecode("store local %b", 2),
  const Bytecode("store boxed %b", 2),
  const Bytecode("store static %i", 5),
  const Bytecode("store field %b", 2),
  const Bytecode("load literal null", 1),
  const Bytecode("load literal true", 1),
  const Bytecode("load literal false", 1),
  const Bytecode("load literal 0", 1),
  const Bytecode("load literal 1", 1),
  const Bytecode("load literal %b", 2),
  const Bytecode("load literal %i", 5),
  const Bytecode("invoke %m", 5),
  const Bytecode("invoke fast %m", 5),
  const Bytecode("invoke vtable %m", 5),
  const Bytecode("invoke static %i", 5),
  const Bytecode("invoke static @%i", 5),
  const Bytecode("invoke factory %i", 5),
  const Bytecode("invoke factory @%i", 5),
  const Bytecode("invoke native %b %b", 3),
  const Bytecode("invoke native yield %b %b", 3),
  const Bytecode("invoke test %i", 5),
  const Bytecode("invoke eq", 5),
  const Bytecode("invoke lt", 5),
  const Bytecode("invoke le", 5),
  const Bytecode("invoke gt", 5),
  const Bytecode("invoke ge", 5),
  const Bytecode("invoke add", 5),
  const Bytecode("invoke sub", 5),
  const Bytecode("invoke mod", 5),
  const Bytecode("invoke mul", 5),
  const Bytecode("invoke trunc div", 5),
  const Bytecode("invoke bit not", 5),
  const Bytecode("invoke bit and", 5),
  const Bytecode("invoke bit or", 5),
  const Bytecode("invoke bit xor", 5),
  const Bytecode("invoke bit shr", 5),
  const Bytecode("invoke bit shl", 5),
  const Bytecode("pop", 1),
  const Bytecode("return %b %b", 3),
  const Bytecode("branch +%i", 5),
  const Bytecode("branch if true +%i", 5),
  const Bytecode("branch if false +%i", 5),
  const Bytecode("branch -%b", 2),
  const Bytecode("branch if true -%b", 2),
  const Bytecode("branch if false -%b", 2),
  const Bytecode("branch -%i", 5),
  const Bytecode("branch if true -%i", 5),
  const Bytecode("branch if false -%i", 5),
  const Bytecode("pop %b and branch +%i", 6),
  const Bytecode("pop %b and branch -%i", 6),
  const Bytecode("allocate %i", 5),
  const Bytecode("allocate @%i", 5),
  const Bytecode("allocate boxed", 1),
  const Bytecode("negate", 1),
  const Bytecode("stack overflow check %i", 5),
  const Bytecode("throw", 1),
  const Bytecode("subroutine call +%i -%i", 9),
  const Bytecode("subroutine return", 1),
  const Bytecode("process yield", 1),
  const Bytecode("coroutine change", 1),
  const Bytecode("identical", 1),
  const Bytecode("identical non numeric", 1),
  const Bytecode("enter noSuchMethod", 1),
  const Bytecode("exit noSuchMethod", 1),
  const Bytecode("frame size %b", 2),
  const Bytecode("method end %i", 5)
];
