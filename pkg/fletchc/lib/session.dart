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

    try {
      if (await _incomingCommands.moveNext()) {
        return _incomingCommands.current;
      } else {
        _drainedIncomingCommands = true;

        if (!force) {
          return null;
        } else {
          return new Future.error(new StateError(
              'Expected response from fletch-vm but got EOF.'));
        }
      }
    } catch (e) {
      _drainedIncomingCommands = true;
      return new Future.error(new StateError(
          'Expected response from fletch-vm but got incoming socket error.'));
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

  DebugState debugState;
  FletchSystem fletchSystem;

  StackTrace currentStackTrace;
  int currentFrame = 0;
  SourceLocation currentLocation;
  bool running = false;

  Session(Socket fletchVmSocket,
          this.compiler,
          this.fletchSystem,
          [this.vmStdoutSyncMessages,
           this.vmStderrSyncMessages]) : super(fletchVmSocket) {
    // TODO(ajohnsen): Should only be initialized on debug()/testDebugger().
    debugState = new DebugState(this);
  }

  bool get currentLocationIsVisible {
    return currentStackTrace.stackFrames[0].isVisible;
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
      print(currentStackTrace.shortStringForFrame(0));
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
      bool gotStdoutSync =
          await vmStdoutSyncMessages.moveNext() &&
          await vmStderrSyncMessages.moveNext();
      assert(gotStdoutSync);
    }
    return null;
  }

  Future nextStopCommand() async {
    await nextOutputSynchronization();
    return readNextCommand();
  }

  Future<int> handleProcessStop(Command response) async {
    currentStackTrace = null;
    currentFrame = 0;
    switch (response.code) {
      case CommandCode.UncaughtException:
        await backtrace();
        running = false;
        break;
      case CommandCode.ProcessTerminated:
        print('### process terminated');
        await shutdown();
        exit(0);
        break;
      default:
        assert(response.code == CommandCode.ProcessBreakpoint);
        ProcessBreakpoint command = response;
        await getStackTrace();
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
                             int methodId,
                             int bytecodeIndex) async {
    ProcessSetBreakpoint response = await runCommands([
        new PushFromMap(MapId.methods, methodId),
        new ProcessSetBreakpoint(bytecodeIndex),
    ]);
    int breakpointId = response.value;
    var breakpoint = new Breakpoint(name, bytecodeIndex, breakpointId);
    debugState.breakpoints[breakpointId] = breakpoint;
    print("breakpoint set: $breakpoint");
  }

  Future setBreakpoint({String methodName, int bytecodeIndex}) async {
    Iterable<int> functionIds = compiler.lookupFunctionIdsByName(methodName);
    for (int id in functionIds) {
      await setBreakpointHelper(methodName, id, bytecodeIndex);
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
    int methodId = debugInfo.function.methodId;
    int bytecodeIndex = location.bytecodeIndex;
    await setBreakpointHelper(name, methodId, bytecodeIndex);
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
    Command response =
      await runCommand(new ProcessStepTo(MapId.methods, methodId, bcp));
    await handleProcessStop(response);
  }

  Future doStep() async {
    SourceLocation previous = currentLocation;
    do {
      var bcp = currentStackTrace.stepBytecodePointer(previous);
      if (bcp != -1) {
        await stepTo(currentStackTrace.methodId, bcp);
      } else {
        await stepBytecode();
      }
    } while (!currentLocationIsVisible ||
             currentLocation == null ||
             currentLocation.isSameSourceLevelLocationAs(previous) ||
             currentLocation.node == null);
  }

  Future step() async {
    if (!checkRunning()) return null;
    await doStep();
    await backtrace();
  }

  Future stepOver() async {
    if (!checkRunning()) return null;
    SourceLocation previous = currentLocation;
    do {
      await stepOverBytecode();
    } while (!currentLocationIsVisible ||
             currentLocation == null ||
             currentLocation == previous ||
             currentLocation.node == null);
    await backtrace();
  }

  Future stepOut() async {
    if (!checkRunning()) return null;
    // If last frame, just continue.
    if (currentStackTrace.stackFrames.length <= 1) {
      await cont();
      return null;
    }
    // Get source location for call. We only want to break when the location
    // has changed from the call to something else.
    SourceLocation return_location =
        currentStackTrace.stackFrames[1].sourceLocation();
    do {
      if (currentStackTrace.stackFrames.length <= 1) {
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
    } while (!currentLocationIsVisible);
    if (currentLocation == return_location) await doStep();
    await backtrace();
  }

  Future restart() async {
    if (!checkRunning()) return null;
    if (currentStackTrace.stackFrames.length <= 1) {
      print("### cannot restart entry frame");
      return null;
    }
    await handleProcessStop(
        await runCommand(new ProcessRestartFrame(currentFrame)));
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
    if (currentStackTrace == null) {
      print("### no stack trace");
      return;
    }
    currentStackTrace.list(currentFrame);
  }

  void disasm() {
    if (currentStackTrace == null) {
      print("### no stack trace");
      return;
    }
    currentStackTrace.disasm(currentFrame);
  }

  void selectFrame(int frame) {
    if (currentStackTrace == null ||
        currentStackTrace.actualFrameNumber(frame) == -1) {
      print('### invalid frame number $frame');
      return;
    }
    currentFrame = frame;
  }

  Future getStackTrace() async {
    if (currentStackTrace == null) {
      ProcessBacktrace backtraceResponse =
          await runCommand(const ProcessBacktraceRequest(MapId.methods));
      var frames = backtraceResponse.frames;
      currentStackTrace = new StackTrace(frames);
      // The bottom frames below main are internal implementation details
      // and should not be surfaced to debugger users by default.
      int mainMethodId = compiler.mainMethodId();
      bool belowMain = true;
      for (int i = 0; i < frames; ++i) {
        int methodId = backtraceResponse.methodIds[i];
        if (methodId == mainMethodId) belowMain = false;
        FletchFunction function = fletchSystem.functions[methodId];
        currentStackTrace.addFrame(
            compiler,
            new StackFrame(function,
                           backtraceResponse.bytecodeIndices[i],
                           compiler,
                           debugState,
                           belowMain));
      }
      currentLocation = currentStackTrace.sourceLocation();
    }
  }

  Future backtrace() async {
    await getStackTrace();
    currentStackTrace.write(currentFrame);
  }

  String dartValueToString(DartValue value) {
    if (value is Instance) {
      Instance i = value;
      String className = compiler.lookupClassName(i.classId);
      return "Instance of '$className'";
    } else {
      return value.dartToString();
    }
  }

  Future printLocal(LocalValue local, [String name]) async {
    var actualFrameNumber = currentStackTrace.actualFrameNumber(currentFrame);
    Command response = await runCommand(
        new ProcessLocal(MapId.classes, actualFrameNumber, local.slot));
    assert(response is DartValue);
    String prefix = (name == null) ? '' : '$name: ';
    print('$prefix${dartValueToString(response)}');
  }

  Future printLocalStructure(String name, LocalValue local) async {
    var frameNumber = currentStackTrace.actualFrameNumber(currentFrame);
    await sendCommand(
        new ProcessLocalStructure(MapId.classes, frameNumber, local.slot));
    Command response = await readNextCommand();
    if (response is DartValue) {
      print(dartValueToString(response));
    } else {
      assert(response is InstanceStructure);
      InstanceStructure structure = response;
      int classId = structure.classId;
      String className = compiler.lookupClassName(classId);
      print("Instance of '$className' {");
      for (int i = 0; i < structure.fields; i++) {
        DartValue value = await readNextCommand();
        var fieldName = compiler.lookupFieldName(classId, i);
        print('  $fieldName: ${dartValueToString(value)}');
      }
      print('}');
    }
  }

  Future printAllVariables() async {
    await getStackTrace();
    ScopeInfo info = currentStackTrace.scopeInfo(currentFrame);
    for (ScopeInfo current = info;
         current != ScopeInfo.sentinel;
         current = current.previous) {
      await printLocal(current.local, current.name);
    }
  }

  Future printVariable(String name) async {
    await getStackTrace();
    ScopeInfo info = currentStackTrace.scopeInfo(currentFrame);
    LocalValue local = info.lookup(name);
    if (local == null) {
      print('### No such variable: $name');
      return null;
    }
    await printLocal(local);
  }

  Future printVariableStructure(String name) async {
    await getStackTrace();
    ScopeInfo info = currentStackTrace.scopeInfo(currentFrame);
    LocalValue local = info.lookup(name);
    if (local == null) {
      print('### No such variable: $name');
      return null;
    }
    await printLocalStructure(name, local);
  }

  Future toggleInternal() async {
    debugState.showInternalFrames = !debugState.showInternalFrames;
    if (currentStackTrace != null) {
      currentStackTrace.visibilityChanged();
      await backtrace();
    }
  }

  void exit(int exitCode) {
    io.exit(exitCode);
  }
}
