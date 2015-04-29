// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletch.session;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'bytecodes.dart';
import 'commands.dart';
import 'compiler.dart' show FletchCompiler;
import 'src/codegen_visitor.dart';
import 'src/debug_info.dart';

part 'command_reader.dart';
part 'input_handler.dart';
part 'stack_trace.dart';

class Breakpoint {
  final String methodName;
  final int bytecodeIndex;
  final int id;
  Breakpoint(this.methodName, this.bytecodeIndex, this.id);
  String toString() => "$id: $methodName @$bytecodeIndex";
}

class Session {
  final Socket vmSocket;
  final FletchCompiler compiler;
  final Map<int, Breakpoint> breakpoints = new Map();

  StreamIterator<Command> vmCommands;
  StackTrace currentStackTrace;
  int currentFrame = 0;
  SourceLocation currentLocation;
  bool running = false;

  Session(this.vmSocket, this.compiler);

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
    const Debugging().addTo(vmSocket);
    const ProcessSpawnForMain().addTo(vmSocket);
    await new InputHandler(this).run();
  }

  Future testDebugStepToCompletion() async {
    vmCommands = new CommandReader(vmSocket).iterator;
    const Debugging().addTo(vmSocket);
    const ProcessSpawnForMain().addTo(vmSocket);
    await setBreakpoint(methodName: 'main', bytecodeIndex: 0);
    await debugRun();
    while (true) {
      await step();
    }
  }

  Future nextVmCommand() async {
    var hasNext = await vmCommands.moveNext();
    assert(hasNext);
    return vmCommands.current;
  }

  Future handleProcessStop() async {
    currentStackTrace = null;
    currentFrame = 0;
    Command response = await nextVmCommand();
    switch (response.code) {
      case CommandCode.UncaughtException:
        await backtrace();
        running = false;
        break;
      case CommandCode.ProcessTerminate:
        print('### process terminated');
        quit();
        exit(0);
        break;
      default:
        assert(response.code == CommandCode.ProcessBreakpoint);
        await getStackTrace();
        break;
    }
  }

  bool checkRunning() {
    if (!running) print("### process not running");
    return running;
  }

  Future debugRun() async {
    if (running) {
      print("### already running");
      return;
    }
    running = true;
    const ProcessRun().addTo(vmSocket);
    await handleProcessStop();
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
    breakpoints[breakpointId] = breakpoint;
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
      return;
    }
    DebugInfo debugInfo = compiler.debugInfoForPosition(file, position);
    if (debugInfo == null) {
      print("### Failed setting breakpoint for $name");
      return;
    }
    SourceLocation location = debugInfo.locationForPosition(position);
    if (location == null) {
      print("### Failed setting breakpoint for $name");
      return;
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
      return;
    }
    int position = compiler.positionInFileFromPattern(file, line - 1, pattern);
    await setFileBreakpointFromPosition('$file:$line:$pattern', file, position);
  }

  Future setFileBreakpoint(String file, int line, int column) async {
    if (line < 1) {
      print("### Invalid line number: $line");
      return;
    }
    if (column < 1) {
      print("### Invalid column number: $column");
      return;
    }
    int position = compiler.positionInFile(file, line - 1, column - 1);
    await setFileBreakpointFromPosition('$file:$line:$column', file, position);
  }

  Future deleteBreakpoint(int id) async {
    if (!breakpoints.containsKey(id)) {
      print("### invalid breakpoint id: $id");
      return;
    }
    new ProcessDeleteBreakpoint(id).addTo(vmSocket);
    ProcessDeleteBreakpoint response = await nextVmCommand();
    assert(response.id == id);
    print("deleted breakpoint: ${breakpoints[id]}");
    breakpoints.remove(id);
  }

  void listBreakpoints() {
    if (breakpoints.isEmpty) {
      print('No breakpoints.');
      return;
    }
    print("Breakpoints:");
    for (var bp in breakpoints.values) {
      print(bp);
    }
  }

  Future stepTo(int methodId, int bcp) async {
    if (!checkRunning()) return;
    new ProcessStepTo(MapId.methods, methodId, bcp).addTo(vmSocket);
    await handleProcessStop();
  }

  Future step() async {
    if (!checkRunning()) return;
    SourceLocation previous = currentLocation;
    do {
      var bcp = currentStackTrace.stepBytecodePointer(compiler, previous);
      if (bcp != -1) {
        await stepTo(currentStackTrace.methodId, bcp);
      } else {
        await stepBytecode();
      }
    } while (currentLocation == null ||
             currentLocation == previous ||
             currentLocation.node == null);
    await backtrace();
  }

  Future stepOver() async {
    if (!checkRunning()) return;
    SourceLocation previous = currentLocation;
    do {
      await stepOverBytecode();
    } while (currentLocation == null ||
             currentLocation == previous ||
             currentLocation.node == null);
    await backtrace();
  }

  Future stepBytecode() async {
    if (!checkRunning()) return;
    const ProcessStep().addTo(vmSocket);
    await handleProcessStop();
  }

  Future stepOverBytecode() async {
    if (!checkRunning()) return;
    const ProcessStepOver().addTo(vmSocket);
    await handleProcessStop();
  }

  Future cont() async {
    if (!checkRunning()) return;
    const ProcessContinue().addTo(vmSocket);
    await handleProcessStop();
    await backtrace();
  }

  void list() {
    if (currentStackTrace == null) {
      print("### no stack trace");
      return;
    }
    currentStackTrace.list(compiler, currentFrame);
  }

  void disasm() {
    if (currentStackTrace == null) {
      print("### no stack trace");
      return;
    }
    currentStackTrace.disasm(compiler, currentFrame);
  }

  void selectFrame(int frame) {
    if (currentStackTrace == null ||
        frame >= currentStackTrace.stackFrames.length) {
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
      for (int i = 0; i < frames; ++i) {
        currentStackTrace.addFrame(
            compiler,
            new StackFrame(backtraceResponse.methodIds[i],
                           backtraceResponse.bytecodeIndices[i]));
      }
      currentLocation = currentStackTrace.sourceLocation(compiler);
    }
  }

  Future backtrace() async {
    await getStackTrace();
    currentStackTrace.write(compiler, currentFrame);
  }

  Future printLocal(LocalValue local) async {
    String name = local.element.name;
    new ProcessLocal(currentFrame, local.slot).addTo(vmSocket);
    Command response = await nextVmCommand();
    if (response is Integer) {
      print('$name: ${response.value}');
      return;
    }
    assert(response is Instance);
    // The local is an instance of a class. The class is on the session stack,
    // lookup the class id in the class map and drop the class from the session
    // stack.
    new MapLookup(MapId.classes).addTo(vmSocket);
    const Drop(1).addTo(vmSocket);
    var classId = (await nextVmCommand()).id;
    String className = compiler.lookupClassName(classId);
    print('$name: instance of $className');
  }

  Future printAllVariables() async {
    await getStackTrace();
    ScopeInfo info = currentStackTrace.scopeInfo(compiler, currentFrame);
    for (ScopeInfo current = info;
         current != ScopeInfo.sentinel;
         current = current.previous) {
      await printLocal(current.local);
    }
  }

  Future printVariable(String name) async {
    await getStackTrace();
    ScopeInfo info = currentStackTrace.scopeInfo(compiler, currentFrame);
    LocalValue local = info.lookup(name);
    if (local == null) {
      print('### No such variable: $name');
      return;
    }
    await printLocal(local);
  }

  void quit() {
    vmSocket.close();
  }
}
