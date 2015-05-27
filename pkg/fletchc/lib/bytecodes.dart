// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch.bytecodes;

import 'dart:typed_data' show
    ByteData,
    Endianness,
    Uint8List;

part 'generated_bytecodes.dart';

const int VAR_DIFF = 0x3FFFFFFF;

abstract class Bytecode {
  static final BytecodeBuffer _buffer = new BytecodeBuffer();

  static bool identicalBytecodes(List<Bytecode> expected,
                                 List<Bytecode> actual) {
    if (expected.length != actual.length) return false;
    for (int i = 0; i < expected.length; i++) {
      if (expected[i] != actual[i]) return false;
    }
    return true;
  }

  const Bytecode();

  Opcode get opcode;

  String get name;

  String get format;

  int get size;

  /// The effect on stack size.
  int get stackPointerDifference;

  String get formatString;

  void addTo(Sink<List<int>> sink);

  bool operator==(Bytecode other) => other.opcode == opcode;

  int get hashCode => opcode.index;

  /// Shared buffer. Not safe to use in asynchronous operations.
  BytecodeBuffer get buffer => _buffer;
}

class BytecodeBuffer {
  int position = 0;

  Uint8List list = new Uint8List(16);

  ByteData get view => new ByteData.view(list.buffer);

  void growBytes(int size) {
    while (position + size >= list.length) {
      list = new Uint8List(list.length * 2)
          ..setRange(0, list.length, list);
    }
  }

  void addUint8(int value) {
    growBytes(1);
    view.setUint8(position++, value);
  }

  void addUint32(int value) {
    growBytes(4);
    view.setUint32(position, value, Endianness.LITTLE_ENDIAN);
    position += 4;
  }

  void addUint64(int value) {
    growBytes(8);
    view.setUint64(position, value, Endianness.LITTLE_ENDIAN);
    position += 8;
  }

  void addUint8List(List<int> value) {
    growBytes(value.length);
    list.setRange(position, position + value.length, value);
    position += value.length;
  }

  void sendOn(Sink<List<int>> sink) {
    // TODO(ahe): Avoid all the copying, redesign this method.
    sink.add(list.sublist(0, position));
    position = 0;
  }
}
