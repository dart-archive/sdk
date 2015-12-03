// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.debug_verb;

import 'dart:core' hide
    StackTrace;

import 'infrastructure.dart';

import 'dart:async' show
    StreamController;

import 'dart:convert' show
    UTF8,
    LineSplitter;

import 'documentation.dart' show
    debugDocumentation;

import '../diagnostic.dart' show
    throwInternalError;

import '../driver/developer.dart' show
    handleSignal,
    compileAndAttachToVmThenDeprecated;

import '../driver/driver_commands.dart' show
    DriverCommand;

import 'package:fletchc/debug_state.dart' show
    Breakpoint;

import '../../debug_state.dart' show
    RemoteObject,
    RemoteValue,
    StackTrace;

import '../../commands.dart' as vm show
    Command;

const Action debugAction =
    const Action(
        debug,
        debugDocumentation,
        requiresSession: true,
        supportedTargets: const [
          TargetKind.APPLY,
          TargetKind.BACKTRACE,
          TargetKind.BREAK,
          TargetKind.CONTINUE,
          TargetKind.DELETE_BREAKPOINT,
          TargetKind.DISASM,
          TargetKind.FIBERS,
          TargetKind.FILE,
          TargetKind.FINISH,
          TargetKind.FRAME,
          TargetKind.LIST,
          TargetKind.LIST_BREAKPOINTS,
          TargetKind.PRINT,
          TargetKind.PRINT_ALL,
          TargetKind.RESTART,
          TargetKind.RUN_TO_MAIN,
          TargetKind.STEP,
          TargetKind.STEP_BYTECODE,
          TargetKind.STEP_OVER,
          TargetKind.STEP_OVER_BYTECODE,
          TargetKind.TOGGLE,
        ]);

const int sigQuit = 3;

Future debug(AnalyzedSentence sentence, VerbContext context) async {
  Uri base = sentence.base;
  if (sentence.target == null) {
    return context.performTaskInWorker(
        new InteractiveDebuggerTask(base));
  }

  DebuggerTask task;
  switch (sentence.target.kind) {
    case TargetKind.APPLY:
      task = new DebuggerTask(TargetKind.APPLY.index, base);
      break;
    case TargetKind.RUN_TO_MAIN:
      task = new DebuggerTask(TargetKind.RUN_TO_MAIN.index, base);
      break;
    case TargetKind.BACKTRACE:
      task = new DebuggerTask(TargetKind.BACKTRACE.index, base);
      break;
    case TargetKind.CONTINUE:
      task = new DebuggerTask(TargetKind.CONTINUE.index, base);
      break;
    case TargetKind.BREAK:
      task = new DebuggerTask(TargetKind.BREAK.index, base,
          sentence.targetName);
      break;
    case TargetKind.LIST:
      task = new DebuggerTask(TargetKind.LIST.index, base);
      break;
    case TargetKind.DISASM:
      task = new DebuggerTask(TargetKind.DISASM.index, base);
      break;
    case TargetKind.FRAME:
      task = new DebuggerTask(TargetKind.FRAME.index, base,
          sentence.targetName);
      break;
    case TargetKind.DELETE_BREAKPOINT:
      task = new DebuggerTask(TargetKind.DELETE_BREAKPOINT.index,
          base,
          sentence.targetName);
      break;
    case TargetKind.LIST_BREAKPOINTS:
      task = new DebuggerTask(TargetKind.LIST_BREAKPOINTS.index, base);
      break;
    case TargetKind.STEP:
      task = new DebuggerTask(TargetKind.STEP.index, base);
      break;
    case TargetKind.STEP_OVER:
      task = new DebuggerTask(TargetKind.STEP_OVER.index, base);
      break;
    case TargetKind.FIBERS:
      task = new DebuggerTask(TargetKind.FIBERS.index, base);
      break;
    case TargetKind.FINISH:
      task = new DebuggerTask(TargetKind.FINISH.index, base);
      break;
    case TargetKind.RESTART:
      task = new DebuggerTask(TargetKind.RESTART.index, base);
      break;
    case TargetKind.STEP_BYTECODE:
      task = new DebuggerTask(TargetKind.STEP_BYTECODE.index, base);
      break;
    case TargetKind.STEP_OVER_BYTECODE:
      task = new DebuggerTask(TargetKind.STEP_OVER_BYTECODE.index, base);
      break;
    case TargetKind.PRINT:
      task = new DebuggerTask(TargetKind.PRINT.index, base,
          sentence.targetName);
      break;
    case TargetKind.PRINT_ALL:
      task = new DebuggerTask(TargetKind.PRINT_ALL.index, base);
      break;
    case TargetKind.TOGGLE:
      task = new DebuggerTask(TargetKind.TOGGLE.index, base,
          sentence.targetName);
      break;
    case TargetKind.FILE:
      task = new DebuggerTask(TargetKind.FILE.index, base,
          sentence.targetUri);
      break;
    default:
      throwInternalError("Unimplemented ${sentence.target}");
  }

  return context.performTaskInWorker(task);
}

Future<Null> readCommands(
    StreamIterator<Command> commandIterator,
    StreamController stdinController,
    SessionState state,
    Session session) async {
  while (await commandIterator.moveNext()) {
    Command command = commandIterator.current;
    switch (command.code) {
      case DriverCommand.Stdin:
        if (command.data.length == 0) {
          await stdinController.close();
        } else {
          stdinController.add(command.data);
        }
        break;

      case DriverCommand.Signal:
        int signalNumber = command.data;
        if (signalNumber == sigQuit) {
          await session.interrupt();
        } else {
          handleSignal(state, signalNumber);
        }
        break;

      default:
        throwInternalError("Unexpected command from client: $command");
    }
  }
}

class InteractiveDebuggerTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final Uri base;

  const InteractiveDebuggerTask(this.base);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return interactiveDebuggerTask(
        commandSender,
        SessionState.current,
        base,
        commandIterator);
  }
}

Future<int> runInteractiveDebuggerTask(
    CommandSender commandSender,
    SessionState state,
    Uri script,
    Uri base,
    StreamIterator<Command> commandIterator) {
  return compileAndAttachToVmThenDeprecated(
      commandSender,
      state,
      script,
      base,
      () => interactiveDebuggerTask(
          commandSender, state, base, commandIterator));
}

Future<int> interactiveDebuggerTask(
    CommandSender commandSender,
    SessionState state,
    Uri base,
    StreamIterator<Command> commandIterator) async {
  List<FletchDelta> compilationResult = state.compilationResults;
  Session session = state.session;
  if (session == null) {
    throwFatalError(DiagnosticKind.attachToVmBeforeRun);
  }
  if (compilationResult.isEmpty) {
    throwFatalError(DiagnosticKind.compileBeforeRun);
  }

  state.attachCommandSender(commandSender);
  state.session = null;
  for (FletchDelta delta in compilationResult) {
    await session.applyDelta(delta);
  }

  // Start event loop.
  StreamController stdinController = new StreamController();
  readCommands(commandIterator, stdinController, state, session);

  // Notify controlling isolate (driver_main) that the event loop
  // [readCommands] has been started, and commands like DriverCommand.Signal
  // will be honored.
  commandSender.sendEventLoopStarted();

  var inputStream = stdinController.stream
      .transform(UTF8.decoder)
      .transform(new LineSplitter());

  return await session.debug(inputStream, base);
}

class DebuggerTask extends SharedTask {
  // Keep this class simple, see note in superclass.
  final int kind;
  final argument;
  final Uri base;

  DebuggerTask(this.kind, this.base, [this.argument]);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    switch (TargetKind.values[kind]) {
      case TargetKind.APPLY:
        return apply(commandSender, SessionState.current);
      case TargetKind.RUN_TO_MAIN:
        return runToMainDebuggerTask(commandSender, SessionState.current);
      case TargetKind.BACKTRACE:
        return backtraceDebuggerTask(commandSender, SessionState.current);
      case TargetKind.CONTINUE:
        return continueDebuggerTask(commandSender, SessionState.current);
      case TargetKind.BREAK:
        return breakDebuggerTask(
            commandSender, SessionState.current, argument, base);
      case TargetKind.LIST:
        return listDebuggerTask(commandSender, SessionState.current);
      case TargetKind.DISASM:
        return disasmDebuggerTask(commandSender, SessionState.current);
      case TargetKind.FRAME:
        return frameDebuggerTask(commandSender, SessionState.current, argument);
      case TargetKind.DELETE_BREAKPOINT:
        return deleteBreakpointDebuggerTask(
            commandSender, SessionState.current, argument);
      case TargetKind.LIST_BREAKPOINTS:
        return listBreakpointsDebuggerTask(commandSender, SessionState.current);
      case TargetKind.STEP:
        return stepDebuggerTask(commandSender, SessionState.current);
      case TargetKind.STEP_OVER:
        return stepOverDebuggerTask(commandSender, SessionState.current);
      case TargetKind.FIBERS:
        return fibersDebuggerTask(commandSender, SessionState.current);
      case TargetKind.FINISH:
        return finishDebuggerTask(commandSender, SessionState.current);
      case TargetKind.RESTART:
        return restartDebuggerTask(commandSender, SessionState.current);
      case TargetKind.STEP_BYTECODE:
        return stepBytecodeDebuggerTask(commandSender, SessionState.current);
      case TargetKind.STEP_OVER_BYTECODE:
        return stepOverBytecodeDebuggerTask(
            commandSender, SessionState.current);
      case TargetKind.PRINT:
        return printDebuggerTask(commandSender, SessionState.current, argument);
      case TargetKind.PRINT_ALL:
        return printAllDebuggerTask(commandSender, SessionState.current);
      case TargetKind.TOGGLE:
        return toggleDebuggerTask(
            commandSender, SessionState.current, argument);
      case TargetKind.FILE:
        return runInteractiveDebuggerTask(
            commandSender, SessionState.current, argument, base,
            commandIterator);

      default:
        throwInternalError("Unimplemented ${TargetKind.values[kind]}");
    }
    return null;
  }
}

Session attachToSession(SessionState state, CommandSender commandSender) {
  Session session = state.session;
  if (session == null) {
    throwFatalError(DiagnosticKind.attachToVmBeforeRun);
  }
  state.attachCommandSender(commandSender);
  return session;
}

Future<int> runToMainDebuggerTask(
    CommandSender commandSender,
    SessionState state) async {
  List<FletchDelta> compilationResults = state.compilationResults;
  Session session = state.session;
  if (session == null) {
    throwFatalError(DiagnosticKind.attachToVmBeforeRun);
  }
  if (compilationResults.isEmpty) {
    throwFatalError(DiagnosticKind.compileBeforeRun);
  }

  state.attachCommandSender(commandSender);
  for (FletchDelta delta in compilationResults) {
    await session.applyDelta(delta);
  }

  await session.enableDebugger();
  await session.spawnProcess();
  await session.setBreakpoint(methodName: "main", bytecodeIndex: 0);
  await session.debugRun();

  return 0;
}

Future<int> backtraceDebuggerTask(
    CommandSender commandSender,
    SessionState state) async {
  Session session = attachToSession(state, commandSender);

  if (!session.loaded) {
    throwInternalError('### process not loaded, cannot show backtrace');
  }
  StackTrace trace = await session.stackTrace();
  print(trace.format());

  return 0;
}

Future<int> continueDebuggerTask(
    CommandSender commandSender,
    SessionState state) async {
  Session session = attachToSession(state, commandSender);

  if (!session.running) {
    // TODO(ager, lukechurch): Fix error reporting.
    throwInternalError('### process not running, cannot continue');
  }
  vm.Command response = await session.cont();
  print(session.processStopResponseToString(response));

  if (session.terminated) state.session = null;

  return 0;
}

Future<int> breakDebuggerTask(
    CommandSender commandSender,
    SessionState state,
    String breakpointSpecification,
    Uri base) async {
  Session session = attachToSession(state, commandSender);

  if (breakpointSpecification.contains('@')) {
    List<String> parts = breakpointSpecification.split('@');

    if (parts.length > 2) {
      // TODO(ager, lukechurch): Fix error reporting.
      throwInternalError('Invalid breakpoint format');
    }

    String name = parts[0];
    int index = 0;

    if (parts.length == 2) {
      index = int.parse(parts[1], onError: (_) => -1);
      if (index == -1) {
        // TODO(ager, lukechurch): Fix error reporting.
        throwInternalError('Invalid bytecode index');
      }
    }

    List<Breakpoint> breakpoints =
    await session.setBreakpoint(methodName: name, bytecodeIndex: index);
    for (Breakpoint breakpoint in breakpoints) {
      print("Breakpoint set: $breakpoint");
    }
  } else if (breakpointSpecification.contains(':')) {
    List<String> parts = breakpointSpecification.split(':');

    if (parts.length != 3) {
      // TODO(ager, lukechurch): Fix error reporting.
      throwInternalError('Invalid breakpoint format');
    }

    String file = parts[0];
    int line = int.parse(parts[1], onError: (_) => -1);
    int column = int.parse(parts[2], onError: (_) => -1);

    if (line < 1 || column < 1) {
      // TODO(ager, lukechurch): Fix error reporting.
      throwInternalError('Invalid line or column number');
    }

    // TODO(ager): Refactor session so that setFileBreakpoint
    // does not print automatically but gives us information about what
    // happened.
    Breakpoint breakpoint =
        await session.setFileBreakpoint(base.resolve(file), line, column);
    if (breakpoint != null) {
      print("Breakpoint set: $breakpoint");
    } else {
      // TODO(ager, lukechurch): Fix error reporting.
      throwInternalError('Failed to set breakpoint');
    }
  } else {
    List<Breakpoint> breakpoints =
        await session.setBreakpoint(
            methodName: breakpointSpecification, bytecodeIndex: 0);
    for (Breakpoint breakpoint in breakpoints) {
      print("Breakpoint set: $breakpoint");
    }
  }

  return 0;
}

Future<int> listDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  Session session = attachToSession(state, commandSender);

  if (!session.loaded) {
    throwInternalError('### process not loaded, nothing to list');
  }
  StackTrace trace = await session.stackTrace();
  if (trace == null) {
    // TODO(ager,lukechurch): Fix error reporting.
    throwInternalError('Source listing failed');
  }
  print(trace.list());

  return 0;
}

Future<int> disasmDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  Session session = attachToSession(state, commandSender);

  if (!session.loaded) {
    throwInternalError('### process not loaded, nothing to disassemble');
  }
  StackTrace trace = await session.stackTrace();
  if (trace == null) {
    // TODO(ager,lukechurch): Fix error reporting.
    throwInternalError('Bytecode disassembly failed');
  }
  print(trace.disasm());

  return 0;
}

Future<int> frameDebuggerTask(
    CommandSender commandSender, SessionState state, String frame) async {
  Session session = attachToSession(state, commandSender);

  int frameNumber = int.parse(frame, onError: (_) => -1);
  if (frameNumber == -1) {
    // TODO(ager,lukechurch): Fix error reporting.
    throwInternalError('Invalid frame number');
  }

  bool frameSelected = await session.selectFrame(frameNumber);
  if (!frameSelected) {
    // TODO(ager,lukechurch): Fix error reporting.
    throwInternalError('Frame selection failed');
  }

  return 0;
}

Future<int> deleteBreakpointDebuggerTask(
    CommandSender commandSender, SessionState state, String breakpoint) async {
  Session session = attachToSession(state, commandSender);

  int id = int.parse(breakpoint, onError: (_) => -1);
  if (id == -1) {
    // TODO(ager,lukechurch): Fix error reporting.
    throwInternalError('Invalid breakpoint id: $breakpoint');
  }

  Breakpoint bp = await session.deleteBreakpoint(id);
  if (bp == null) {
    throwInternalError('Invalid breakpoint id: $id');
  }
  print('Deleted breakpoint: $bp');
  return 0;
}

Future<int> listBreakpointsDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  Session session = attachToSession(state, commandSender);
  List<Breakpoint> breakpoints = session.breakpoints();
  if (breakpoints == null || breakpoints.isEmpty) {
    print('No breakpoints');
  } else {
    print('Breakpoints:');
    for (Breakpoint bp in breakpoints) {
      print(bp);
    }
  }
  return 0;
}

Future<int> stepDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  Session session = attachToSession(state, commandSender);
  if (!session.running) {
    throwInternalError(
        '### process not running, cannot step to next expression');
  }
  vm.Command response = await session.step();
  print(session.processStopResponseToString(response));
  return 0;
}

Future<int> stepOverDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  Session session = attachToSession(state, commandSender);
  if (!session.running) {
    throwInternalError('### process not running, cannot go to next expression');
  }
  vm.Command response = await session.stepOver();
  print(session.processStopResponseToString(response));
  return 0;
}

Future<int> fibersDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  Session session = attachToSession(state, commandSender);
  if (!session.running) {
    throwInternalError('### process not running, cannot show fibers');
  }
  List<StackTrace> traces = await session.fibers();
  print('');
  for (int fiber = 0; fiber < traces.length; ++fiber) {
    print('fiber $fiber');
    print(traces[fiber].format());
  }
  return 0;
}

Future<int> finishDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  Session session = attachToSession(state, commandSender);
  if (!session.running) {
    throwInternalError('### process not running, cannot finish method');
  }
  vm.Command response = await session.stepOut();
  print(session.processStopResponseToString(response));
  return 0;
}

Future<int> restartDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  Session session = attachToSession(state, commandSender);
  if (!session.loaded) {
    throwInternalError('### process not loaded, cannot restart');
  }
  StackTrace trace = await session.stackTrace();
  if (trace == null) {
    throwInternalError("### cannot restart when nothing is executing.");
  }
  if (trace.frames <= 1) {
    throwInternalError("### cannot restart entry frame.");
  }
  vm.Command response = await session.restart();
  print(session.processStopResponseToString(response));
  return 0;
}

Future<int> apply(
    CommandSender commandSender, SessionState state) async {
  Session session = attachToSession(state, commandSender);
  await session.applyDelta(state.compilationResults.last);
  return 0;
}

Future<int> stepBytecodeDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  Session session = attachToSession(state, commandSender);
  if (!session.running) {
    throwInternalError('### process not running, cannot step bytecode');
  }
  vm.Command response = await session.stepBytecode();
  assert(response != null);  // stepBytecode cannot return null
  print(session.processStopResponseToString(response));
  return 0;
}

Future<int> stepOverBytecodeDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  Session session = attachToSession(state, commandSender);
  if (!session.running) {
    throwInternalError('### process not running, cannot step over bytecode');
  }
  vm.Command response = await session.stepOverBytecode();
  assert(response != null);  // stepOverBytecode cannot return null
  print(session.processStopResponseToString(response));
  return 0;
}

Future<int> printDebuggerTask(
    CommandSender commandSender, SessionState state, String name) async {
  Session session = attachToSession(state, commandSender);

  RemoteObject variable;
  if (name.startsWith("*")) {
    name = name.substring(1);
    variable = await session.processVariableStructure(name);
  } else {
    variable = await session.processVariable(name);
  }
  if (variable == null) {
    print('### No such variable: $name');
  } else {
    print(session.remoteObjectToString(variable));
  }

  return 0;
}

Future<int> printAllDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  Session session = attachToSession(state, commandSender);
  List<RemoteObject> variables = await session.processAllVariables();
  if (variables.isEmpty) {
    print('### No variables in scope');
  } else {
    for (RemoteObject variable in variables) {
      print(session.remoteObjectToString(variable));
    }
  }
  return 0;
}

Future<int> toggleDebuggerTask(
    CommandSender commandSender, SessionState state, String argument) async {
  Session session = attachToSession(state, commandSender);

  if (argument != 'internal') {
    // TODO(ager, lukechurch): Fix error reporting.
    throwInternalError("Invalid argument to toggle. "
                       "Valid arguments: 'internal'.");
  }
  await session.toggleInternal();

  return 0;
}
