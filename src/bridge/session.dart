// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library session;

import 'dart:io';

part 'bytecodes.dart';
part 'command.dart';
part 'opcodes.dart';
part 'program_model.dart';
part 'stack_trace.dart';
part 'utils.dart';

// To make it easy to bootstrap a new bytecode compiler, we allow running
// with a super small library implementation.
const SIMPLE_SYSTEM = const bool.fromEnvironment("simple-system");

class Chunk {
  List _data;
  Chunk next;

  Chunk(this._data);

  int get length => _data.length;
  int operator [](int index) => _data[index];
}

class SessionData {
  Chunk _first;
  Chunk _last;
  int _index;

  Chunk _currentChunk;
  int _currentIndex;

  SessionData() : _index = 0;

  void addData(List data) {
    if (_first == null) {
      _first = _last = new Chunk(data);
    } else {
      _last.next = new Chunk(data);
      _last = _last.next;
    }
  }

  int readByte() {
    if (_currentChunk == null) return null;
    if (_currentIndex < _currentChunk.length) {
      return _currentChunk[_currentIndex++];
    }
    _currentChunk = _currentChunk.next;
    _currentIndex = 0;
    return readByte();
  }

  int readInt() {
    var result = 0;
    for (int i = 0; i < 4; ++i) {
      var byte = readByte();
      if (byte == null) return null;
      result |= byte << (i * 8);
    }
    return result;
  }

  List readBytes(int size) {
    var result = new List(size);
    for (int i = 0; i < size; ++i) {
      int byte = readByte();
      if (byte == null) return null;
      result[i] = byte;
    }
    return result;
  }

  void advance() {
    _first = _currentChunk;
    if (_first == null) _last = _first;
    _index = _currentIndex;
  }

  void reset() {
    _currentChunk = _first;
    _currentIndex = _index;
  }

  Command readCommand() {
    reset();
    var length = readInt();
    if (length == null) return null;
    var opcode = readByte();
    if (opcode == null) return null;
    var buffer = readBytes(length);
    if (buffer == null) return null;
    advance();
    return new Command(Opcode.values[opcode], buffer);
  }
}

class SessionStack {
  final List _stack = new List();

  void push(value) { _stack.add(value); }
  Object top() => _stack.last;
  Object pop() => _stack.removeLast();
  void drop(int n) => _stack.removeRange(_stack.length - n, _stack.length);
  bool get isEmpty => _stack.isEmpty;
}

class Session {
  final SessionData _compilerData = new SessionData();
  final SessionData _vmData = new SessionData();
  final ProgramModel _model = new ProgramModel();
  final SessionStack _stack = new SessionStack();
  final Socket _compilerSocket;
  final Socket _vmSocket;

  StackTrace _stackTrace;
  int _stackTraceMethodId;
  bool _terminateAfterBacktrace = false;
  bool _classConstruction = false;

  Session(this._compilerSocket, this._vmSocket) {
    _vmSocket.listen(onVMData, onDone: _vmSocket.close);
    _compilerSocket.listen(onCompilerData, onDone: _compilerSocket.close);
  }

  onVMData(data) {
    _vmData.addData(data);
    processVMData();
  }

  onCompilerData(data) {
    _compilerData.addData(data);
    processCompilerData();
  }

  end() {
    Command endCommand = new EndCommand();
    endCommand.writeTo(_vmSocket);
  }

  void pushNewClass(int fieldCount) {
    var name = _stack.pop();
    var klass = new Class(name, fieldCount);
    // TODO(ager): The compiler generates a dup instruction that we
    // ignore; therefore we explicitly dup here.
    _stack.push(klass);
    _stack.push(klass);
    _classConstruction = true;
  }

  processCompilerData() {
    Command command = _compilerData.readCommand();
    while (command != null) {
      // Forward actual program structure to the VM.
      if (command.opcode != Opcode.PushNewName &&
          command.opcode != Opcode.ProcessRun) {
        command.writeTo(_vmSocket);
      }
      switch (command.opcode) {
        case Opcode.PushNewName:
          _stack.push(command.bufferAsString());
          break;
        case Opcode.PushNewFunction:
          var bytecodeSize = command.readInt(8);
          var bytecodes = command.readBytes(12, bytecodeSize);
          var name = _stack.pop();
          _stack.push(new Method(name, bytecodes));
          break;
        case Opcode.PushNewClass:
          pushNewClass(command.readInt(0));
          break;
        case Opcode.PushBuiltinClass:
          pushNewClass(command.readInt(4));
          break;
        case Opcode.PopToMap:
          if (!_stack.isEmpty) {
            int mapId = command.readInt(0);
            int id = command.readInt64(4);
            var map = _model.lookupMap(mapId);
            // TODO(ager): Deal with constants map as well.
            if (map != null) map[id] = _stack.pop();
          }
          break;
        case Opcode.NewMap:
          int id = command.readInt(0);
          if (!_stack.isEmpty) {
            switch (_stack.pop()) {
              case "classMap":
                _model.setClassMapId(id);
                break;
              case "methodMap":
                _model.setMethodMapId(id);
                break;
            }
          }
          break;
        case Opcode.PushNewInteger:
          // TODO(ager): deal with all opcodes that manipulate the stack
          // to not have this special case.
          if (_classConstruction) {
            _stack.push(command.readInt64(0));
          }
          break;
        case Opcode.PushFromMap:
          // TODO(ager): deal with all opcodes that manipulate the stack
          // to not have this special case.
          if (_classConstruction) {
            var mapId = command.readInt(0);
            var id = command.readInt64(4);
            _stack.push(_model.lookupMap(mapId)[id]);
          }
          break;
        case Opcode.ChangeMethodTable:
          var length = command.readInt(0);
          List methods = new List(length * 2);
          for (int i = 0; i < length * 2; ++i) {
            methods[i] = _stack.pop();
          }
          var klass = _stack.pop();
          for (int i = 0; i < length; ++i) {
            var method = methods[i * 2];
            var encodedSelector = methods[i * 2 + 1];
            klass.methods[encodedSelector] = method;
            var selector = new Selector(encodedSelector);
            _model.methodNameMap[selector.id] = method.name;
          }
          _classConstruction = false;
          break;
        case Opcode.ProcessRun:
          if (SIMPLE_SYSTEM) _model.dumpMethods();
          break;
        default:
          break;
      }
      command = _compilerData.readCommand();
    }
  }

  processVMData() {
    Command command = _vmData.readCommand();

    while (command != null) {
      switch (command.opcode) {
        case Opcode.UncaughtException:
          _terminateAfterBacktrace = true;
          new ProcessBacktraceCommand().writeTo(_vmSocket);
          break;
        case Opcode.ProcessBacktrace:
          var frameCount = command.readInt(0);
          _stackTrace = new StackTrace(frameCount);
          for (int i = 0; i < frameCount; ++i) {
            var command = new MapLookupCommand(_model.methodMapId);
            command.writeTo(_vmSocket);
            command = new DropCommand(1);
            command.writeTo(_vmSocket);
            command = new PopIntegerCommand();
            command.writeTo(_vmSocket);
          }
          break;
        case Opcode.ObjectId:
          _stackTraceMethodId = command.readInt(0);
          break;
        case Opcode.Integer:
          var bcp = command.readInt64(0);
          var methodName = _model.methodMap[_stackTraceMethodId];
          _stackTrace.addFrame(new StackFrame(methodName, bcp));
          if (_stackTrace.complete) {
            _stackTrace.write(_model);
            if (_terminateAfterBacktrace) {
              var command = new ForceTerminationCommand();
              command.writeTo(_vmSocket);
            }
          }
          break;
        default:
          throw "Unknown VM opcode ${command.opcode}";
      }
      command = _vmData.readCommand();
    }
  }

  // TODO(ager): introduce a command buffer and process the buffer only when
  // the previous command has been completely processed.
  run() {
    new ProcessRunCommand().writeTo(_vmSocket);
  }

  debug() {
    new ProcessDebugCommand().writeTo(_vmSocket);
  }

  step() {
    new ProcessStepCommand().writeTo(_vmSocket);
  }

  cont() {
    new ProcessContinueCommand().writeTo(_vmSocket);
  }

  backtrace() {
    new ProcessBacktraceCommand().writeTo(_vmSocket);
  }
}
