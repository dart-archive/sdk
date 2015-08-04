// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.commands;

import 'dart:convert' show
    UTF8;

import 'dart:typed_data' show
    Uint16List,
    Uint8List;

import 'bytecodes.dart' show
    Bytecode,
    MethodEnd;

import 'src/shared_command_infrastructure.dart' show
    CommandBuffer;

abstract class Command {
  final CommandCode code;

  const Command(this.code);

  factory Command.fromBuffer(CommandCode code, Uint8List buffer) {
    switch (code) {
      case CommandCode.InstanceStructure:
        int classId = CommandBuffer.readInt64FromBuffer(buffer, 0);
        int fields = CommandBuffer.readInt32FromBuffer(buffer, 8);
        return new InstanceStructure(classId, fields);
      case CommandCode.Instance:
        int classId = CommandBuffer.readInt64FromBuffer(buffer, 0);
        return new Instance(classId);
      case CommandCode.Integer:
        int value = CommandBuffer.readInt64FromBuffer(buffer, 0);
        return new Integer(value);
      case CommandCode.Double:
        return new Double(CommandBuffer.readDoubleFromBuffer(buffer, 0));
      case CommandCode.Boolean:
        return new Boolean(CommandBuffer.readBoolFromBuffer(buffer, 0));
      case CommandCode.Null:
        return const NullValue();
      case CommandCode.String:
        return new StringValue(
            CommandBuffer.readStringFromBuffer(buffer, 0, buffer.length));
      case CommandCode.StdoutData:
        return new StdoutData(buffer);
      case CommandCode.StderrData:
        return new StderrData(buffer);
      case CommandCode.ObjectId:
        int id = CommandBuffer.readInt64FromBuffer(buffer, 0);
        return new ObjectId(id);
      case CommandCode.ProcessBacktrace:
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
      case CommandCode.ProcessBreakpoint:
        int breakpointId = CommandBuffer.readInt32FromBuffer(buffer, 0);
        int functionId = CommandBuffer.readInt64FromBuffer(buffer, 4);
        int bytecodeIndex = CommandBuffer.readInt64FromBuffer(buffer, 12);
        return new ProcessBreakpoint(breakpointId, functionId, bytecodeIndex);
      case CommandCode.ProcessDeleteBreakpoint:
        int id = CommandBuffer.readInt32FromBuffer(buffer, 0);
        return new ProcessDeleteBreakpoint(id);
      case CommandCode.ProcessSetBreakpoint:
        int value = CommandBuffer.readInt32FromBuffer(buffer, 0);
        return new ProcessSetBreakpoint(value);
      case CommandCode.ProcessTerminated:
        return const ProcessTerminated();
      case CommandCode.ProcessCompileTimeError:
        return const ProcessCompileTimeError();
      case CommandCode.ProcessNumberOfStacks:
        int value = CommandBuffer.readInt32FromBuffer(buffer, 0);
        return new ProcessNumberOfStacks(value);
      case CommandCode.UncaughtException:
        return const UncaughtException();
      case CommandCode.CommitChangesResult:
        bool success = CommandBuffer.readBoolFromBuffer(buffer, 0);
        String message = CommandBuffer.readAsciiStringFromBuffer(
            buffer, 1, buffer.length - 1);
        return new CommitChangesResult(success, message);
      default:
        throw 'Unhandled command in Command.fromBuffer: $code';
    }
  }

  void addTo(Sink<List<int>> sink) {
    internalAddTo(sink, new CommandBuffer<CommandCode>());
  }

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer.sendOn(sink, code);
  }

  /// Indicates the number of responses we expect after sending a [Command].
  /// If the number is unknown (e.g. one response determines whether more will
  /// come) this will be `null`.
  ///
  /// Some of the [Command]s will instruct the fletch-vm to continue running
  /// the program. The response [Command] can be one of
  ///    * ProcessBreakpoint
  ///    * ProcessTerminated
  ///    * ProcessCompileTimeError
  ///    * UncaughtException
  int get numberOfResponsesExpected => null;

  String valuesToString();

  String toString() => "$code(${valuesToString()})";
}

class Dup extends Command {
  const Dup()
      : super(CommandCode.Dup);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class PushNewString extends Command {
  final String value;

  const PushNewString(this.value)
      : super(CommandCode.PushNewString);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    List<int> payload = new Uint16List.fromList(value.codeUnits)
        .buffer.asUint8List();
    buffer
        ..addUint32(payload.length)
        ..addUint8List(payload)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "'$value'";
}

class PushNewInstance extends Command {
  const PushNewInstance()
      : super(CommandCode.PushNewInstance);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class PushNewClass extends Command {
  final int fields;

  const PushNewClass(this.fields)
      : super(CommandCode.PushNewClass);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(fields)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$fields";
}

class PushBuiltinClass extends Command {
  final int name;
  final int fields;

  const PushBuiltinClass(this.name, this.fields)
      : super(CommandCode.PushBuiltinClass);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(name)
        ..addUint32(fields)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$name, $fields";
}

class PushConstantList extends Command {
  final int entries;

  const PushConstantList(this.entries)
      : super(CommandCode.PushConstantList);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(entries)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$entries";
}

class PushConstantMap extends Command {
  final int entries;

  const PushConstantMap(this.entries)
      : super(CommandCode.PushConstantMap);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(entries)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$entries";
}

class Generic extends Command {
  final List<int> payload;

  const Generic(CommandCode code, this.payload)
      : super(code);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint8List(payload)
        ..sendOn(sink, code);
  }

  // We do not know who many commands to expect as a response.
  int get numberOfResponsesExpected => null;

  String valuesToString() => "$payload";

  String toString() => "Generic($code, ${valuesToString()})";
}

class NewMap extends Command {
  final MapId map;

  const NewMap(this.map)
      : super(CommandCode.NewMap);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(map.index)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$map";
}

class DeleteMap extends Command {
  final MapId map;

  const DeleteMap(this.map)
      : super(CommandCode.DeleteMap);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(map.index)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$map";
}

abstract class MapAccess extends Command {
  final MapId map;
  final int index;

  const MapAccess(this.map, this.index, CommandCode code)
      : super(code);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(map.index)
        ..addUint64(index)
        ..sendOn(sink, code);
  }
}

class PopToMap extends MapAccess {
  const PopToMap(MapId map, int index)
      : super(map, index, CommandCode.PopToMap);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$map, $index";
}

class PushFromMap extends MapAccess {
  const PushFromMap(MapId map, int index)
      : super(map, index, CommandCode.PushFromMap);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$map, $index";
}

class RemoveFromMap extends MapAccess {
  const RemoveFromMap(MapId map, int index)
      : super(map, index, CommandCode.RemoveFromMap);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$map, $index";
}

class Drop extends Command {
  final int value;

  const Drop(this.value)
      : super(CommandCode.Drop);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(value)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$value";
}

class PushNull extends Command {
  const PushNull()
      : super(CommandCode.PushNull);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class PushBoolean extends Command {
  final bool value;

  const PushBoolean(this.value)
      : super(CommandCode.PushBoolean);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
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

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
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

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$arity, $literals, $bytecodes, $catchRanges";
}

class PushNewInitializer extends Command {
  const PushNewInitializer()
      : super(CommandCode.PushNewInitializer);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class ChangeStatics extends Command {
  final int count;

  const ChangeStatics(this.count)
      : super(CommandCode.ChangeStatics);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(count)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$count";
}

class ChangeMethodLiteral extends Command {
  final int index;

  const ChangeMethodLiteral(this.index)
      : super(CommandCode.ChangeMethodLiteral);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(index)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$index";
}

class ChangeMethodTable extends Command {
  final int count;

  const ChangeMethodTable(this.count)
      : super(CommandCode.ChangeMethodTable);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(count)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$count";
}

class ChangeSuperClass extends Command {
  const ChangeSuperClass()
      : super(CommandCode.ChangeSuperClass);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class ChangeSchemas extends Command {
  final int count;
  final int delta;

  const ChangeSchemas(this.count, this.delta)
      : super(CommandCode.ChangeSchemas);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(count)
        ..addUint32(delta)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => '$count, $delta';
}

class PrepareForChanges extends Command {
  const PrepareForChanges()
      : super(CommandCode.PrepareForChanges);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class CommitChanges extends Command {
  final int count;

  const CommitChanges(this.count)
      : super(CommandCode.CommitChanges);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(count)
        ..sendOn(sink, code);
  }

  /// Peer will respond with [CommitChangesResult].
  int get numberOfResponsesExpected => 1;

  String valuesToString() => '$count';
}

class CommitChangesResult extends Command {
  final bool successful;
  final String message;

  const CommitChangesResult(this.successful, this.message)
      : super(CommandCode.CommitChangesResult);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    throw new UnimplementedError();
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => 'success: $successful, message: $message';
}

class UncaughtException extends Command {
  const UncaughtException()
      : super(CommandCode.UncaughtException);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class MapLookup extends Command {
  final MapId mapId;

  const MapLookup(this.mapId)
      : super(CommandCode.MapLookup);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(mapId.index)
        ..sendOn(sink, code);
  }

  /// Peer will respond with [ObjectId].
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "$mapId";
}

class ObjectId extends Command {
  final int id;

  const ObjectId(this.id)
      : super(CommandCode.ObjectId);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint64(id)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$id";
}

class PushNewArray extends Command {
  final int length;

  const PushNewArray(this.length)
      : super(CommandCode.PushNewArray);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(length)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => '$length';
}

class PushNewInteger extends Command {
  final int value;

  const PushNewInteger(this.value)
      : super(CommandCode.PushNewInteger);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint64(value)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$value";
}

class PushNewDouble extends Command {
  final double value;

  const PushNewDouble(this.value)
      : super(CommandCode.PushNewDouble);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addDouble(value)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$value";
}

class ProcessSpawnForMain extends Command {
  const ProcessSpawnForMain()
      : super(CommandCode.ProcessSpawnForMain);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class ProcessRun extends Command {
  const ProcessRun()
      : super(CommandCode.ProcessRun);

  /// It depends whether the connection is a "debugging session" or a
  /// "normal session". For a normal session, we do not expect to get any
  /// response, but for a debugging session we expect this to result in any of
  /// the responses noted further up at [Command.numberOfResponsesExpected].
  int get numberOfResponsesExpected => null;

  String valuesToString() => "";
}

class ProcessSetBreakpoint extends Command {
  final int value;

  const ProcessSetBreakpoint(this.value)
      : super(CommandCode.ProcessSetBreakpoint);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(value)
        ..sendOn(sink, code);
  }

  /// Peer will respond with [ProcessSetBreakpoint]
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "$value";
}

class ProcessDeleteBreakpoint extends Command {
  final int id;

  const ProcessDeleteBreakpoint(this.id)
      : super(CommandCode.ProcessDeleteBreakpoint);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(id)
        ..sendOn(sink, code);
  }

  /// Peer will respond with [ProcessDeleteBreakpoint]
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "$id";
}

class ProcessBacktrace extends Command {
  final int frames;
  final List<int> functionIds;
  final List<int> bytecodeIndices;

  ProcessBacktrace(int frameCount)
      : frames = frameCount,
        functionIds = new List<int>(frameCount),
        bytecodeIndices = new List<int>(frameCount),
        super(CommandCode.ProcessBacktrace);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    throw new UnimplementedError();
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$frames, $functionIds, $bytecodeIndices";
}

class ProcessBacktraceRequest extends Command {
  const ProcessBacktraceRequest()
      : super(CommandCode.ProcessBacktraceRequest);

  /// Peer will respond with [ProcessBacktrace]
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "";
}

class ProcessFiberBacktraceRequest extends Command {
  final int fiber;

  const ProcessFiberBacktraceRequest(this.fiber)
      : super(CommandCode.ProcessFiberBacktraceRequest);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint64(fiber)
        ..sendOn(sink, code);
  }

  /// Peer will respond with [ProcessBacktrace]
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "$fiber";
}

class ProcessBreakpoint extends Command {
  final int breakpointId;
  final int functionId;
  final int bytecodeIndex;

  const ProcessBreakpoint(this.breakpointId, this.functionId, this.bytecodeIndex)
      : super(CommandCode.ProcessBreakpoint);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    throw new UnimplementedError();
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$breakpointId, $functionId, $bytecodeIndex";
}

class ProcessLocal extends Command {
  final int frame;
  final int slot;

  const ProcessLocal(this.frame, this.slot)
      : super(CommandCode.ProcessLocal);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(frame)
        ..addUint32(slot)
        ..sendOn(sink, code);
  }

  /// Peer will respond with a [DartValue].
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "$frame, $slot";
}

class ProcessLocalStructure extends Command {
  final int frame;
  final int slot;

  const ProcessLocalStructure(this.frame, this.slot)
      : super(CommandCode.ProcessLocalStructure);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
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

class ProcessRestartFrame extends Command {
  final int frame;

  const ProcessRestartFrame(this.frame)
      : super(CommandCode.ProcessRestartFrame);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(frame)
        ..sendOn(sink, code);
  }

  /// Peer will continue program -- see [Command.numberOfResponsesExpected] for
  /// possible responses.
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "$frame";
}

class ProcessStep extends Command {
  const ProcessStep()
      : super(CommandCode.ProcessStep);

  /// Peer will continue program -- see [Command.numberOfResponsesExpected] for
  /// possible responses.
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "";
}

class ProcessStepOver extends Command {
  const ProcessStepOver()
      : super(CommandCode.ProcessStepOver);

  /// Peer will respond with a [ProcessSetBreakpoint] response and continues
  /// the program -- see [Command.numberOfResponsesExpected] for possible
  /// responses.
  int get numberOfResponsesExpected => 2;

  String valuesToString() => "";
}

class ProcessStepOut extends Command {
  const ProcessStepOut()
      : super(CommandCode.ProcessStepOut);

  /// Peer will respond with a [ProcessSetBreakpoint] response and continues
  /// the program -- see [Command.numberOfResponsesExpected] for possible
  /// responses.
  int get numberOfResponsesExpected => 2;

  String valuesToString() => "";
}

class ProcessStepTo extends Command {
  final int functionId;
  final int bcp;

  const ProcessStepTo(this.functionId, this.bcp)
      : super(CommandCode.ProcessStepTo);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
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

class ProcessContinue extends Command {
  const ProcessContinue()
      : super(CommandCode.ProcessContinue);

  /// Peer will continue program -- see [Command.numberOfResponsesExpected] for
  /// possible responses.
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "";
}

class ProcessTerminated extends Command {
  const ProcessTerminated()
      : super(CommandCode.ProcessTerminated);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class ProcessCompileTimeError extends Command {
  const ProcessCompileTimeError()
      : super(CommandCode.ProcessCompileTimeError);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class ProcessAddFibersToMap extends Command {
  const ProcessAddFibersToMap()
      : super(CommandCode.ProcessAddFibersToMap);

  /// The peer will respond with [ProcessNumberOfStacks].
  int get numberOfResponsesExpected => 1;

  String valuesToString() => "";
}

class ProcessNumberOfStacks extends Command {
  final int value;

  const ProcessNumberOfStacks(this.value)
      : super(CommandCode.ProcessNumberOfStacks);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$value";
}

class SessionEnd extends Command {
  const SessionEnd()
      : super(CommandCode.SessionEnd);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class Debugging extends Command {
  const Debugging()
      : super(CommandCode.Debugging);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint32(MapId.methods.index)
        ..addUint32(MapId.classes.index)
        ..addUint32(MapId.fibers.index)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "";
}

class StdoutData extends Command {
  final Uint8List value;

  const StdoutData(this.value)
      : super(CommandCode.StdoutData);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$value";
}

class StderrData extends Command {
  final Uint8List value;

  const StderrData(this.value)
      : super(CommandCode.StderrData);

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$value";
}

class WriteSnapshot extends Command {
  final String value;

  const WriteSnapshot(this.value)
      : super(CommandCode.WriteSnapshot);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    List<int> payload = UTF8.encode(value).toList()..add(0);
    buffer
        ..addUint32(payload.length)
        ..addUint8List(payload)
        ..sendOn(sink, code);
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "'$value'";
}

class InstanceStructure extends Command {
  final int classId;
  final int fields;

  const InstanceStructure(this.classId, this.fields)
      : super(CommandCode.InstanceStructure);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    throw new UnimplementedError();
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => "$classId, $fields";
}

abstract class DartValue extends Command {
  const DartValue(CommandCode code)
      : super(code);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    throw new UnimplementedError();
  }

  int get numberOfResponsesExpected => 0;

  String valuesToString() => dartToString();

  String dartToString();
}

class Instance extends DartValue {
  final int classId;

  const Instance(this.classId)
      : super(CommandCode.Instance);

  String valuesToString() => "$classId";

  String dartToString() => "Instance of $classId";
}

class Integer extends DartValue {
  final int value;

  const Integer(this.value)
      : super(CommandCode.Integer);

  void internalAddTo(Sink<List<int>> sink, CommandBuffer<CommandCode> buffer) {
    buffer
        ..addUint64(value)
        ..sendOn(sink, code);
  }

  String dartToString() => '$value';
}

class Double extends DartValue {
  final double value;

  const Double(this.value)
      : super(CommandCode.Double);

  String dartToString() => '$value';
}

class Boolean extends DartValue {
  final bool value;

  const Boolean(this.value)
      : super(CommandCode.Boolean);

  String dartToString() => '$value';
}

class NullValue extends DartValue {
  const NullValue()
      : super(CommandCode.Null);

  String valuesToString() => '';

  String dartToString() => 'null';
}

class StringValue extends DartValue {
  final String value;

  const StringValue(this.value)
      : super(CommandCode.String);

  String dartToString() => "'$value'";
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
  StdoutData,
  StderrData,

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
  ProcessBreakpoint,
  ProcessLocal,
  ProcessLocalStructure,
  ProcessRestartFrame,
  ProcessTerminated,
  ProcessCompileTimeError,
  ProcessAddFibersToMap,
  ProcessNumberOfStacks,
  WriteSnapshot,
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
  InstanceStructure
}

enum MapId {
  methods,
  classes,
  constants,
  fibers,
}
