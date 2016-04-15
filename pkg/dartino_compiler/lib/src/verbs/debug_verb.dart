// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.verbs.debug_verb;

import 'dart:core' hide
    StackTrace;

import 'infrastructure.dart';

import 'dart:async' show
    Stream,
    StreamController,
    StreamIterator;

import 'dart:convert' show
    UTF8,
    LineSplitter;

import 'documentation.dart' show
    debugDocumentation;

import '../diagnostic.dart' show
    throwInternalError;

import '../worker/developer.dart' show
    ClientEventHandler,
    handleSignal,
    compileAndAttachToVmThen,
    setupClientInOut;

import '../hub/client_commands.dart' show
    ClientCommandCode;

import 'package:dartino_compiler/debug_state.dart' show
    Breakpoint;

import '../../debug_state.dart' show
    RemoteObject,
    BackTrace;

import '../../vm_commands.dart' show
    VmCommand;

const Action debugAction =
    const Action(
        debug,
        debugDocumentation,
        requiresSession: true,
        supportsWithUri: true,
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
        new InteractiveDebuggerTask(base, snapshotLocation: sentence.withUri));
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
          argument: sentence.targetName);
      break;
    case TargetKind.LIST:
      task = new DebuggerTask(TargetKind.LIST.index, base);
      break;
    case TargetKind.DISASM:
      task = new DebuggerTask(TargetKind.DISASM.index, base);
      break;
    case TargetKind.FRAME:
      task = new DebuggerTask(TargetKind.FRAME.index, base,
          argument: sentence.targetName);
      break;
    case TargetKind.DELETE_BREAKPOINT:
      task = new DebuggerTask(TargetKind.DELETE_BREAKPOINT.index, base,
          argument: sentence.targetName);
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
          argument: sentence.targetName);
      break;
    case TargetKind.PRINT_ALL:
      task = new DebuggerTask(TargetKind.PRINT_ALL.index, base);
      break;
    case TargetKind.TOGGLE:
      task = new DebuggerTask(TargetKind.TOGGLE.index, base,
          argument: sentence.targetName);
      break;
    case TargetKind.FILE:
      task = new DebuggerTask(TargetKind.FILE.index, base,
          argument: sentence.targetUri, snapshotLocation: sentence.withUri);
      break;
    default:
      throwInternalError("Unimplemented ${sentence.target}");
  }

  return context.performTaskInWorker(task);
}

// Returns a debug client event handler that is bound to the current session.
ClientEventHandler debugClientEventHandler(
    SessionState state,
    StreamIterator<ClientCommand> commandIterator,
    StreamController stdinController) {
  // TODO(zerny): Take the correct session explicitly because it will be cleared
  // later to ensure against possible reuse. Restructure the code to avoid this.
  return (DartinoVmContext vmContext) async {
    while (await commandIterator.moveNext()) {
      ClientCommand command = commandIterator.current;
      switch (command.code) {
        case ClientCommandCode.Stdin:
          if (command.data.length == 0) {
            await stdinController.close();
          } else {
            stdinController.add(command.data);
          }
          break;

        case ClientCommandCode.Signal:
          int signalNumber = command.data;
          if (signalNumber == sigQuit) {
            await vmContext.interrupt();
          } else {
            handleSignal(state, signalNumber);
          }
          break;

        default:
          throwInternalError("Unexpected command from client: $command");
      }
    }
  };
}

class InteractiveDebuggerTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  final Uri base;

  final Uri snapshotLocation;

  const InteractiveDebuggerTask(this.base, {this.snapshotLocation});

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) {

    // Setup a more advanced client input handler for the interactive debug task
    // that also handles the input and forwards it to the debug input handler.
    StreamController stdinController = new StreamController();
    SessionState state = SessionState.current;
    setupClientInOut(
        state,
        commandSender,
        debugClientEventHandler(state, commandIterator, stdinController));

    return interactiveDebuggerTask(state,
        base,
        stdinController,
        snapshotLocation: snapshotLocation);
  }
}

Future<int> runInteractiveDebuggerTask(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator,
    SessionState state,
    Uri script,
    Uri base,
    {Uri snapshotLocation}) {

  // Setup a more advanced client input handler for the interactive debug task
  // that also handles the input and forwards it to the debug input handler.
  StreamController stdinController = new StreamController();
  return compileAndAttachToVmThen(
      commandSender,
      commandIterator,
      state,
      script,
      base,
      true,
      () => interactiveDebuggerTask(
          state,
          base,
          stdinController,
          snapshotLocation: snapshotLocation),
      eventHandler:
          debugClientEventHandler(state, commandIterator, stdinController));
}

Future<int> interactiveDebuggerTask(
    SessionState state,
    Uri base,
    StreamController stdinController,
    {Uri snapshotLocation}) async {
  DartinoVmContext vmContext = state.vmContext;
  if (vmContext == null) {
    throwFatalError(DiagnosticKind.attachToVmBeforeRun);
  }
  List<DartinoDelta> compilationResult = state.compilationResults;
  if (snapshotLocation == null && compilationResult.isEmpty) {
    throwFatalError(DiagnosticKind.compileBeforeRun);
  }

  // Make sure current state's vmContext is not reused if invoked again.
  state.vmContext = null;

  Stream<String> inputStream = stdinController.stream
      .transform(UTF8.decoder)
      .transform(new LineSplitter());

  return await vmContext.debug((DartinoVmContext _) => inputStream,
      base,
      state,
      snapshotLocation: snapshotLocation);
}

class DebuggerTask extends SharedTask {
  // Keep this class simple, see note in superclass.
  final int kind;
  final argument;
  final Uri base;
  final Uri snapshotLocation;

  DebuggerTask(this.kind, this.base, {this.argument, this.snapshotLocation});

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<ClientCommand> commandIterator) {
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
            commandSender, commandIterator, SessionState.current, argument,
            base, snapshotLocation: snapshotLocation);

      default:
        throwInternalError("Unimplemented ${TargetKind.values[kind]}");
    }
    return null;
  }
}

DartinoVmContext attachToSession(
    SessionState state, CommandSender commandSender) {
  DartinoVmContext vmContext = state.vmContext;
  if (vmContext == null) {
    throwFatalError(DiagnosticKind.attachToVmBeforeRun);
  }
  state.attachCommandSender(commandSender);
  return vmContext;
}

Future<int> runToMainDebuggerTask(
    CommandSender commandSender,
    SessionState state) async {
  List<DartinoDelta> compilationResults = state.compilationResults;
  DartinoVmContext vmContext = state.vmContext;
  if (vmContext == null) {
    throwFatalError(DiagnosticKind.attachToVmBeforeRun);
  }
  if (vmContext.loaded) {
    // We cannot reuse a vm context that has already been loaded. Loading
    // currently implies that some of the code has been run.
    throwFatalError(DiagnosticKind.sessionInvalidState,
        sessionName: state.name);
  }
  if (compilationResults.isEmpty) {
    throwFatalError(DiagnosticKind.compileBeforeRun);
  }

  state.attachCommandSender(commandSender);
  for (DartinoDelta delta in compilationResults) {
    await vmContext.applyDelta(delta);
  }

  await vmContext.enableDebugger();
  // TODO(ahe): Add support for arguments when debugging.
  await vmContext.spawnProcess([]);
  await vmContext.setBreakpoint(methodName: "main", bytecodeIndex: 0);
  await vmContext.debugRun();

  return 0;
}

Future<int> backtraceDebuggerTask(
    CommandSender commandSender,
    SessionState state) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);

  if (!vmContext.loaded) {
    throwInternalError('### process not loaded, cannot show backtrace');
  }
  BackTrace trace = await vmContext.backTrace();
  print(trace.format());

  return 0;
}

Future<int> continueDebuggerTask(
    CommandSender commandSender,
    SessionState state) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);

  if (!vmContext.running) {
    // TODO(ager, lukechurch): Fix error reporting.
    throwInternalError('### process not running, cannot continue');
  }
  VmCommand response = await vmContext.cont();
  print(await vmContext.processStopResponseToString(response, state));

  if (vmContext.terminated) state.vmContext = null;

  return 0;
}

Future<int> breakDebuggerTask(
    CommandSender commandSender,
    SessionState state,
    String breakpointSpecification,
    Uri base) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);

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
    await vmContext.setBreakpoint(methodName: name, bytecodeIndex: index);
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

    // TODO(ager): Refactor VmContext so that setFileBreakpoint
    // does not print automatically but gives us information about what
    // happened.
    Breakpoint breakpoint =
        await vmContext.setFileBreakpoint(base.resolve(file), line, column);
    if (breakpoint != null) {
      print("Breakpoint set: $breakpoint");
    } else {
      // TODO(ager, lukechurch): Fix error reporting.
      throwInternalError('Failed to set breakpoint');
    }
  } else {
    List<Breakpoint> breakpoints =
        await vmContext.setBreakpoint(
            methodName: breakpointSpecification, bytecodeIndex: 0);
    for (Breakpoint breakpoint in breakpoints) {
      print("Breakpoint set: $breakpoint");
    }
  }

  return 0;
}

Future<int> listDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);

  if (!vmContext.loaded) {
    throwInternalError('### process not loaded, nothing to list');
  }
  BackTrace trace = await vmContext.backTrace();
  if (trace == null) {
    // TODO(ager,lukechurch): Fix error reporting.
    throwInternalError('Source listing failed');
  }
  print(trace.list(state));

  return 0;
}

Future<int> disasmDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);

  if (!vmContext.loaded) {
    throwInternalError('### process not loaded, nothing to disassemble');
  }
  BackTrace trace = await vmContext.backTrace();
  if (trace == null) {
    // TODO(ager,lukechurch): Fix error reporting.
    throwInternalError('Bytecode disassembly failed');
  }
  print(trace.disasm());

  return 0;
}

Future<int> frameDebuggerTask(
    CommandSender commandSender, SessionState state, String frame) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);

  int frameNumber = int.parse(frame, onError: (_) => -1);
  if (frameNumber == -1) {
    // TODO(ager,lukechurch): Fix error reporting.
    throwInternalError('Invalid frame number');
  }

  bool frameSelected = await vmContext.selectFrame(frameNumber);
  if (!frameSelected) {
    // TODO(ager,lukechurch): Fix error reporting.
    throwInternalError('Frame selection failed');
  }

  return 0;
}

Future<int> deleteBreakpointDebuggerTask(
    CommandSender commandSender, SessionState state, String breakpoint) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);

  int id = int.parse(breakpoint, onError: (_) => -1);
  if (id == -1) {
    // TODO(ager,lukechurch): Fix error reporting.
    throwInternalError('Invalid breakpoint id: $breakpoint');
  }

  Breakpoint bp = await vmContext.deleteBreakpoint(id);
  if (bp == null) {
    throwInternalError('Invalid breakpoint id: $id');
  }
  print('Deleted breakpoint: $bp');
  return 0;
}

Future<int> listBreakpointsDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);
  List<Breakpoint> breakpoints = vmContext.breakpoints();
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
  DartinoVmContext vmContext = attachToSession(state, commandSender);
  if (!vmContext.running) {
    throwInternalError(
        '### process not running, cannot step to next expression');
  }
  VmCommand response = await vmContext.step();
  print(await vmContext.processStopResponseToString(response, state));
  return 0;
}

Future<int> stepOverDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);
  if (!vmContext.running) {
    throwInternalError('### process not running, cannot go to next expression');
  }
  VmCommand response = await vmContext.stepOver();
  print(await vmContext.processStopResponseToString(response, state));
  return 0;
}

Future<int> fibersDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);
  if (!vmContext.running) {
    throwInternalError('### process not running, cannot show fibers');
  }
  List<BackTrace> traces = await vmContext.fibers();
  print('');
  for (int fiber = 0; fiber < traces.length; ++fiber) {
    print('fiber $fiber');
    print(traces[fiber].format());
  }
  return 0;
}

Future<int> finishDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);
  if (!vmContext.running) {
    throwInternalError('### process not running, cannot finish method');
  }
  VmCommand response = await vmContext.stepOut();
  print(await vmContext.processStopResponseToString(response, state));
  return 0;
}

Future<int> restartDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);
  if (!vmContext.loaded) {
    throwInternalError('### process not loaded, cannot restart');
  }
  BackTrace trace = await vmContext.backTrace();
  if (trace == null) {
    throwInternalError("### cannot restart when nothing is executing.");
  }
  if (trace.length <= 1) {
    throwInternalError("### cannot restart entry frame.");
  }
  VmCommand response = await vmContext.restart();
  print(await vmContext.processStopResponseToString(response, state));
  return 0;
}

Future<int> apply(
    CommandSender commandSender, SessionState state) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);
  await vmContext.applyDelta(state.compilationResults.last);
  return 0;
}

Future<int> stepBytecodeDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);
  if (!vmContext.running) {
    throwInternalError('### process not running, cannot step bytecode');
  }
  VmCommand response = await vmContext.stepBytecode();
  assert(response != null);  // stepBytecode cannot return null
  print(await vmContext.processStopResponseToString(response, state));
  return 0;
}

Future<int> stepOverBytecodeDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);
  if (!vmContext.running) {
    throwInternalError('### process not running, cannot step over bytecode');
  }
  VmCommand response = await vmContext.stepOverBytecode();
  assert(response != null);  // stepOverBytecode cannot return null
  print(await vmContext.processStopResponseToString(response, state));
  return 0;
}

Future<int> printDebuggerTask(
    CommandSender commandSender, SessionState state, String name) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);

  RemoteObject variable;
  if (name.startsWith("*")) {
    name = name.substring(1);
    variable = await vmContext.processVariableStructure(name);
  } else {
    variable = await vmContext.processVariable(name);
  }
  if (variable == null) {
    print('### No such variable: $name');
  } else {
    print(vmContext.remoteObjectToString(variable));
  }

  return 0;
}

Future<int> printAllDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);
  List<RemoteObject> variables = await vmContext.processAllVariables();
  if (variables.isEmpty) {
    print('### No variables in scope');
  } else {
    for (RemoteObject variable in variables) {
      print(vmContext.remoteObjectToString(variable));
    }
  }
  return 0;
}

Future<int> toggleDebuggerTask(
    CommandSender commandSender, SessionState state, String argument) async {
  DartinoVmContext vmContext = attachToSession(state, commandSender);

  if (argument != 'internal') {
    // TODO(ager, lukechurch): Fix error reporting.
    throwInternalError("Invalid argument to toggle. "
                       "Valid arguments: 'internal'.");
  }
  await vmContext.toggleInternal();

  return 0;
}
