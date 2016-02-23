// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.vm_commands;

import 'dart:convert' show
    UTF8;

import 'dart:typed_data' show
    Int32List,
    Uint16List,
    Uint8List;

import 'bytecodes.dart' show
    Bytecode,
    MethodEnd;

import 'src/shared_command_infrastructure.dart' show
    CommandBuffer;

abstract class VmCommand {
  final VmCommandCode code;

  const VmCommand(this.code);

  factory VmCommand.fromBuffer(VmCommandCode code, Uint8List buffer) {
    switch (code) {
      case VmCommandCode.HandShakeResult:
        bool success = CommandBuffer.readBoolFromBuffer(buffer, 0);
        int versionLength = CommandBuffer.readInt32FromBuffer(buffer, 1);
        String version =
            CommandBuffer.readAsciiStringFromBuffer(buffer, 5, versionLength);
        return new HandShakeResult(success, version);
      case VmCommandCode.InstanceStructure:
        int classId = CommandBuffer.readInt64FromBuffer(buffer, 0);
        int fields = CommandBuffer.readInt32FromBuffer(buffer, 8);
        return new InstanceStructure(classId, fields);
      case VmCommandCode.Instance:
        int classId = CommandBuffer.readInt64FromBuffer(buffer, 0);
        return new Instance(classId);
      case VmCommandCode.Class:
        int classId = CommandBuffer.readInt64FromBuffer(buffer, 0);
        return new ClassValue(classId);
      case VmCommandCode.Integer:
        int value = CommandBuffer.readInt64FromBuffer(buffer, 0);
        return new Integer(value);
      case VmCommandCode.Double:
        return new Double(CommandBuffer.readDoubleFromBuffer(buffer, 0));
      case VmCommandCode.Boolean:
        return new Boolean(CommandBuffer.readBoolFromBuffer(buffer, 0));
      case VmCommandCode.Null:
        return const NullValue();
      case VmCommandCode.String:
        return new StringValue(
            CommandBuffer.readStringFromBuffer(buffer, 0, buffer.length));
      case VmCommandCode.StdoutData:
        return new StdoutData(buffer);
      case VmCommandCode.StderrData:
        return new StderrData(buffer);
      case VmCommandCode.ObjectId:
        int id = CommandBuffer.readInt64FromBuffer(buffer, 0);
        return new ObjectId(id);
      case VmCommandCode.ProcessBacktrace:
        int frames = CommandBuffer.readInt32FromBuffer(buffer, 0);
        ProcessBacktrace backtrace = new ProcessBacktrace(frames);
        for (int i = 0; i < frames; i++) {
          int offset = i * 16 + 4;
          int functionId = CommandBuffer.readInt64FromBuffer(buffer, offset);
          int bytecodeIndex =
              CommandBuffer.readInt64FromBuffer(buffer, offset + 8);
          backtrace.functionIds[i] = functionId;
          backtrace.bytecodeIndices[i] = bytecodeIndex;
        }
        return backtrace;
      case VmCommandCode.ProcessBreakpoint:
        int breakpointId = CommandBuffer.readInt32FromBuffer(buffer, 0);
        int functionId = CommandBuffer.readInt64FromBuffer(buffer, 4);
        int bytecodeIndex = CommandBuffer.readInt64FromBuffer(buffer, 12);
        return new ProcessBreakpoint(breakpointId, functionId, bytecodeIndex);
      case VmCommandCode.ProcessDeleteBreakpoint:
        int id = CommandBuffer.readInt32FromBuffer(buffer, 0);
        return new ProcessDeleteBreakpoint(id);
      case VmCommandCode.ProcessSetBreakpoint:
        int value = CommandBuffer.readInt32FromBuffer(buffer, 0);
        return new ProcessSetBreakpoint(value);
      case VmCommandCode.ProcessTerminated:
        return const ProcessTerminated();
      case VmCommandCode.ProcessCompileTimeError:
        return const ProcessCompileTimeError();
      case VmCommandCode.ProcessNumberOfStacks:
        int value = CommandBuffer.readInt32FromBuffer(buffer, 0);
        return new ProcessNumberOfStacks(value);
      case VmCommandCode.ProcessGetProcessIdsResult:
        int count = CommandBuffer.readInt32FromBuffer(buffer, 0);
        List<int> ids = new List(count);
        for (int i = 0; i < count; ++i) {
          ids[i] = CommandBuffer.readInt32FromBuffer(buffer, (i + 1) * 4);
        }
        return new ProcessGetProcessIdsResult(ids);
      case VmCommandCode.UncaughtException:
        return const UncaughtException();
      case VmCommandCode.CommitChangesResult:
        bool success = CommandBuffer.readBoolFromBuffer(buffer, 0);
        String message = CommandBuffer.readAsciiStringFromBuffer(
            buffer, 1, buffer.length - 1);
        return new CommitChangesResult(success, message);
      case VmCommandCode.WriteSnapshotResult:
        if ((buffer.offsetInBytes % 4) != 0) {
          buffer = new Uint8List.fromList(buffer);
        }

        int offset = 0;

        int readInt() {
          int number = CommandBuffer.readInt32FromBuffer(buffer, offset);
          offset += 4;
          return number;
        }

        Int32List readArray(int length) {
          Int32List classTable = new Int32List.view(
              buffer.buffer, buffer.offsetInBytes + offset, length);
          offset += 4 * length;
          return classTable;
        }

        int hashtag = readInt();

        int classEntries = readInt();
        Int32List classTable = readArray(classEntries);

        int functionEntries = readInt();
        Int32List functionTable = readArray(functionEntries);

        return new WriteSnapshotResult(classTable, functionTable, hashtag);
      default:
        throw 'Unhandled command in VmCommand.fromBuffer: $code';
    }
  }

  void addTo(Sink<List<int>> sink) {
    internalAddTo(sink, new CommandBuffer<VmCommandCode>());
  }

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer.sendOn(sink, code);
  }

  /// Indicates the number of responses we expect after sending a [VmCommand].
  /// If the number is unknown (e.g. one response determines whether more will
  /// come) this will be `null`.
  ///
  /// Some of the [VmCommand]s will instruct the dartino-vm to continue running
  /// the program. The response [VmCommand] can be one of
  ///    * ProcessBreakpoint
  ///    * ProcessTerminated
  ///    * ProcessCompileTimeError
  ///    * UncaughtException
  int get numberOfResponsesExpected => null;

  String valuesToString();

  String toString() => "$code(${valuesToString()})";
}

class HandShake extends VmCommand {
  final String value;

  const HandShake(this.value)
      : super(VmCommandCode.HandShake);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    List<int> payload = UTF8.encode(value);
    buffer
        ..addUint32(payload.length)
        ..addUint8List(payload)
        ..sendOn(sink, code);
  }

  // Expects a HandShakeResult reply.
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "$value";
}

class HandShakeResult extends VmCommand {
  final bool success;
  final String version;

  const HandShakeResult(this.success, this.version)
      : super(VmCommandCode.HandShakeResult);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    List<int> payload = UTF8.encode(version);
    buffer
        ..addUint8(success ? 1 : 0)
        ..addUint32(payload.length)
        ..addUint8List(payload)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$success, $version";
}

class Dup extends VmCommand {
  const Dup()
      : super(VmCommandCode.Dup);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class PushNewOneByteString extends VmCommand {
  final Uint8List value;

  const PushNewOneByteString(this.value)
      : super(VmCommandCode.PushNewOneByteString);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    List<int> payload = value;
    buffer
        ..addUint32(payload.length)
        ..addUint8List(payload)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "'${new String.fromCharCodes(value)}'";
}

class PushNewTwoByteString extends VmCommand {
  final Uint16List value;

  const PushNewTwoByteString(this.value)
      : super(VmCommandCode.PushNewTwoByteString);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    List<int> payload = value.buffer.asUint8List();
    buffer
        ..addUint32(payload.length)
        ..addUint8List(payload)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "'${new String.fromCharCodes(value)}'";
}

class PushNewInstance extends VmCommand {
  const PushNewInstance()
      : super(VmCommandCode.PushNewInstance);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class PushNewClass extends VmCommand {
  final int fields;

  const PushNewClass(this.fields)
      : super(VmCommandCode.PushNewClass);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(fields)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$fields";
}

class PushBuiltinClass extends VmCommand {
  final int name;
  final int fields;

  const PushBuiltinClass(this.name, this.fields)
      : super(VmCommandCode.PushBuiltinClass);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(name)
        ..addUint32(fields)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$name, $fields";
}

class PushConstantList extends VmCommand {
  final int entries;

  const PushConstantList(this.entries)
      : super(VmCommandCode.PushConstantList);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(entries)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$entries";
}

class PushConstantByteList extends VmCommand {
  final int entries;

  const PushConstantByteList(this.entries)
      : super(VmCommandCode.PushConstantByteList);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(entries)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$entries";
}

class PushConstantMap extends VmCommand {
  final int entries;

  const PushConstantMap(this.entries)
      : super(VmCommandCode.PushConstantMap);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(entries)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$entries";
}

class Generic extends VmCommand {
  final List<int> payload;

  const Generic(VmCommandCode code, this.payload)
      : super(code);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint8List(payload)
        ..sendOn(sink, code);
  }

  // We do not know who many commands to expect as a response.
  int get numberOfResponsesExpected => null;

  String valuesToString() => "$payload";

  String toString() => "Generic($code, ${valuesToString()})";
}

class NewMap extends VmCommand {
  final MapId map;

  const NewMap(this.map)
      : super(VmCommandCode.NewMap);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(map.index)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$map";
}

class DeleteMap extends VmCommand {
  final MapId map;

  const DeleteMap(this.map)
      : super(VmCommandCode.DeleteMap);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(map.index)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$map";
}

abstract class MapAccess extends VmCommand {
  final MapId map;
  final int index;

  const MapAccess(this.map, this.index, VmCommandCode code)
      : super(code);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(map.index)
        ..addUint64(index)
        ..sendOn(sink, code);
  }
}

class PopToMap extends MapAccess {
  const PopToMap(MapId map, int index)
      : super(map, index, VmCommandCode.PopToMap);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$map, $index";
}

class PushFromMap extends MapAccess {
  const PushFromMap(MapId map, int index)
      : super(map, index, VmCommandCode.PushFromMap);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$map, $index";
}

class RemoveFromMap extends MapAccess {
  const RemoveFromMap(MapId map, int index)
      : super(map, index, VmCommandCode.RemoveFromMap);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$map, $index";
}

class Drop extends VmCommand {
  final int value;

  const Drop(this.value)
      : super(VmCommandCode.Drop);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(value)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$value";
}

class PushNull extends VmCommand {
  const PushNull()
      : super(VmCommandCode.PushNull);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class PushBoolean extends VmCommand {
  final bool value;

  const PushBoolean(this.value)
      : super(VmCommandCode.PushBoolean);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint8(value ? 1 : 0)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => '$value';
}

class BytecodeSink implements Sink<List<int>> {
  List<int> bytes = <int>[];

  void add(List<int> data) {
    bytes.addAll(data);
  }

  void close() {
  }
}

class PushNewFunction extends VmCommand {
  final int arity;

  final int literals;

  final List<Bytecode> bytecodes;

  final List<int> catchRanges;

  const PushNewFunction(
      this.arity,
      this.literals,
      this.bytecodes,
      this.catchRanges)
      : super(VmCommandCode.PushNewFunction);

  List<int> computeBytes(List<Bytecode> bytecodes) {
    BytecodeSink sink = new BytecodeSink();
    for (Bytecode bytecode in bytecodes) {
      bytecode.addTo(sink);
    }
    return sink.bytes;
  }

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    List<int> bytes = computeBytes(bytecodes);
    int size = bytes.length;
    if (catchRanges.isNotEmpty) size += 4 + catchRanges.length * 4;
    buffer
        ..addUint32(arity)
        ..addUint32(literals)
        ..addUint32(size)
        ..addUint8List(bytes);
    if (catchRanges.isNotEmpty) {
      buffer.addUint32(catchRanges.length ~/ 3);
      catchRanges.forEach(buffer.addUint32);
    }
    buffer.sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$arity, $literals, $bytecodes, $catchRanges";
}

class PushNewInitializer extends VmCommand {
  const PushNewInitializer()
      : super(VmCommandCode.PushNewInitializer);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class ChangeStatics extends VmCommand {
  final int count;

  const ChangeStatics(this.count)
      : super(VmCommandCode.ChangeStatics);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(count)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$count";
}

class ChangeMethodLiteral extends VmCommand {
  final int index;

  const ChangeMethodLiteral(this.index)
      : super(VmCommandCode.ChangeMethodLiteral);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(index)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$index";
}

class ChangeMethodTable extends VmCommand {
  final int count;

  const ChangeMethodTable(this.count)
      : super(VmCommandCode.ChangeMethodTable);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(count)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$count";
}

class ChangeSuperClass extends VmCommand {
  const ChangeSuperClass()
      : super(VmCommandCode.ChangeSuperClass);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class ChangeSchemas extends VmCommand {
  final int count;
  final int delta;

  const ChangeSchemas(this.count, this.delta)
      : super(VmCommandCode.ChangeSchemas);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(count)
        ..addUint32(delta)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => '$count, $delta';
}

class PrepareForChanges extends VmCommand {
  const PrepareForChanges()
      : super(VmCommandCode.PrepareForChanges);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class CommitChanges extends VmCommand {
  final int count;

  const CommitChanges(this.count)
      : super(VmCommandCode.CommitChanges);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(count)
        ..sendOn(sink, code);
  }

  /// Peer will respond with [CommitChangesResult].
  int get numberOfResponsesExpected => 1;

  String valuesToString() => '$count';
}

class CommitChangesResult extends VmCommand {
  final bool successful;
  final String message;

  const CommitChangesResult(this.successful, this.message)
      : super(VmCommandCode.CommitChangesResult);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addBool(successful)
        ..addAsciiString(message)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => 'success: $successful, message: $message';
}

class UncaughtException extends VmCommand {
  const UncaughtException()
      : super(VmCommandCode.UncaughtException);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class MapLookup extends VmCommand {
  final MapId mapId;

  const MapLookup(this.mapId)
      : super(VmCommandCode.MapLookup);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(mapId.index)
        ..sendOn(sink, code);
  }

  /// Peer will respond with [ObjectId].
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "$mapId";
}

class ObjectId extends VmCommand {
  final int id;

  const ObjectId(this.id)
      : super(VmCommandCode.ObjectId);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint64(id)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$id";
}

class PushNewArray extends VmCommand {
  final int length;

  const PushNewArray(this.length)
      : super(VmCommandCode.PushNewArray);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(length)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => '$length';
}

class PushNewInteger extends VmCommand {
  final int value;

  const PushNewInteger(this.value)
      : super(VmCommandCode.PushNewInteger);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint64(value)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$value";
}

class PushNewBigInteger extends VmCommand {
  final bool negative;
  final List<int> parts;
  final MapId classMap;
  final int bigintClassId;
  final int uint32DigitsClassId;

  const PushNewBigInteger(this.negative,
                          this.parts,
                          this.classMap,
                          this.bigintClassId,
                          this.uint32DigitsClassId)
      : super(VmCommandCode.PushNewBigInteger);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint8(negative ? 1 : 0)
        ..addUint32(parts.length)
        ..addUint32(classMap.index)
        ..addUint64(bigintClassId)
        ..addUint64(uint32DigitsClassId);
    parts.forEach((part) => buffer.addUint32(part));
    buffer.sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() {
    return "$negative, $parts, $classMap, $bigintClassId, $uint32DigitsClassId";
  }
}

class PushNewDouble extends VmCommand {
  final double value;

  const PushNewDouble(this.value)
      : super(VmCommandCode.PushNewDouble);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addDouble(value)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$value";
}

class ProcessSpawnForMain extends VmCommand {
  final List<String> arguments;

  const ProcessSpawnForMain(this.arguments)
      : super(VmCommandCode.ProcessSpawnForMain);

  int get numberOfResponsesExpected => 0;

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer.addUint32(arguments.length);
    for (String argument in arguments) {
      List<int> payload = UTF8.encode(argument);
      buffer
        ..addUint32(payload.length)
        ..addUint8List(payload);
    }
    buffer.sendOn(sink, code);
  }

  String valuesToString() => "$arguments";
}

class ProcessDebugInterrupt extends VmCommand {
  const ProcessDebugInterrupt()
      : super(VmCommandCode.ProcessDebugInterrupt);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class ProcessRun extends VmCommand {
  const ProcessRun()
      : super(VmCommandCode.ProcessRun);

  /// It depends whether the connection is a "debugging session" or a
  /// "normal session". For a normal session, we do not expect to get any
  /// response, but for a debugging session we expect this to result in any of
  /// the responses noted further up at [Command.numberOfResponsesExpected].
  int get numberOfResponsesExpected => null;

  String valuesToString() => "";
}

class ProcessSetBreakpoint extends VmCommand {
  final int value;

  const ProcessSetBreakpoint(this.value)
      : super(VmCommandCode.ProcessSetBreakpoint);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(value)
        ..sendOn(sink, code);
  }

  /// Peer will respond with [ProcessSetBreakpoint]
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "$value";
}

class ProcessDeleteBreakpoint extends VmCommand {
  final int id;

  const ProcessDeleteBreakpoint(this.id)
      : super(VmCommandCode.ProcessDeleteBreakpoint);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(id)
        ..sendOn(sink, code);
  }

  /// Peer will respond with [ProcessDeleteBreakpoint]
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "$id";
}

class ProcessBacktrace extends VmCommand {
  final int frames;
  final List<int> functionIds;
  final List<int> bytecodeIndices;

  ProcessBacktrace(int frameCount)
      : frames = frameCount,
        functionIds = new List<int>(frameCount),
        bytecodeIndices = new List<int>(frameCount),
        super(VmCommandCode.ProcessBacktrace);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    throw new UnimplementedError();
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$frames, $functionIds, $bytecodeIndices";
}

class ProcessBacktraceRequest extends VmCommand {
  final int processId;

  // TODO(zerny): Make the process id non-optional and non-negative.
  const ProcessBacktraceRequest([this.processId = -1])
      : super(VmCommandCode.ProcessBacktraceRequest);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(processId + 1)
        ..sendOn(sink, code);
  }
  /// Peer will respond with [ProcessBacktrace]
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "$processId";
}

class ProcessFiberBacktraceRequest extends VmCommand {
  final int fiber;

  const ProcessFiberBacktraceRequest(this.fiber)
      : super(VmCommandCode.ProcessFiberBacktraceRequest);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint64(fiber)
        ..sendOn(sink, code);
  }

  /// Peer will respond with [ProcessBacktrace]
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "$fiber";
}

class ProcessUncaughtExceptionRequest extends VmCommand {
  const ProcessUncaughtExceptionRequest()
      : super(VmCommandCode.ProcessUncaughtExceptionRequest);

  /// Peer will respond with a [DartValue] or [InstanceStructure] and a number
  /// of [DartValue]s.
  ///
  /// The number of responses is not fixed.
  int get numberOfResponsesExpected => null;

  String valuesToString() => '';
}

class ProcessBreakpoint extends VmCommand {
  final int breakpointId;
  final int functionId;
  final int bytecodeIndex;

  const ProcessBreakpoint(
      this.breakpointId, this.functionId, this.bytecodeIndex)
      : super(VmCommandCode.ProcessBreakpoint);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    throw new UnimplementedError();
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$breakpointId, $functionId, $bytecodeIndex";
}

class ProcessLocal extends VmCommand {
  final int frame;
  final int slot;

  const ProcessLocal(this.frame, this.slot)
      : super(VmCommandCode.ProcessLocal);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(frame)
        ..addUint32(slot)
        ..sendOn(sink, code);
  }

  /// Peer will respond with a [DartValue].
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "$frame, $slot";
}

class ProcessLocalStructure extends VmCommand {
  final int frame;
  final int slot;

  const ProcessLocalStructure(this.frame, this.slot)
      : super(VmCommandCode.ProcessLocalStructure);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(frame)
        ..addUint32(slot)
        ..sendOn(sink, code);
  }

  /// Peer will respond with a [DartValue] or [InstanceStructure] and a number
  /// of [DartValue]s.
  ///
  /// The number of responses is not fixed.
  int get numberOfResponsesExpected => null;

  String valuesToString() => "$frame, $slot";
}

class ProcessRestartFrame extends VmCommand {
  final int frame;

  const ProcessRestartFrame(this.frame)
      : super(VmCommandCode.ProcessRestartFrame);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(frame)
        ..sendOn(sink, code);
  }

  /// Peer will continue program -- see [Command.numberOfResponsesExpected] for
  /// possible responses.
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "$frame";
}

class ProcessStep extends VmCommand {
  const ProcessStep()
      : super(VmCommandCode.ProcessStep);

  /// Peer will continue program -- see [Command.numberOfResponsesExpected] for
  /// possible responses.
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "";
}

class ProcessStepOver extends VmCommand {
  const ProcessStepOver()
      : super(VmCommandCode.ProcessStepOver);

  /// Peer will respond with a [ProcessSetBreakpoint] response and continues
  /// the program -- see [Command.numberOfResponsesExpected] for possible
  /// responses.
  int get numberOfResponsesExpected => 2;

  String valuesToString() => "";
}

class ProcessStepOut extends VmCommand {
  const ProcessStepOut()
      : super(VmCommandCode.ProcessStepOut);

  /// Peer will respond with a [ProcessSetBreakpoint] response and continues
  /// the program -- see [Command.numberOfResponsesExpected] for possible
  /// responses.
  int get numberOfResponsesExpected => 2;

  String valuesToString() => "";
}

class ProcessStepTo extends VmCommand {
  final int functionId;
  final int bcp;

  const ProcessStepTo(this.functionId, this.bcp)
      : super(VmCommandCode.ProcessStepTo);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint64(functionId)
        ..addUint32(bcp)
        ..sendOn(sink, code);
  }

  /// Peer will continue program -- see [Command.numberOfResponsesExpected] for
  /// possible responses.
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "$functionId, $bcp";
}

class ProcessContinue extends VmCommand {
  const ProcessContinue()
      : super(VmCommandCode.ProcessContinue);

  /// Peer will continue program -- see [Command.numberOfResponsesExpected] for
  /// possible responses.
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "";
}

class ProcessTerminated extends VmCommand {
  const ProcessTerminated()
      : super(VmCommandCode.ProcessTerminated);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class ProcessCompileTimeError extends VmCommand {
  const ProcessCompileTimeError()
      : super(VmCommandCode.ProcessCompileTimeError);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class ProcessAddFibersToMap extends VmCommand {
  const ProcessAddFibersToMap()
      : super(VmCommandCode.ProcessAddFibersToMap);

  /// The peer will respond with [ProcessNumberOfStacks].
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "";
}

class ProcessNumberOfStacks extends VmCommand {
  final int value;

  const ProcessNumberOfStacks(this.value)
      : super(VmCommandCode.ProcessNumberOfStacks);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$value";
}

class ProcessGetProcessIds extends VmCommand {
  const ProcessGetProcessIds()
      : super(VmCommandCode.ProcessGetProcessIds);

  /// The peer will respond with [ProcessGetProcessIdsResult].
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "";
}

class ProcessGetProcessIdsResult extends VmCommand {
  final List<int> ids;

  const ProcessGetProcessIdsResult(this.ids)
      : super(VmCommandCode.ProcessGetProcessIdsResult);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$ids";
}

class SessionEnd extends VmCommand {
  const SessionEnd()
      : super(VmCommandCode.SessionEnd);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class LiveEditing extends VmCommand {
  const LiveEditing()
      : super(VmCommandCode.LiveEditing);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(MapId.methods.index)
        ..addUint32(MapId.classes.index)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class Debugging extends VmCommand {
  const Debugging()
      : super(VmCommandCode.Debugging);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint32(MapId.fibers.index)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class DisableStandardOutput extends VmCommand {
  const DisableStandardOutput()
      : super(VmCommandCode.DisableStandardOutput);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class StdoutData extends VmCommand {
  final Uint8List value;

  const StdoutData(this.value)
      : super(VmCommandCode.StdoutData);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$value";
}

class StderrData extends VmCommand {
  final Uint8List value;

  const StderrData(this.value)
      : super(VmCommandCode.StderrData);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$value";
}

class WriteSnapshot extends VmCommand {
  final String value;

  const WriteSnapshot(this.value)
      : super(VmCommandCode.WriteSnapshot);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    List<int> payload = UTF8.encode(value).toList()..add(0);
    buffer
        ..addUint32(payload.length)
        ..addUint8List(payload)
        ..sendOn(sink, code);
  }

  // Response is a [WriteSnapshotResult] message.
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "'$value'";
}

// Contains two tables with information about function/class offsets in the
// program heap (when loaded from a snapshot).
//
// Both offset tables have the form:
//   [
//       [class/function id1, config{1,2,3,4}-offset]
//       [class/function id2, ...],
//       ...,
//   ]
// Each id/offset is represented as a 4 byte integer (which may be -1).
//
// All offsets are relative to the start of the program heap if a snapshot was
// loaded into memory.
//
// The offsets are different for our 4 different configurations:
//
//     config1: "64 bit double"
//     config2: "64 bit float"
//     config3: "32 bit double"
//     config4: "32 bit float"
//
class WriteSnapshotResult extends VmCommand {
  final Int32List classOffsetTable;
  final Int32List functionOffsetTable;
  final int hashtag;

  const WriteSnapshotResult(this.classOffsetTable,
                            this.functionOffsetTable,
                            this.hashtag)
      : super(VmCommandCode.WriteSnapshotResult);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    throw new UnimplementedError();
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$classOffsetTable, $functionOffsetTable";
}

class InstanceStructure extends VmCommand {
  final int classId;
  final int fields;

  const InstanceStructure(this.classId, this.fields)
      : super(VmCommandCode.InstanceStructure);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    throw new UnimplementedError();
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$classId, $fields";
}

abstract class DartValue extends VmCommand {
  const DartValue(VmCommandCode code)
      : super(code);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    throw new UnimplementedError();
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => dartToString();

  String dartToString();
}

class Instance extends DartValue {
  final int classId;

  const Instance(this.classId)
      : super(VmCommandCode.Instance);

  String valuesToString() => "$classId";

  String dartToString() => "Instance of $classId";
}

class ClassValue extends DartValue {
  final int classId;

  const ClassValue(this.classId)
      : super(VmCommandCode.Class);

  String valuesToString() => "$classId";

  String dartToString() => "Class with id $classId";
}

class Integer extends DartValue {
  final int value;

  const Integer(this.value)
      : super(VmCommandCode.Integer);

  void internalAddTo(
      Sink<List<int>> sink, CommandBuffer<VmCommandCode> buffer) {
    buffer
        ..addUint64(value)
        ..sendOn(sink, code);
  }

  String dartToString() => '$value';
}

class Double extends DartValue {
  final double value;

  const Double(this.value)
      : super(VmCommandCode.Double);

  String dartToString() => '$value';
}

class Boolean extends DartValue {
  final bool value;

  const Boolean(this.value)
      : super(VmCommandCode.Boolean);

  String dartToString() => '$value';
}

class NullValue extends DartValue {
  const NullValue()
      : super(VmCommandCode.Null);

  String valuesToString() => '';

  String dartToString() => 'null';
}

class StringValue extends DartValue {
  final String value;

  const StringValue(this.value)
      : super(VmCommandCode.String);

  String dartToString() => "'$value'";
}

class ConnectionError extends VmCommand {
  final error;

  final StackTrace trace;

  const ConnectionError(this.error, this.trace)
      : super(VmCommandCode.ConnectionError);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$error, $trace";
}

// Any change in [VmCommandCode] must also be done in [Opcode] in
// src/shared/connection.h.
enum VmCommandCode {
  // DO NOT MOVE! The handshake opcodes needs to be the first one as
  // it is used to verify the compiler and vm versions.
  HandShake,
  HandShakeResult,

  // Session opcodes.
  // TODO(ahe): Understand what "Session opcodes" mean and turn it into a
  // proper documentation comment (the comment was copied from
  // src/bridge/opcodes.dart).
  ConnectionError,
  CompilerError,
  SessionEnd,
  LiveEditing,
  Debugging,
  DisableStandardOutput,
  StdoutData,
  StderrData,

  ProcessDebugInterrupt,
  ProcessSpawnForMain,
  ProcessRun,
  ProcessSetBreakpoint,
  ProcessDeleteBreakpoint,
  ProcessStep,
  ProcessStepOver,
  ProcessStepOut,
  ProcessStepTo,
  ProcessContinue,
  ProcessBacktraceRequest,
  ProcessFiberBacktraceRequest,
  ProcessBacktrace,
  ProcessUncaughtExceptionRequest,
  ProcessBreakpoint,
  ProcessLocal,
  ProcessLocalStructure,
  ProcessRestartFrame,
  ProcessTerminated,
  ProcessCompileTimeError,
  ProcessAddFibersToMap,
  ProcessNumberOfStacks,

  ProcessGetProcessIds,
  ProcessGetProcessIdsResult,

  WriteSnapshot,
  WriteSnapshotResult,
  CollectGarbage,

  NewMap,
  DeleteMap,
  PushFromMap,
  PopToMap,
  RemoveFromMap,

  Dup,
  Drop,
  PushNull,
  PushBoolean,
  PushNewInteger,
  PushNewBigInteger,
  PushNewDouble,
  PushNewOneByteString,
  PushNewTwoByteString,
  PushNewInstance,
  PushNewArray,
  PushNewFunction,
  PushNewInitializer,
  PushNewClass,
  PushBuiltinClass,
  PushConstantList,
  PushConstantByteList,
  PushConstantMap,

  ChangeSuperClass,
  ChangeMethodTable,
  ChangeMethodLiteral,
  ChangeStatics,
  ChangeSchemas,

  PrepareForChanges,
  CommitChanges,
  CommitChangesResult,
  DiscardChange,

  UncaughtException,

  MapLookup,
  ObjectId,

  Integer,
  Boolean,
  Null,
  Double,
  String,
  Instance,
  Class,
  InstanceStructure
}

enum MapId {
  methods,
  classes,
  constants,
  fibers,
}
