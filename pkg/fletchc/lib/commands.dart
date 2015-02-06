// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.commands;

import 'dart:async' show
    StreamSink;

import 'dart:convert' show
    UTF8;

import 'dart:typed_data' show
    ByteData,
    Endianness,
    Uint8List;

class Command {
  final Opcode opcode;

  const Command(this.opcode);
}

class PushNewString extends Command {
  final String value;

  const PushNewString(this.value)
      : super(Opcode.PushNewString);

  void addTo(StreamSink<List<int>> sink) {
    List<int> payload = UTF8.encode(value);
    int header = 4 /* 32 bit uint */ + 1 /* Opcode */ + 4 /* 32 bit unit */;
    Uint8List list = new Uint8List(header + payload.length);
    ByteData view = new ByteData.view(list.buffer);
    view.setUint32(0, payload.length + 4, Endianness.LITTLE_ENDIAN);
    view.setUint8(4, opcode.index);
    view.setUint32(5, payload.length, Endianness.LITTLE_ENDIAN);
    for (int i = 0; i < payload.length; i++) {
      list[i + header] = payload[i];
    }
    sink.add(list);
  }
}

class Generic extends Command {
  final List<int> payload;

  const Generic(Opcode opcode, this.payload)
      : super(opcode);

  void addTo(StreamSink<List<int>> sink) {
    int header = 4 /* 32 bit uint */ + 1 /* Opcode */;
    Uint8List list = new Uint8List(header + payload.length);
    ByteData view = new ByteData.view(list.buffer);
    view.setUint32(0, payload.length, Endianness.LITTLE_ENDIAN);
    view.setUint8(4, opcode.index);
    for (int i = 0; i < payload.length; i++) {
      list[i + header] = payload[i];
    }
    sink.add(list);
  }
}

enum Opcode {
  // Session opcodes.
  // TODO(ahe): Understand what "Session opcodes" mean and turn it into a
  // proper documentation comment.
  ConnectionError,
  CompilerError,
  SessionEnd,
  ForceTermination,

  RunMain,
  WriteSnapshot,
  CollectGarbage,

  NewMap,
  DeleteMap,
  PushFromMap,
  PopToMap,

  Dup,
  Drop,
  PushNull,
  PushBoolean,
  PushNewInteger,
  PushNewDouble,
  PushNewString,
  PushNewInstance,
  PushNewArray,
  PushNewFunction,
  PushNewInitializer,
  PushNewClass,
  PushBuiltinClass,
  PushConstantList,
  PushConstantMap,

  PushNewName,

  ChangeSuperClass,
  ChangeMethodTable,
  ChangeMethodLiteral,
  ChangeStatics,
  CommitChanges,
  DiscardChange,

  UncaughtException,

  MapLookup,
  ObjectId,

  PopInteger,
  Integer
}
