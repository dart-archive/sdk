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

class CommandBuffer {
  static const int headerSize = 5 /* 32 bit package length + 1 byte opcode */;

  int position = headerSize;

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

  void sendOn(StreamSink<List<int>> sink, Opcode opcode) {
    view.setUint32(0, position - headerSize, Endianness.LITTLE_ENDIAN);
    view.setUint8(4, opcode.index);
    sink.add(list.sublist(0, position));
    position = headerSize;
  }
}

class Command {
  final Opcode opcode;

  static final _buffer = new CommandBuffer();

  const Command(this.opcode);

  /// Shared command buffer. Not safe to use in asynchronous operations.
  CommandBuffer get buffer => _buffer;

  void addTo(StreamSink<List<int>> sink) {
    buffer.sendOn(sink, opcode);
  }
}

class PushNewString extends Command {
  final String value;

  const PushNewString(this.value)
      : super(Opcode.PushNewString);

  void addTo(StreamSink<List<int>> sink) {
    List<int> payload = UTF8.encode(value);
    buffer
        ..addUint32(payload.length)
        ..addUint8List(payload)
        ..sendOn(sink, opcode);
  }
}

class Generic extends Command {
  final List<int> payload;

  const Generic(Opcode opcode, this.payload)
      : super(opcode);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint8List(payload)
        ..sendOn(sink, opcode);
  }
}

class NewMap extends Command {
  final MapId map;

  const NewMap(this.map)
      : super(Opcode.NewMap);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(map.index)
        ..sendOn(sink, opcode);
  }
}

abstract class MapAccess extends Command {
  final MapId map;
  final int index;

  const MapAccess(this.map, this.index, Opcode opcode)
      : super(opcode);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(map.index)
        ..addUint64(index)
        ..sendOn(sink, opcode);
  }
}

class PopToMap extends MapAccess {
  const PopToMap(MapId map, int index)
      : super(map, index, Opcode.PopToMap);
}

class PushFromMap extends MapAccess {
  const PushFromMap(MapId map, int index)
      : super(map, index, Opcode.PushFromMap);
}

class PushNull extends Command {
  const PushNull()
      : super(Opcode.PushNull);
}

class PushBoolean extends Command {
  final bool value;

  const PushBoolean(this.value)
      : super(Opcode.PushBoolean);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint8(value ? 1 : 0)
        ..sendOn(sink, opcode);
  }
}

class PushNewFunction extends Command {
  final int arity;

  final int literals;

  final List<int> bytecodes;

  const PushNewFunction(this.arity, this.literals, this.bytecodes)
      : super(Opcode.PushNewFunction);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(arity)
        ..addUint32(literals)
        ..addUint32(bytecodes.length)
        ..addUint8List(bytecodes)
        ..sendOn(sink, opcode);
  }
}

class ChangeStatics extends Command {
  final int count;

  const ChangeStatics(this.count)
      : super(Opcode.ChangeStatics);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(count)
        ..sendOn(sink, opcode);
  }
}

class ChangeMethodLiteral extends Command {
  final int index;

  const ChangeMethodLiteral(this.index)
      : super(Opcode.ChangeMethodLiteral);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(index)
        ..sendOn(sink, opcode);
  }
}

class CommitChanges extends Command {
  final int count;

  const CommitChanges(this.count)
      : super(Opcode.CommitChanges);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(count)
        ..sendOn(sink, opcode);
  }
}

class PushNewInteger extends Command {
  final int value;

  const PushNewInteger(this.value)
      : super(Opcode.PushNewInteger);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint64(value)
        ..sendOn(sink, opcode);
  }
}

class RunMain extends Command {
  const RunMain()
      : super(Opcode.RunMain);
}

class SessionEnd extends Command {
  const SessionEnd()
      : super(Opcode.SessionEnd);
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

enum MapId {
  methods,
  classes,
  constants,
}
