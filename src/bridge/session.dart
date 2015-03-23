// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library session;

import 'dart:async';
import 'dart:io';

part 'bytecodes.dart';
part 'command.dart';
part 'command_reader.dart';
part 'opcodes.dart';
part 'program_model.dart';
part 'stack_trace.dart';
part 'utils.dart';

// To make it easy to bootstrap a new bytecode compiler, we allow running
// with a super small library implementation.
const SIMPLE_SYSTEM = const bool.fromEnvironment("simple-system");

class SessionStack {
  final List _stack = new List();

  void push(value) { _stack.add(value); }
  Object top() => _stack.last;
  Object pop() => _stack.removeLast();
  void drop(int n) => _stack.removeRange(_stack.length - n, _stack.length);
  bool get isEmpty => _stack.isEmpty;
}

class Session {
  final CommandReader _compilerCommands;
  final StreamIterator<Command> _userResponseVMCommands;
  final Stream<Command> _otherVMCommands;
  final ProgramModel _model = new ProgramModel();
  final SessionStack _stack = new SessionStack();
  final Socket _vmSocket;

  bool _classConstruction = false;

  Session._(this._vmSocket,
            this._compilerCommands,
            this._userResponseVMCommands,
            this._otherVMCommands) {
    _otherVMCommands.listen(processVMCommand);
  }

  static Future<Session> start(Socket compilerSocket, Socket vmSocket) async {
    var vmCommandReader = new CommandReader(vmSocket);
    var vmCommands = vmCommandReader.broadcastStream();
    var userResponseVMCommands = vmCommands
        .where((command) => command.opcode != Opcode.UncaughtException);
    var otherVMCommands = vmCommands
        .where((command) => command.opcode == Opcode.UncaughtException);
    Session session = new Session._(vmSocket,
                                    new CommandReader(compilerSocket),
                                    new StreamIterator(userResponseVMCommands),
                                    otherVMCommands);
    await session.processCompilerData();
    return session;
  }

  Future processCompilerData() async {
    await for (Command command in _compilerCommands.stream()) {
      processCompilerCommand(command);
    }
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

  processCompilerCommand(Command command) {
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
  }

  Future processVMCommand(Command command) async {
    switch (command.opcode) {
      case Opcode.UncaughtException:
        await backtrace();
        new ForceTerminationCommand().writeTo(_vmSocket);
        break;
      default:
        throw "Unknown non-user response VM opcode ${command.opcode}";
    }
  }

  Future nextUserResponseCommand() async {
    var hasNext = await _userResponseVMCommands.moveNext();
    assert(hasNext);
    return _userResponseVMCommands.current;
  }

  // TODO(ager): Add ack responses to more commands. At this point only
  // backtrace awaits the full reply.
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

  Future backtrace() async {
    new ProcessBacktraceCommand().writeTo(_vmSocket);
    var backtraceResponse = await nextUserResponseCommand();
    var frameCount = backtraceResponse.readInt(0);
    var stackTrace = new StackTrace(frameCount);
    for (int i = 0; i < frameCount; ++i) {
      var command = new MapLookupCommand(_model.methodMapId);
      command.writeTo(_vmSocket);
      command = new DropCommand(1);
      command.writeTo(_vmSocket);
      command = new PopIntegerCommand();
      command.writeTo(_vmSocket);
      var objectIdCommand = await nextUserResponseCommand();
      var stackTraceMethodId = objectIdCommand.readInt(0);
      var integerCommand = await nextUserResponseCommand();
      var bcp = integerCommand.readInt64(0);
      var methodName = _model.methodMap[stackTraceMethodId];
      stackTrace.addFrame(new StackFrame(methodName, bcp));
    }
    stackTrace.write(_model);
  }

  end() {
    new EndCommand().writeTo(_vmSocket);
  }
}
