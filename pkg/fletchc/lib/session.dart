// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch.session;

import 'dart:core' hide StackTrace;
import 'dart:async';
import 'dart:convert';
import 'dart:io' hide exit;

import 'dart:typed_data' show
    ByteData,
    Uint8List;

import 'commands.dart';
import 'fletch_system.dart';

import 'incremental/fletchc_incremental.dart'
    show IncrementalCompiler;

import 'src/codegen_visitor.dart';
import 'src/debug_info.dart';
import 'debug_state.dart';

import 'src/shared_command_infrastructure.dart' show
    CommandTransformerBuilder,
    toUint8ListView;

part 'command_reader.dart';
part 'input_handler.dart';

/// Encapsulates a TCP connection to a running fletch-vm and provides a
/// [Command] based view on top of it.
class FletchVmSession {
  /// The outgoing connection to the fletch-vm.
  final StreamSink<List<int>> _outgoingSink;

  final Sink<List<int>> stdoutSink;
  final Sink<List<int>> stderrSink;

  /// The command reader producing a stream iterator for [Commands]s
  /// from the fletch-vm as well as a stream for stdout from the VM as
  /// well as stderr from the VM.
  final CommandReader _commandReader;

  /// Completes when the underlying TCP connection is terminated.
  final Future _done;

  bool _connectionIsDead = false;
  bool _drainedIncomingCommands = false;

  FletchVmSession(Socket vmSocket,
                  Sink<List<int>> stdoutSink,
                  Sink<List<int>> stderrSink)
      : _outgoingSink = vmSocket,
        this.stdoutSink = stdoutSink,
        this.stderrSink = stderrSink,
        _done = vmSocket.done,
        _commandReader = new CommandReader(vmSocket, stdoutSink, stderrSink) {
    _done.catchError((_, __) {}).then((_) {
      _connectionIsDead = true;
    });
  }

  void writeStdout(String s) {
    if (stdoutSink != null) stdoutSink.add(UTF8.encode(s));
  }

  void writeStdoutLine(String s) => writeStdout("$s\n");

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
        !await _commandReader.iterator.moveNext().catchError((error) {
          _drainedIncomingCommands = true;
          throw error;
        });

    if (_drainedIncomingCommands && force) {
      throw new StateError('Expected response from fletch-vm but got EOF.');
    }

    return _commandReader.iterator.current;
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
    var value = _commandReader.iterator.cancel();
    if (value != null) {
      await value.catchError((_) {});
    }
    _drainedIncomingCommands = true;
  }
}

/// Extends a bare [FletchVmSession] with debugging functionality.
class Session extends FletchVmSession {
  final IncrementalCompiler compiler;
  final Future processExitCodeFuture;

  DebugState debugState;
  FletchSystem fletchSystem;
  bool running = false;
  bool terminated = false;

  Session(Socket fletchVmSocket,
          this.compiler,
          Sink<List<int>> stdoutSink,
          Sink<List<int>> stderrSink,
          [this.processExitCodeFuture])
      : super(fletchVmSocket, stdoutSink, stderrSink) {
    // We send many small packages, so use no-delay.
    fletchVmSocket.setOption(SocketOption.TCP_NODELAY, true);
    // TODO(ajohnsen): Should only be initialized on debug()/testDebugger().
    debugState = new DebugState(this);
  }

  Future applyDelta(FletchDelta delta) async {
    Command response = await runCommands(delta.commands);
    fletchSystem = delta.system;
    return response;
  }

  Future disableVMStandardOutput() async {
    await runCommand(const DisableStandardOutput());
  }

  Future writeSnapshot(String snapshotPath) async {
    await runCommand(new WriteSnapshot(snapshotPath));
    await shutdown();
  }

  Future enableDebugger() async {
    await runCommand(const Debugging());
  }

  Future spawnProcess() async {
    await runCommand(const ProcessSpawnForMain());
  }

  Future run() async {
    await spawnProcess();
    await runCommand(const ProcessRun());
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

  Future<int> debug(Stream<String> inputLines) async {
    await enableDebugger();
    await spawnProcess();
    return await new InputHandler(this, inputLines, false).run();
  }

  Future stepToCompletion() async {
    await setBreakpoint(methodName: 'main', bytecodeIndex: 0);
    await debugRun();
    while (!terminated) {
      writeStdoutLine(debugState.topFrame.shortString());
      await step();
    }
  }

  Stream<String> debugCommandsFromString(String commandString) {
    return new Stream<String>.fromIterable(commandString.split(','));
  }

  Future testDebugger(String commands) async {
    await enableDebugger();
    await spawnProcess();
    if (commands.isEmpty) {
      await stepToCompletion();
    } else {
      InputHandler handler =
          new InputHandler(this, debugCommandsFromString(commands), true);
      await handler.run();
    }
  }

  Future terminateSession() async {
    await runCommand(const SessionEnd());
    if (processExitCodeFuture != null) await processExitCodeFuture;
    await shutdown();
    terminated = true;
  }

  Future<Command> handleProcessStop(Command response) async {
    debugState.reset();
    switch (response.code) {
      case CommandCode.UncaughtException:
      case CommandCode.ProcessCompileTimeError:
        running = false;
        break;
      case CommandCode.ProcessTerminated:
        running = false;
        writeStdoutLine('### process terminated');
        await terminateSession();
        break;
      default:
        assert(response.code == CommandCode.ProcessBreakpoint);
        ProcessBreakpoint command = response;
        var function = fletchSystem.lookupFunctionById(command.functionId);
        debugState.topFrame = new StackFrame(
            function, command.bytecodeIndex, compiler, debugState);
        break;
    }
    return response;
  }

  bool checkRunning() {
    if (!running) writeStdoutLine("### process not running");
    return running;
  }

  Future debugRun() async {
    assert(!running);
    running = true;
    await sendCommand(const ProcessRun());
    return handleProcessStop(await readNextCommand());
  }

  Future setBreakpointHelper(String name,
                             FletchFunction function,
                             int bytecodeIndex) async {
    ProcessSetBreakpoint response = await runCommands([
        new PushFromMap(MapId.methods, function.functionId),
        new ProcessSetBreakpoint(bytecodeIndex),
    ]);
    int breakpointId = response.value;
    var breakpoint = new Breakpoint(name, bytecodeIndex, breakpointId);
    debugState.breakpoints[breakpointId] = breakpoint;
    return breakpoint;
  }

  // TODO(ager): Let setBreakpoint return a stream instead and deal with
  // error situations such as bytecode indices that are out of bounds for
  // some of the methods with the given name.
  Future setBreakpoint({String methodName, int bytecodeIndex}) async {
    Iterable<FletchFunction> functions =
        fletchSystem.functionsWhere((f) => f.name == methodName);
    List<Breakpoint> breakpoints = [];
    for (FletchFunction function in functions) {
      breakpoints.add(
          await setBreakpointHelper(methodName, function, bytecodeIndex));
    }
    return breakpoints;
  }

  Future setFileBreakpointFromPosition(String name,
                                       String file,
                                       int position) async {
    if (position == null) {
      writeStdoutLine("### Failed setting breakpoint for $name");
      return null;
    }
    DebugInfo debugInfo = compiler.debugInfoForPosition(file, position);
    if (debugInfo == null) {
      writeStdoutLine("### Failed setting breakpoint for $name");
      return null;
    }
    SourceLocation location = debugInfo.locationForPosition(position);
    if (location == null) {
      writeStdoutLine("### Failed setting breakpoint for $name");
      return null;
    }
    FletchFunction function = debugInfo.function;
    int bytecodeIndex = location.bytecodeIndex;
    return setBreakpointHelper(function.name, function, bytecodeIndex);
  }

  Future setFileBreakpointFromPattern(String file,
                                      int line,
                                      String pattern) async {
    if (line < 1) {
      writeStdoutLine("### Invalid line number: $line");
      return null;
    }
    int position = compiler.positionInFileFromPattern(file, line - 1, pattern);
    await setFileBreakpointFromPosition('$file:$line:$pattern', file, position);
  }

  Future setFileBreakpoint(String file, int line, int column) async {
    if (line < 1) {
      writeStdoutLine("### Invalid line number: $line");
      return null;
    }
    if (column < 1) {
      writeStdoutLine("### Invalid column number: $column");
      return null;
    }
    int position = compiler.positionInFile(file, line - 1, column - 1);
    return setFileBreakpointFromPosition('$file:$line:$column', file, position);
  }

  Future doDeleteBreakpoint(int id) async {
    ProcessDeleteBreakpoint response =
        await runCommand(new ProcessDeleteBreakpoint(id));
    assert(response.id == id);
  }

  Future deleteBreakpoint(int id) async {
    if (!debugState.breakpoints.containsKey(id)) {
      writeStdoutLine("### invalid breakpoint id: $id");
      return null;
    }
    await doDeleteBreakpoint(id);
    writeStdoutLine("deleted breakpoint: ${debugState.breakpoints[id]}");
    debugState.breakpoints.remove(id);
  }

  void listBreakpoints() {
    if (debugState.breakpoints.isEmpty) {
      writeStdoutLine('No breakpoints.');
      return;
    }
    writeStdoutLine("Breakpoints:");
    for (var bp in debugState.breakpoints.values) {
      writeStdoutLine('$bp');
    }
  }

  Future stepTo(int functionId, int bcp) async {
    Command response = await runCommand(new ProcessStepTo(functionId, bcp));
    return await handleProcessStop(response);
  }

  Future step() async {
    Command response;
    SourceLocation previous = debugState.currentLocation;
    do {
      var bcp = debugState.topFrame.stepBytecodePointer(previous);
      if (bcp != -1) {
        response = await stepTo(debugState.topFrame.functionId, bcp);
      } else {
        response = await stepBytecode();
      }
    } while (running && debugState.atLocation(previous));
    return response;
  }

  Future stepOver() async {
    Command response;
    SourceLocation previous = debugState.currentLocation;
    do {
      response = await stepOverBytecode();
    } while (running && debugState.atLocation(previous));
    return response;
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
      assert(setBreakpoint.value != -1);
      Command response = await handleProcessStop(await readNextCommand());
      bool success =
          response is ProcessBreakpoint &&
          response.breakpointId == setBreakpoint.value;
      if (!success) {
        writeStdoutLine("### 'finish' cancelled because "
                        "another breakpoint was hit");
        await doDeleteBreakpoint(setBreakpoint.value);
        await backtrace();
        return null;
      }
    } while (!debugState.topFrame.isVisible);
    if (running && debugState.atLocation(return_location)) {
      await step();
    }
    await backtrace();
  }

  Future restart() async {
    if (debugState.currentStackTrace == null) {
      writeStdoutLine("### Cannot restart when nothing is executing.");
      return null;
    }
    if (debugState.numberOfStackFrames <= 1) {
      writeStdoutLine("### cannot restart entry frame");
      return null;
    }
    int frame = debugState.actualCurrentFrameNumber;
    await handleProcessStop(await runCommand(new ProcessRestartFrame(frame)));
    await backtrace();
  }

  Future stepBytecode() async {
    return await handleProcessStop(await runCommand(const ProcessStep()));
  }

  Future stepOverBytecode() async {
    if (!checkRunning()) return null;
    await sendCommand(const ProcessStepOver());
    ProcessSetBreakpoint setBreakpoint = await readNextCommand();
    Command response = await handleProcessStop(await readNextCommand());
    bool success =
        response is ProcessBreakpoint &&
        response.breakpointId == setBreakpoint.value;
    if (!success) {
      writeStdoutLine("### 'step over' cancelled because "
                      "another breakpoint was hit");
      if (setBreakpoint.value != -1) {
        await doDeleteBreakpoint(setBreakpoint.value);
      }
    }
  }

  Future cont() async {
    return handleProcessStop(await runCommand(const ProcessContinue()));
  }

  String list() {
    if (debugState.currentStackTrace == null) return null;
    return debugState.list();
  }

  String disasm() {
    if (debugState.currentStackTrace == null) return null;
    return debugState.disasm();
  }

  bool selectFrame(int frame) {
    if (debugState.currentStackTrace == null ||
        debugState.currentStackTrace.actualFrameNumber(frame) == -1) {
      return false;
    }
    debugState.currentFrame = frame;
    return true;
  }

  StackTrace stackTraceFromBacktraceResponse(
      ProcessBacktrace backtraceResponse) {
    int frames = backtraceResponse.frames;
    StackTrace stackTrace = new StackTrace(frames);
    for (int i = 0; i < frames; ++i) {
      int functionId = backtraceResponse.functionIds[i];
      FletchFunction function = fletchSystem.lookupFunctionById(functionId);
      if (function == null) {
        function = const FletchFunction.missing();
      }
      stackTrace.addFrame(
          compiler,
          new StackFrame(function,
                         backtraceResponse.bytecodeIndices[i],
                         compiler,
                         debugState));
    }
    return stackTrace;
  }

  Future getStackTrace() async {
    if (debugState.currentStackTrace == null) {
      ProcessBacktrace backtraceResponse =
          await runCommand(const ProcessBacktraceRequest());
      debugState.currentStackTrace =
          stackTraceFromBacktraceResponse(backtraceResponse);
    }
  }

  Future backtrace() async {
    // TODO(ager): We should refactor this so that we never
    // call backtrace from other debugger methods when the
    // session has been terminated.
    if (terminated) return null;
    await getStackTrace();
    String trace = debugState.formatStackTrace();
    writeStdout(trace);
  }

  Future backtraceForFiber(int fiber) async {
    ProcessBacktrace backtraceResponse =
        await runCommand(new ProcessFiberBacktraceRequest(fiber));
    StackTrace stackTrace = stackTraceFromBacktraceResponse(backtraceResponse);
    writeStdoutLine('fiber $fiber');
    String trace = stackTrace.format(0);
    writeStdout(trace);
  }

  Future fibers() async {
    if (!checkRunning()) return null;
    await runCommand(const NewMap(MapId.fibers));
    ProcessNumberOfStacks response =
        await runCommand(const ProcessAddFibersToMap());
    int numberOfFibers = response.value;
    for (int i = 0; i < numberOfFibers; i++) {
      writeStdoutLine('');
      await backtraceForFiber(i);
    }
    writeStdoutLine('');
    await runCommand(const DeleteMap(MapId.fibers));
  }

  String dartValueToString(DartValue value) {
    if (value is Instance) {
      Instance i = value;
      String className = fletchSystem.lookupClassById(i.classId).name;
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
    writeStdoutLine('$prefix${dartValueToString(response)}');
  }

  Future printLocalStructure(String name, LocalValue local) async {
    var frameNumber = debugState.actualCurrentFrameNumber;
    await sendCommand(new ProcessLocalStructure(frameNumber, local.slot));
    Command response = await readNextCommand();
    if (response is DartValue) {
      writeStdoutLine(dartValueToString(response));
    } else {
      assert(response is InstanceStructure);
      InstanceStructure structure = response;
      int classId = structure.classId;
      FletchClass klass = fletchSystem.lookupClassById(classId);
      writeStdoutLine("Instance of '${klass.name}' {");
      for (int i = 0; i < structure.fields; i++) {
        DartValue value = await readNextCommand();
        var fieldName = debugState.lookupFieldName(klass, i);
        writeStdoutLine('  $fieldName: ${dartValueToString(value)}');
      }
      writeStdoutLine('}');
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
      writeStdoutLine('### No such variable: $name');
      return null;
    }
    await printLocal(local);
  }

  Future printVariableStructure(String name) async {
    await getStackTrace();
    ScopeInfo info = debugState.currentScopeInfo;
    LocalValue local = info.lookup(name);
    if (local == null) {
      writeStdoutLine('### No such variable: $name');
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
}
