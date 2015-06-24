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

class Session {
  final Socket vmSocket;
  final FletchCompiler compiler;
  final StreamIterator<bool> vmStdoutSyncMessages;
  final StreamIterator<bool> vmStderrSyncMessages;

  DebugState debugState;
  FletchSystem fletchSystem;

  StreamIterator<Command> vmCommands;
  StackTrace currentStackTrace;
  int currentFrame = 0;
  SourceLocation currentLocation;
  bool running = false;

  Session(this.vmSocket,
          this.compiler,
          this.fletchSystem,
          [this.vmStdoutSyncMessages,
           this.vmStderrSyncMessages]) {
    // TODO(ajohnsen): Should only be initialized on debug()/testDebugger().
    debugState = new DebugState(this);
  }

  bool get currentLocationIsVisible {
    return currentStackTrace.stackFrames[0].isVisible;
  }

  void writeSnapshot(String snapshotPath) {
    new WriteSnapshot(snapshotPath).addTo(vmSocket);
    vmSocket.drain();
    quit();
  }

  void run() {
    const ProcessSpawnForMain().addTo(vmSocket);
    const ProcessRun().addTo(vmSocket);
    vmSocket.drain();
    quit();
  }

  Future debug() async {
    vmCommands = new CommandReader(vmSocket).iterator;
    const Debugging(true).addTo(vmSocket);
    const ProcessSpawnForMain().addTo(vmSocket);
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
    vmCommands = new CommandReader(vmSocket).iterator;
    const Debugging(true).addTo(vmSocket);
    const ProcessSpawnForMain().addTo(vmSocket);
    if (commands.isEmpty) {
      await stepToCompletion();
    } else {
      await new InputHandler(this, debugCommandsFromString(commands)).run();
    }
  }

  Future nextVmCommand() async {
    var hasNext = await vmCommands.moveNext();
    assert(hasNext);
    return vmCommands.current;
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
    return nextVmCommand();
  }

  Future<int> handleProcessStop() async {
    currentStackTrace = null;
    currentFrame = 0;
    Command response = await nextVmCommand();
    switch (response.code) {
      case CommandCode.UncaughtException:
        await backtrace();
        running = false;
        break;
      case CommandCode.ProcessTerminated:
        print('### process terminated');
        quit();
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
    const ProcessRun().addTo(vmSocket);
    await handleProcessStop();
  }

  Future debugRun() async {
    await doDebugRun();
    await backtrace();
  }

  Future setBreakpointHelper(String name,
                             int methodId,
                             int bytecodeIndex) async {
    new PushFromMap(MapId.methods, methodId).addTo(vmSocket);
    new ProcessSetBreakpoint(bytecodeIndex).addTo(vmSocket);
    ProcessSetBreakpoint response = await nextVmCommand();
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
    new ProcessDeleteBreakpoint(id).addTo(vmSocket);
    ProcessDeleteBreakpoint response = await nextVmCommand();
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
    new ProcessStepTo(MapId.methods, methodId, bcp).addTo(vmSocket);
    await handleProcessStop();
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
      const ProcessStepOut().addTo(vmSocket);
      ProcessSetBreakpoint response = await nextVmCommand();
      assert(response.value != -1);
      int id = await handleProcessStop();
      if (id != response.value) {
        print("### 'finish' cancelled because another breakpoint was hit");
        await doDeleteBreakpoint(response.value);
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
    new ProcessRestartFrame(currentFrame).addTo(vmSocket);
    await handleProcessStop();
    await backtrace();
  }

  Future stepBytecode() async {
    if (!checkRunning()) return null;
    const ProcessStep().addTo(vmSocket);
    await handleProcessStop();
  }

  Future stepOverBytecode() async {
    if (!checkRunning()) return null;
    const ProcessStepOver().addTo(vmSocket);
    ProcessSetBreakpoint response = await nextVmCommand();
    int id = await handleProcessStop();
    if (id != response.value) {
      print("### 'step over' cancelled because another breakpoint was hit");
      if (response.value != -1) await doDeleteBreakpoint(response.value);
    }
  }

  Future cont() async {
    if (!checkRunning()) return null;
    const ProcessContinue().addTo(vmSocket);
    await handleProcessStop();
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
      const ProcessBacktraceRequest(MapId.methods).addTo(vmSocket);
      ProcessBacktrace backtraceResponse = await nextVmCommand();
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
    new ProcessLocal(MapId.classes,
                     actualFrameNumber,
                     local.slot).addTo(vmSocket);
    Command response = await nextVmCommand();
    assert(response is DartValue);
    String prefix = (name == null) ? '' : '$name: ';
    print('$prefix${dartValueToString(response)}');
  }

  Future printLocalStructure(String name, LocalValue local) async {
    var actualFrameNumber = currentStackTrace.actualFrameNumber(currentFrame);
    new ProcessLocalStructure(MapId.classes,
                              actualFrameNumber,
                              local.slot).addTo(vmSocket);
    Command response = await nextVmCommand();
    if (response is DartValue) {
      print(dartValueToString(response));
    } else {
      assert(response is InstanceStructure);
      InstanceStructure structure = response;
      int classId = structure.classId;
      String className = compiler.lookupClassName(classId);
      print("Instance of '$className' {");
      for (int i = 0; i < structure.fields; i++) {
        DartValue value = await nextVmCommand();
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

  void quit() {
    vmSocket.close();
  }

  void exit(int exitCode) {
    io.exit(exitCode);
  }
}
