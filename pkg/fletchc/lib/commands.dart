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

import 'bytecodes.dart' show
    Bytecode,
    MethodEnd;

class CommandBuffer {
  static const int headerSize = 5 /* 32 bit package length + 1 byte code */;

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
    // TODO(ahe): The C++ appears to often read 32-bit values into a signed
    // integer. Figure which is signed and which is unsigned.
    growBytes(4);
    view.setUint32(position, value, Endianness.LITTLE_ENDIAN);
    position += 4;
  }

  void addUint64(int value) {
    growBytes(8);
    view.setUint64(position, value, Endianness.LITTLE_ENDIAN);
    position += 8;
  }

  void addDouble(double value) {
    growBytes(8);
    view.setFloat64(position, value, Endianness.LITTLE_ENDIAN);
    position += 8;
  }

  void addUint8List(List<int> value) {
    growBytes(value.length);
    list.setRange(position, position + value.length, value);
    position += value.length;
  }

  void sendOn(StreamSink<List<int>> sink, CommandCode code) {
    view.setUint32(0, position - headerSize, Endianness.LITTLE_ENDIAN);
    view.setUint8(4, code.index);
    sink.add(list.sublist(0, position));
    position = headerSize;
  }
}

class Command {
  final CommandCode code;

  static final _buffer = new CommandBuffer();

  const Command(this.code);

  /// Shared command buffer. Not safe to use in asynchronous operations.
  CommandBuffer get buffer => _buffer;

  void addTo(StreamSink<List<int>> sink) {
    buffer.sendOn(sink, code);
  }
}

class Dup extends Command {
  const Dup()
      : super(CommandCode.Dup);
}

class PushNewString extends Command {
  final String value;

  const PushNewString(this.value)
      : super(CommandCode.PushNewString);

  void addTo(StreamSink<List<int>> sink) {
    List<int> payload = UTF8.encode(value);
    buffer
        ..addUint32(payload.length)
        ..addUint8List(payload)
        ..sendOn(sink, code);
  }
}

class PushNewInstance extends Command {
  const PushNewInstance()
      : super(CommandCode.PushNewInstance);
}

class PushNewClass extends Command {
  final int fields;

  const PushNewClass(this.fields)
      : super(CommandCode.PushNewClass);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(fields)
        ..sendOn(sink, code);
  }
}

class PushBuiltinClass extends Command {
  final int name;
  final int fields;

  const PushBuiltinClass(this.name, this.fields)
      : super(CommandCode.PushBuiltinClass);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(name)
        ..addUint32(fields)
        ..sendOn(sink, code);
  }
}

class PushConstantList extends Command {
  final int entries;

  const PushConstantList(this.entries)
      : super(CommandCode.PushConstantList);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(entries)
        ..sendOn(sink, code);
  }
}

class Generic extends Command {
  final List<int> payload;

  const Generic(CommandCode code, this.payload)
      : super(code);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint8List(payload)
        ..sendOn(sink, code);
  }
}

class NewMap extends Command {
  final MapId map;

  const NewMap(this.map)
      : super(CommandCode.NewMap);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(map.index)
        ..sendOn(sink, code);
  }
}

abstract class MapAccess extends Command {
  final MapId map;
  final int index;

  const MapAccess(this.map, this.index, CommandCode code)
      : super(code);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(map.index)
        ..addUint64(index)
        ..sendOn(sink, code);
  }
}

class PopToMap extends MapAccess {
  const PopToMap(MapId map, int index)
      : super(map, index, CommandCode.PopToMap);
}

class PushFromMap extends MapAccess {
  const PushFromMap(MapId map, int index)
      : super(map, index, CommandCode.PushFromMap);
}

class PushNull extends Command {
  const PushNull()
      : super(CommandCode.PushNull);
}

class PushBoolean extends Command {
  final bool value;

  const PushBoolean(this.value)
      : super(CommandCode.PushBoolean);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint8(value ? 1 : 0)
        ..sendOn(sink, code);
  }
}

class BytecodeSink implements Sink<List<int>> {
  List<int> bytes = <int>[];

  void add(List<int> data) {
    bytes.addAll(data);
  }

  void close() {
  }
}

class PushNewFunction extends Command {
  final int arity;

  final int literals;

  final List<Bytecode> bytecodes;

  final List<int> catchRanges;

  const PushNewFunction(
      this.arity,
      this.literals,
      this.bytecodes,
      this.catchRanges)
      : super(CommandCode.PushNewFunction);

  List<int> computeBytes(List<Bytecode> bytecodes) {
    BytecodeSink sink = new BytecodeSink();
    for (Bytecode bytecode in bytecodes) {
      bytecode.addTo(sink);
    }
    return sink.bytes;
  }

  void addTo(StreamSink<List<int>> sink) {
    List<int> bytes = computeBytes(bytecodes);
    int size = bytes.length + 4 + catchRanges.length * 4;
    buffer
        ..addUint32(arity)
        ..addUint32(literals)
        ..addUint32(size)
        ..addUint8List(bytes)
        ..addUint32(catchRanges.length ~/ 2);
    catchRanges.forEach(buffer.addUint32);
    buffer.sendOn(sink, code);
  }
}

class ChangeStatics extends Command {
  final int count;

  const ChangeStatics(this.count)
      : super(CommandCode.ChangeStatics);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(count)
        ..sendOn(sink, code);
  }
}

class ChangeMethodLiteral extends Command {
  final int index;

  const ChangeMethodLiteral(this.index)
      : super(CommandCode.ChangeMethodLiteral);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(index)
        ..sendOn(sink, code);
  }
}

class ChangeMethodTable extends Command {
  final int count;

  const ChangeMethodTable(this.count)
      : super(CommandCode.ChangeMethodTable);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(count)
        ..sendOn(sink, code);
  }
}

class ChangeSuperClass extends Command {
  const ChangeSuperClass()
      : super(CommandCode.ChangeSuperClass);
}

class CommitChanges extends Command {
  final int count;

  const CommitChanges(this.count)
      : super(CommandCode.CommitChanges);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(count)
        ..sendOn(sink, code);
  }
}

class PushNewInteger extends Command {
  final int value;

  const PushNewInteger(this.value)
      : super(CommandCode.PushNewInteger);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint64(value)
        ..sendOn(sink, code);
  }
}

class PushNewDouble extends Command {
  final double value;

  const PushNewDouble(this.value)
      : super(CommandCode.PushNewDouble);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addDouble(value)
        ..sendOn(sink, code);
  }
}

class ProcessSpawnForMain extends Command {
  const ProcessSpawnForMain()
      : super(CommandCode.ProcessSpawnForMain);
}

class ProcessRun extends Command {
  const ProcessRun()
      : super(CommandCode.ProcessRun);
}

class SessionEnd extends Command {
  const SessionEnd()
      : super(CommandCode.SessionEnd);
}

enum CommandCode {
  // Session opcodes.
  // TODO(ahe): Understand what "Session opcodes" mean and turn it into a
  // proper documentation comment (the comment was copied from
  // src/bridge/opcodes.dart).
  ConnectionError,
  CompilerError,
  SessionEnd,
  ForceTermination,

  ProcessSpawnForMain,
  ProcessRun,
  ProcessSetBreakpoint,
  ProcessStep,
  ProcessContinue,
  ProcessBacktrace,
  ProcessBreakpoint,
  ProcessTerminate,
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
