// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.instructions;

/// A generalization of reflective opcodes and bytecodes.
abstract class Instruction {
  const Instruction();
}

/// A code that can be used in a method body.
abstract class ByteCode extends Instruction {
  const ByteCode();
}

/// A reflective opcode for the fletch VM, for example, Opcode.NewMap.
abstract class Opcode extends Instruction {
  // TODO(ahe): Copy enum Opcode from ../../../src/bridge/opcodes.dart.
  const Opcode();
}

/// One byte of padding.
class Pad extends ByteCode {
  final int byte;

  const Pad([this.byte = 0]);
}
