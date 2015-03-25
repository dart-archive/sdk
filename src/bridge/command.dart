// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of session;

class Command {
  final Opcode opcode;
  final List buffer;

  Command(this.opcode, this.buffer);

  bool isPushNewName() { return opcode == Opcode.PushNewName; }

  void writeLengthTo(Socket socket) {
    var data = new List(4);
    var length = buffer.length;
    writeInt32ToBuffer(data, 0, length);
    socket.add(data);
  }

  void writeTo(Socket socket) {
    writeLengthTo(socket);
    socket.add([opcode.index]);
    socket.add(buffer);
  }

  String bufferAsString() {
    assert(isPushNewName());
    return new String.fromCharCodes(buffer);
  }

  int readInt64(int offset) => readInt64FromBuffer(buffer, offset);
  int readInt(int offset) => readInt32FromBuffer(buffer, offset);

  void writeInt64(int offset, int value) {
    writeInt64ToBuffer(buffer, offset, value);
  }

  void writeInt(int offset, int value) {
    writeInt32ToBuffer(buffer, offset, value);
  }

  List<int> readBytes(int offset, int length) =>
      buffer.sublist(offset, offset + length);
}

class PushFromMapCommand extends Command {
  PushFromMapCommand(int mapIndex, int id)
      : super(Opcode.PushFromMap, new List(12)) {
    writeInt(0, mapIndex);
    writeInt64(4, id);
  }
}

class MapLookupCommand extends Command {
  MapLookupCommand(int mapIndex) : super(Opcode.MapLookup, new List(4)) {
    writeInt(0, mapIndex);
  }
}

class EndCommand extends Command {
  EndCommand() : super(Opcode.SessionEnd, const []);
}

class ForceTerminationCommand extends Command {
  ForceTerminationCommand() : super(Opcode.ForceTermination, const []);
}

class DropCommand extends Command {
  DropCommand(int count) : super(Opcode.Drop, new List(4)) {
    writeInt(0, count);
  }
}

class PopIntegerCommand extends Command {
  PopIntegerCommand() : super(Opcode.PopInteger, const []);
}

class ProcessRunCommand extends Command {
  ProcessRunCommand() : super(Opcode.ProcessRun, const[]);
}

class ProcessSetBreakpointCommand extends Command {
  ProcessSetBreakpointCommand(int bytecodeIndex)
      : super(Opcode.ProcessSetBreakpoint, new List(4)) {
    writeInt(0, bytecodeIndex);
  }
}

class ProcessDeleteBreakpointCommand extends Command {
  ProcessDeleteBreakpointCommand(int id)
      : super(Opcode.ProcessDeleteBreakpoint, new List(4)) {
    writeInt(0, id);
  }
}

class ProcessStepCommand extends Command {
  ProcessStepCommand() : super(Opcode.ProcessStep, const[]);
}

class ProcessContinueCommand extends Command {
  ProcessContinueCommand() : super(Opcode.ProcessContinue, const[]);
}

class ProcessBacktraceCommand extends Command {
  ProcessBacktraceCommand() : super(Opcode.ProcessBacktrace, const[]);
}
