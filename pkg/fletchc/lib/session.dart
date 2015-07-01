// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch.session;

import 'dart:core' hide StackTrace;
import 'dart:async';
import 'dart:convert';
import 'dart:io' hide exit;
import 'dart:io' as io;
import 'dart:typed_data' show Uint8List;

import 'bytecodes.dart';
import 'commands.dart';
import 'fletch_system.dart';
import 'fletch_vm.dart';
import 'compiler.dart' show FletchCompiler;
import 'src/codegen_visitor.dart';
import 'src/debug_info.dart';
import 'debug_state.dart';

part 'command_reader.dart';
part 'input_handler.dart';

/// Encapsulates a TCP connection to a running fletch-vm and provides a
/// [Command] based view on top of it.
class FletchVmSession {
  /// The outgoing connection to the fletch-vm.
  final StreamSink<List<int>> _outgoingSink;

  /// The stream of [Command]s from the fletch-vm.
  final StreamIterator<Command> _incomingCommands;

  /// Completes when the underlying TCP connection is terminated.
  final Future _done;

  bool _connectionIsDead = false;
  bool _drainedIncomingCommands = false;

  FletchVmSession(Socket vmSocket)
      : _outgoingSink = vmSocket,
        _done = vmSocket.done,
        _incomingCommands = new CommandReader(vmSocket).iterator {
    _done.catchError((_, __) {}).then((_) {
      _connectionIsDead = true;
    });
  }

  /// Convenience around [runCommands] for running just a single command.
  Future<Command> runCommand(Command command) {
    return runCommands([command]);
  }

  /// Sends the given commands to a fletch-vm and reads response commands
  /// (if necessary).
  ///
  /// If all commands have been successfully applied and responses been awaited,
  /// this function will complete with the last received [Command] from the
  /// remote peer (or `null` if there was none).
  Future<Command> runCommands(List<Command> commands) async {
    if (commands.any((Command c) => c.numberOfResponsesExpected == null)) {
      throw new ArgumentError(
          'The runComands() method will read response commands and therefore '
          'needs to know how many to read. One of the given commands does'
          'not specify how many commands the response will have.');
    }

    Command lastResponse;
    for (Command command in commands) {
      await sendCommand(command);
      for (int i = 0; i < command.numberOfResponsesExpected; i++) {
        lastResponse = await readNextCommand();
      }
    }
    return lastResponse;
  }

  /// Sends all given [Command]s to a fletch-vm.
  Future sendCommands(List<Command> commands) async {
    for (var command in commands) {
      await sendCommand(command);
    }
  }

  /// Sends a [Command] to a fletch-vm.
  Future sendCommand(Command command) async {
    if (_connectionIsDead) {
      throw new StateError(
          'Trying to send command ${command} to fletch-vm, but '
          'the connection is already closed.');
    }
    command.addTo(_outgoingSink);
  }

  /// Will read the next [Command] the fletch-vm sends to us.
  Future<Command> readNextCommand({bool force: true}) async {
    if (_drainedIncomingCommands) {
      throw new StateError(
          'Tried to read a command from the fletch-vm, but the connection is '
          'already closed.');
    }

    _drainedIncomingCommands =
        !await _incomingCommands.moveNext().catchError((error) {
          _drainedIncomingCommands = true;
          throw error;
        });

    if (_drainedIncomingCommands && force) {
      throw new StateError('Expected response from fletch-vm but got EOF.');
    }

    return _incomingCommands.current;
  }

  /// Closes the connection to the fletch-vm and drains the remaining response
  /// commands.
  ///
  /// If [ignoreExtraCommands] is `false` it will throw a StateError if the
  /// fletch-vm sent any commands.
  Future shutdown({bool ignoreExtraCommands: false}) async {
    await _outgoingSink.close().catchError((_) {});

    while (!_drainedIncomingCommands) {
      Command response = await readNextCommand(force: false);
      if (!ignoreExtraCommands && response != null) {
        await kill();
        throw new StateError(
            "Got unexpected command from fletch-vm during shutdown "
            "($response)");
      }
    }

    return _done;
  }

  /// Closes the connection to the fletch-vm. It does not wait until it shuts
  /// down.
  ///
  /// This method will never complete with an exception.
  Future kill() async {
    _connectionIsDead = true;
    _drainedIncomingCommands = true;

    await _outgoingSink.close().catchError((_) {});
    var value = _incomingCommands.cancel();
    if (value != null) {
      await value.catchError((_) {});
    }
    _drainedIncomingCommands = true;
  }
}

/// Extends a bare [FletchVmSession] with debugging functionality.
class Session extends FletchVmSession {
  final FletchCompiler compiler;
  final StreamIterator<bool> vmStdoutSyncMessages;
  final StreamIterator<bool> vmStderrSyncMessages;
  final Future processExitCodeFuture;

  DebugState debugState;
  FletchSystem fletchSystem;
  bool running = false;

  Session(Socket fletchVmSocket,
          this.compiler,
          this.fletchSystem,
          [this.vmStdoutSyncMessages,
           this.vmStderrSyncMessages,
           this.processExitCodeFuture]) : super(fletchVmSocket) {
    // We send many small packages, so use no-delay.
    fletchVmSocket.setOption(SocketOption.TCP_NODELAY, true);
    // TODO(ajohnsen): Should only be initialized on debug()/testDebugger().
    debugState = new DebugState(this);
  }

  Future writeSnapshot(String snapshotPath) async {
    await runCommand(new WriteSnapshot(snapshotPath));
    await shutdown();
  }

  Future run() async {
    await sendCommands([const ProcessSpawnForMain(),
                        const ProcessRun()]);
    // NOTE: The [ProcessRun] command normally results in a
    // [ProcessTerminated] command. But if the compiler emitted a compile time
    // error, the fletch-vm will just halt()/exit() and we therefore get no
    // response.
    var command = await readNextCommand(force: false);
    if (command != null && command is! ProcessTerminated) {
      throw new Exception('Expected program to finish complete with '
                          '[ProcessTerminated] but got [$command]');
    }

    await shutdown();
  }

  Future debug() async {
    await sendCommands([
        const Debugging(true),
        const ProcessSpawnForMain(),
    ]);
    await new InputHandler(this).run();
  }

  Future stepToCompletion() async {
    await setBreakpoint(methodName: 'main', bytecodeIndex: 0);
    await doDebugRun();
    while (true) {
      print(debugState.topFrame.shortString());
      await doStep();
    }
  }

  Stream<String> debugCommandsFromString(String commandString) {
    return new Stream<String>.fromIterable(commandString.split(','));
  }

  Future testDebugger(String commands) async {
    await sendCommands([
        const Debugging(true),
        const ProcessSpawnForMain(),
    ]);
    if (commands.isEmpty) {
      await stepToCompletion();
    } else {
      await new InputHandler(this, debugCommandsFromString(commands)).run();
    }
  }

  Future nextOutputSynchronization() async {
    if (vmStderrSyncMessages != null) {
      assert(vmStdoutSyncMessages != null);
      bool gotSync =
          await vmStdoutSyncMessages.moveNext() &&
          await vmStderrSyncMessages.moveNext();
      assert(gotSync);
    }
    return null;
  }

  Future<int> handleProcessStop(Command response) async {
    await nextOutputSynchronization();
    debugState.reset();
    switch (response.code) {
      case CommandCode.UncaughtException:
        await backtrace();
        running = false;
        break;
      case CommandCode.ProcessTerminated:
        int exitCode = 0;
        print('### process terminated');
        await runCommand(const SessionEnd());
        if (processExitCodeFuture != null) {
          while (await vmStdoutSyncMessages.moveNext()) {}
          while (await vmStderrSyncMessages.moveNext()) {}
          exitCode = await processExitCodeFuture;
        }
        await shutdown();
        exit(exitCode);
        break;
      default:
        assert(response.code == CommandCode.ProcessBreakpoint);
        ProcessBreakpoint command = response;
        var function = fletchSystem.lookupFunctionById(command.methodId);
        debugState.topFrame = new StackFrame(
            function, command.bytecodeIndex, compiler, debugState);
        return command.breakpointId;
    }
    return -1;
  }

  bool checkRunning() {
    if (!running) print("### process not running");
    return running;
  }

  Future doDebugRun() async {
    if (running) {
      print("### already running");
      return null;
    }
    running = true;
    await sendCommand(const ProcessRun());
    await handleProcessStop(await readNextCommand());
  }

  Future debugRun() async {
    await doDebugRun();
    await backtrace();
  }

  Future setBreakpointHelper(String name,
                             FletchFunction function,
                             int bytecodeIndex) async {
    ProcessSetBreakpoint response = await runCommands([
        new PushFromMap(MapId.methods, function.methodId),
        new ProcessSetBreakpoint(bytecodeIndex),
    ]);
    int breakpointId = response.value;
    var breakpoint = new Breakpoint(name, bytecodeIndex, breakpointId);
    debugState.breakpoints[breakpointId] = breakpoint;
    print("breakpoint set: $breakpoint");
  }

  Future setBreakpoint({String methodName, int bytecodeIndex}) async {
    Iterable<FletchFunction> functions =
        fletchSystem.functionsWhere((f) => f.name == methodName);
    for (FletchFunction function in functions) {
      await setBreakpointHelper(methodName, function, bytecodeIndex);
    }
  }

  Future setFileBreakpointFromPosition(String name,
                                       String file,
                                       int position) async {
    if (position == null) {
      print("### Failed setting breakpoint for $name");
      return null;
    }
    DebugInfo debugInfo = compiler.debugInfoForPosition(file, position);
    if (debugInfo == null) {
      print("### Failed setting breakpoint for $name");
      return null;
    }
    SourceLocation location = debugInfo.locationForPosition(position);
    if (location == null) {
      print("### Failed setting breakpoint for $name");
      return null;
    }
    FletchFunction function = debugInfo.function;
    int bytecodeIndex = location.bytecodeIndex;
    await setBreakpointHelper(name, function, bytecodeIndex);
  }

  Future setFileBreakpointFromPattern(String file,
                                      int line,
                                      String pattern) async {
    if (line < 1) {
      print("### Invalid line number: $line");
      return null;
    }
    int position = compiler.positionInFileFromPattern(file, line - 1, pattern);
    await setFileBreakpointFromPosition('$file:$line:$pattern', file, position);
  }

  Future setFileBreakpoint(String file, int line, int column) async {
    if (line < 1) {
      print("### Invalid line number: $line");
      return null;
    }
    if (column < 1) {
      print("### Invalid column number: $column");
      return null;
    }
    int position = compiler.positionInFile(file, line - 1, column - 1);
    await setFileBreakpointFromPosition('$file:$line:$column', file, position);
  }

  Future doDeleteBreakpoint(int id) async {
    ProcessDeleteBreakpoint response =
        await runCommand(new ProcessDeleteBreakpoint(id));
    assert(response.id == id);
  }

  Future deleteBreakpoint(int id) async {
    if (!debugState.breakpoints.containsKey(id)) {
      print("### invalid breakpoint id: $id");
      return null;
    }
    await doDeleteBreakpoint(id);
    print("deleted breakpoint: ${debugState.breakpoints[id]}");
    debugState.breakpoints.remove(id);
  }

  void listBreakpoints() {
    if (debugState.breakpoints.isEmpty) {
      print('No breakpoints.');
      return;
    }
    print("Breakpoints:");
    for (var bp in debugState.breakpoints.values) {
      print(bp);
    }
  }

  Future stepTo(int methodId, int bcp) async {
    if (!checkRunning()) return null;
    Command response = await runCommand(new ProcessStepTo(methodId, bcp));
    await handleProcessStop(response);
  }

  Future doStep() async {
    SourceLocation previous = debugState.currentLocation;
    do {
      var bcp = debugState.topFrame.stepBytecodePointer(previous);
      if (bcp != -1) {
        await stepTo(debugState.topFrame.methodId, bcp);
      } else {
        await stepBytecode();
      }
    } while (debugState.atLocation(previous));
  }

  Future step() async {
    if (!checkRunning()) return null;
    await doStep();
    await backtrace();
  }

  Future stepOver() async {
    if (!checkRunning()) return null;
    SourceLocation previous = debugState.currentLocation;
    do {
      await stepOverBytecode();
    } while (debugState.atLocation(previous));
    await backtrace();
  }

  Future stepOut() async {
    if (!checkRunning()) return null;
    await getStackTrace();
    // If last frame, just continue.
    if (debugState.numberOfStackFrames <= 1) {
      await cont();
      return null;
    }
    // Get source location for call. We only want to break when the location
    // has changed from the call to something else.
    SourceLocation return_location = debugState.sourceLocationForFrame(1);
    do {
      if (debugState.numberOfStackFrames <= 1) {
        await cont();
        return null;
      }
      await sendCommand(const ProcessStepOut());
      ProcessSetBreakpoint setBreakpoint = await readNextCommand();
      Command response = await readNextCommand();
      assert(setBreakpoint.value != -1);
      int id = await handleProcessStop(response);
      if (id != setBreakpoint.value) {
        print("### 'finish' cancelled because another breakpoint was hit");
        await doDeleteBreakpoint(setBreakpoint.value);
        await backtrace();
        return null;
      }
    } while (!debugState.topFrame.isVisible);
    if (debugState.atLocation(return_location)) await doStep();
    await backtrace();
  }

  Future restart() async {
    if (!checkRunning()) return null;
    if (debugState.numberOfStackFrames <= 1) {
      print("### cannot restart entry frame");
      return null;
    }
    await handleProcessStop(
        await runCommand(new ProcessRestartFrame(debugState.currentFrame)));
    await backtrace();
  }

  Future stepBytecode() async {
    if (!checkRunning()) return null;
    await handleProcessStop(await runCommand(const ProcessStep()));
  }

  Future stepOverBytecode() async {
    if (!checkRunning()) return null;
    await sendCommand(const ProcessStepOver());
    ProcessSetBreakpoint setBreakpoint = await readNextCommand();
    Command response = await readNextCommand();
    int id = await handleProcessStop(response);
    if (id != setBreakpoint.value) {
      print("### 'step over' cancelled because another breakpoint was hit");
      if (setBreakpoint.value != -1) {
        await doDeleteBreakpoint(setBreakpoint.value);
      }
    }
  }

  Future cont() async {
    if (!checkRunning()) return null;
    await handleProcessStop(await runCommand(const ProcessContinue()));
    await backtrace();
  }

  void list() {
    if (debugState.currentStackTrace == null) {
      print("### no stack trace");
      return;
    }
    debugState.list();
  }

  void disasm() {
    if (debugState.currentStackTrace == null) {
      print("### no stack trace");
      return;
    }
    debugState.disasm();
  }

  void selectFrame(int frame) {
    if (debugState.currentStackTrace == null ||
        debugState.currentStackTrace.actualFrameNumber(frame) == -1) {
      print('### invalid frame number $frame');
      return;
    }
    debugState.currentFrame = frame;
  }

  Future getStackTrace() async {
    if (debugState.currentStackTrace == null) {
      ProcessBacktrace backtraceResponse =
          await runCommand(const ProcessBacktraceRequest());
      var frames = backtraceResponse.frames;
      StackTrace stackTrace = new StackTrace(frames);
      for (int i = 0; i < frames; ++i) {
        int methodId = backtraceResponse.methodIds[i];
        FletchFunction function = fletchSystem.lookupFunctionById(methodId);
        stackTrace.addFrame(
            compiler,
            new StackFrame(function,
                           backtraceResponse.bytecodeIndices[i],
                           compiler,
                           debugState));
      }
      debugState.currentStackTrace = stackTrace;
    }
  }

  Future backtrace() async {
    await getStackTrace();
    debugState.printStackTrace();
  }

  String dartValueToString(DartValue value) {
    if (value is Instance) {
      Instance i = value;
      String className = fletchSystem.lookupClass(i.classId).name;
      return "Instance of '$className'";
    } else {
      return value.dartToString();
    }
  }

  Future printLocal(LocalValue local, [String name]) async {
    var actualFrameNumber = debugState.actualCurrentFrameNumber;
    Command response = await runCommand(
        new ProcessLocal(actualFrameNumber, local.slot));
    assert(response is DartValue);
    String prefix = (name == null) ? '' : '$name: ';
    print('$prefix${dartValueToString(response)}');
  }

  Future printLocalStructure(String name, LocalValue local) async {
    var frameNumber = debugState.actualCurrentFrameNumber;
    await sendCommand(new ProcessLocalStructure(frameNumber, local.slot));
    Command response = await readNextCommand();
    if (response is DartValue) {
      print(dartValueToString(response));
    } else {
      assert(response is InstanceStructure);
      InstanceStructure structure = response;
      int classId = structure.classId;
      FletchClass klass = fletchSystem.lookupClass(classId);
      print("Instance of '${klass.name}' {");
      for (int i = 0; i < structure.fields; i++) {
        DartValue value = await readNextCommand();
        var fieldName = debugState.lookupFieldName(klass, i);
        print('  $fieldName: ${dartValueToString(value)}');
      }
      print('}');
    }
  }

  Future printAllVariables() async {
    await getStackTrace();
    ScopeInfo info = debugState.currentScopeInfo;
    for (ScopeInfo current = info;
         current != ScopeInfo.sentinel;
         current = current.previous) {
      await printLocal(current.local, current.name);
    }
  }

  Future printVariable(String name) async {
    await getStackTrace();
    ScopeInfo info = debugState.currentScopeInfo;
    LocalValue local = info.lookup(name);
    if (local == null) {
      print('### No such variable: $name');
      return null;
    }
    await printLocal(local);
  }

  Future printVariableStructure(String name) async {
    await getStackTrace();
    ScopeInfo info = debugState.currentScopeInfo;
    LocalValue local = info.lookup(name);
    if (local == null) {
      print('### No such variable: $name');
      return null;
    }
    await printLocalStructure(name, local);
  }

  Future toggleInternal() async {
    debugState.showInternalFrames = !debugState.showInternalFrames;
    if (debugState.currentStackTrace != null) {
      debugState.currentStackTrace.visibilityChanged();
      await backtrace();
    }
  }

  void exit(int exitCode) {
    io.exit(exitCode);
  }
}
