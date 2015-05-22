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

  static int readInt32FromBuffer(List<int> buffer, int offset) {
    return _readIntFromBuffer(buffer, offset, 4);
  }

  static int readInt64FromBuffer(List<int> buffer, int offset) {
    return _readIntFromBuffer(buffer, offset, 8);
  }

  static int _readIntFromBuffer(List<int> buffer, int offset, int sizeInBytes) {
    assert(buffer.length >= offset + sizeInBytes);
    int result = 0;
    for (int i = 0; i < sizeInBytes; ++i) {
      result |= buffer[i + offset] << (i * 8);
    }
    return result;
  }
}

class Command {
  final CommandCode code;

  static final _buffer = new CommandBuffer();

  const Command(this.code);

  factory Command.fromBuffer(CommandCode code, List<int> buffer) {
    switch (code) {
      case CommandCode.Instance:
        return const Instance();
      case CommandCode.Integer:
        int value = CommandBuffer.readInt64FromBuffer(buffer, 0);
        return new Integer(value);
      case CommandCode.ObjectId:
        int id = CommandBuffer.readInt32FromBuffer(buffer, 0);
        return new ObjectId(id);
      case CommandCode.ProcessBacktrace:
        int frames = CommandBuffer.readInt32FromBuffer(buffer, 0);
        ProcessBacktrace backtrace = new ProcessBacktrace(frames);
        for (int i = 0; i < frames; i++) {
          int offset = i * 12;
          int methodId = CommandBuffer.readInt32FromBuffer(buffer, offset + 4);
          int bytecodeIndex =
              CommandBuffer.readInt64FromBuffer(buffer, offset + 8);
          backtrace.methodIds[i] = methodId;
          backtrace.bytecodeIndices[i] = bytecodeIndex;
        }
        return backtrace;
      case CommandCode.ProcessBreakpoint:
        int breakpointId = CommandBuffer.readInt32FromBuffer(buffer, 0);
        return new ProcessBreakpoint(breakpointId);
      case CommandCode.ProcessDeleteBreakpoint:
        int id = CommandBuffer.readInt32FromBuffer(buffer, 0);
        return new ProcessDeleteBreakpoint(id);
      case CommandCode.ProcessSetBreakpoint:
        int value = CommandBuffer.readInt32FromBuffer(buffer, 0);
        return new ProcessSetBreakpoint(value);
      case CommandCode.ProcessTerminate:
        return const ProcessTerminate();
      case CommandCode.UncaughtException:
        return const UncaughtException();
      default:
        throw 'Unhandled command in Command.fromBuffer: $code';
    }
  }

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

  String toString() => "PushNewString('$value')";
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

class PushConstantMap extends Command {
  final int entries;

  const PushConstantMap(this.entries)
      : super(CommandCode.PushConstantMap);

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

  String toString() => "NewMap($map)";
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

  String toString() => "PopToMap($map, $index)";
}

class PushFromMap extends MapAccess {
  const PushFromMap(MapId map, int index)
      : super(map, index, CommandCode.PushFromMap);

  String toString() => "PushFromMap($map, $index)";
}

class Drop extends Command {
  final int value;

  const Drop(this.value)
      : super(CommandCode.Drop);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(value)
        ..sendOn(sink, code);
  }

  String toString() => "Drop($value)";
}

class PushNull extends Command {
  const PushNull()
      : super(CommandCode.PushNull);

  String toString() => "PushNull()";
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

  String toString() => 'PushBoolean($value)';
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

  String toString() {
    return "PushNewFunction($arity, $literals, $bytecodes, $catchRanges)";
  }
}

class PushNewInitializer extends Command {
  const PushNewInitializer()
      : super(CommandCode.PushNewInitializer);
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

  String toString() => "ChangeMethodLiteral($index)";
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

class ChangeSchemas extends Command {
  final int count;
  final int delta;

  const ChangeSchemas(this.count, this.delta)
      : super(CommandCode.ChangeSchemas);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(count)
        ..addUint32(delta)
        ..sendOn(sink, code);
  }

  String toString() => 'ChangeSchemas($count, $delta)';
}

class PrepareForChanges extends Command {
  const PrepareForChanges()
      : super(CommandCode.PrepareForChanges);

  String toString() => "PrepareForChanges()";
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

  String toString() => 'CommitChanges($count)';
}

class UncaughtException extends Command {
  const UncaughtException()
      : super(CommandCode.UncaughtException);
}

class MapLookup extends Command {
  final MapId mapId;

  const MapLookup(this.mapId)
      : super(CommandCode.MapLookup);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(mapId.index)
        ..sendOn(sink, code);
  }
}

class ObjectId extends Command {
  final int id;

  const ObjectId(this.id)
      : super(CommandCode.ObjectId);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint64(id)
        ..sendOn(sink, code);
  }
}

class PushNewArray extends Command {
  final int length;

  const PushNewArray(this.length)
      : super(CommandCode.PushNewArray);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(length)
        ..sendOn(sink, code);
  }

  String toString() => 'PushNewArray($length)';
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

  String toString() => "PushNewInteger($value)";
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

class ProcessSetBreakpoint extends Command {
  final int value;

  const ProcessSetBreakpoint(this.value)
      : super(CommandCode.ProcessSetBreakpoint);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(value)
        ..sendOn(sink, code);
  }
}

class ProcessDeleteBreakpoint extends Command {
  final int id;

  const ProcessDeleteBreakpoint(this.id)
      : super(CommandCode.ProcessDeleteBreakpoint);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(id)
        ..sendOn(sink, code);
  }
}

class ProcessBacktrace extends Command {
  final int frames;
  final List<int> methodIds;
  final List<int> bytecodeIndices;

  ProcessBacktrace(int frameCount)
      : frames = frameCount,
        methodIds = new List<int>(frameCount),
        bytecodeIndices = new List<int>(frameCount),
        super(CommandCode.ProcessBacktrace);
}

class ProcessBacktraceRequest extends Command {
  final MapId methodMap;

  const ProcessBacktraceRequest(this.methodMap)
      : super(CommandCode.ProcessBacktrace);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(methodMap.index)
        ..sendOn(sink, code);
  }

}

class ProcessBreakpoint extends Command {
  final int breakpointId;

  const ProcessBreakpoint(this.breakpointId)
      : super(CommandCode.ProcessBreakpoint);
}

class ProcessLocal extends Command {
  final int frame;
  final int slot;

  const ProcessLocal(this.frame, this.slot)
      : super(CommandCode.ProcessLocal);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(frame)
        ..addUint32(slot)
        ..sendOn(sink, code);
  }
}

class ProcessStep extends Command {
  const ProcessStep()
      : super(CommandCode.ProcessStep);
}

class ProcessStepOver extends Command {
  const ProcessStepOver()
      : super(CommandCode.ProcessStepOver);
}

class ProcessStepOut extends Command {
  const ProcessStepOut()
      : super(CommandCode.ProcessStepOut);
}

class ProcessStepTo extends Command {
  final MapId id;
  final int methodId;
  final int bcp;

  const ProcessStepTo(this.id, this.methodId, this.bcp)
      : super(CommandCode.ProcessStepTo);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint32(id.index)
        ..addUint64(methodId)
        ..addUint32(bcp)
        ..sendOn(sink, code);
  }
}

class ProcessContinue extends Command {
  const ProcessContinue()
      : super(CommandCode.ProcessContinue);
}

class ProcessTerminate extends Command {
  const ProcessTerminate()
      : super(CommandCode.ProcessTerminate);
}

class SessionEnd extends Command {
  const SessionEnd()
      : super(CommandCode.SessionEnd);
}

class Debugging extends Command {
  const Debugging()
      : super(CommandCode.Debugging);
}

class WriteSnapshot extends Command {
  final String value;

  const WriteSnapshot(this.value)
      : super(CommandCode.WriteSnapshot);

  void addTo(StreamSink<List<int>> sink) {
    List<int> payload = UTF8.encode(value).toList()..add(0);
    buffer
        ..addUint32(payload.length)
        ..addUint8List(payload)
        ..sendOn(sink, code);
  }
}

class PopInteger extends Command {
  const PopInteger()
      : super(CommandCode.PopInteger);
}

class Instance extends Command {
  const Instance()
      : super(CommandCode.Instance);
}

class Integer extends Command {
  final int value;

  const Integer(this.value)
    : super(CommandCode.Integer);

  void addTo(StreamSink<List<int>> sink) {
    buffer
        ..addUint64(value)
        ..sendOn(sink, code);
  }
}

enum CommandCode {
  // Session opcodes.
  // TODO(ahe): Understand what "Session opcodes" mean and turn it into a
  // proper documentation comment (the comment was copied from
  // src/bridge/opcodes.dart).
  ConnectionError,
  CompilerError,
  SessionEnd,
  Debugging,

  ProcessSpawnForMain,
  ProcessRun,
  ProcessSetBreakpoint,
  ProcessDeleteBreakpoint,
  ProcessStep,
  ProcessStepOver,
  ProcessStepOut,
  ProcessStepTo,
  ProcessContinue,
  ProcessBacktrace,
  ProcessBreakpoint,
  ProcessLocal,
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

  ChangeSuperClass,
  ChangeMethodTable,
  ChangeMethodLiteral,
  ChangeStatics,
  ChangeSchemas,

  PrepareForChanges,
  CommitChanges,
  DiscardChange,

  UncaughtException,

  MapLookup,
  ObjectId,

  PopInteger,
  Integer,
  Instance
}

enum MapId {
  methods,
  classes,
  constants,
}
