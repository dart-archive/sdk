// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.verbs.debug_verb;

import 'infrastructure.dart';

import 'dart:async' show
    StreamController,
    Zone;

import 'dart:convert' show
    UTF8,
    LineSplitter;

import 'documentation.dart' show
    debugDocumentation;

import '../diagnostic.dart' show
    throwInternalError;

import '../driver/driver_commands.dart' show
    DriverCommand;

import 'package:fletchc/debug_state.dart' show
    Breakpoint;

const Verb debugVerb =
    const Verb(
        debug,
        debugDocumentation,
        requiresSession: true,
        supportedTargets: const [
          TargetKind.RUN_TO_MAIN,
          TargetKind.BACKTRACE,
          TargetKind.BREAK,
          TargetKind.CONTINUE,
          TargetKind.LIST,
          TargetKind.DISASM,
          TargetKind.FRAME
        ]);

Future debug(AnalyzedSentence sentence, VerbContext context) async {
  if (sentence.target == null) {
    context.performTaskInWorker(new InteractiveDebuggerTask());
    return null;
  }

  DebuggerTask task;
  switch (sentence.target.kind) {
    case TargetKind.RUN_TO_MAIN:
      task = new DebuggerTask(TargetKind.RUN_TO_MAIN.index);
      break;
    case TargetKind.BACKTRACE:
      task = new DebuggerTask(TargetKind.BACKTRACE.index);
      break;
    case TargetKind.CONTINUE:
      task = new DebuggerTask(TargetKind.CONTINUE.index);
      break;
    case TargetKind.BREAK:
      task = new DebuggerTask(TargetKind.BREAK.index, sentence.targetName);
      break;
    case TargetKind.LIST:
      task = new DebuggerTask(TargetKind.LIST.index);
      break;
    case TargetKind.DISASM:
      task = new DebuggerTask(TargetKind.DISASM.index);
      break;
    case TargetKind.FRAME:
      task = new DebuggerTask(TargetKind.FRAME.index, sentence.targetName);
      break;
    default:
      throwInternalError("Unimplemented ${sentence.target}");
  }

  context.performTaskInWorker(task);
  return null;
}

Future<Null> readCommands(
    StreamIterator<Command> commandIterator,
    StreamController stdinController) async {
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
        throwInternalError("Unimplemented");
        break;

      default:
        throwInternalError("Unexpected command from client: $command");
    }
  }
}

class InteractiveDebuggerTask extends SharedTask {
  // Keep this class simple, see note in superclass.

  const InteractiveDebuggerTask();

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    return interactiveDebuggerTask(
        commandSender,
        SessionState.current,
        commandIterator);
  }
}

Future<int> interactiveDebuggerTask(
    CommandSender commandSender,
    SessionState state,
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
  readCommands(commandIterator, stdinController);

  var inputStream = stdinController.stream
      .transform(UTF8.decoder)
      .transform(new LineSplitter());

  return await session.debug(inputStream);
}

class DebuggerTask extends SharedTask {
  // Keep this class simple, see note in superclass.
  final int kind;
  final String argument;

  DebuggerTask(this.kind, [this.argument]);

  Future<int> call(
      CommandSender commandSender,
      StreamIterator<Command> commandIterator) {
    switch (TargetKind.values[kind]) {
      case TargetKind.RUN_TO_MAIN:
        return runToMainDebuggerTask(commandSender, SessionState.current);
      case TargetKind.BACKTRACE:
        return backtraceDebuggerTask(commandSender, SessionState.current);
      case TargetKind.CONTINUE:
        return continueDebuggerTask(commandSender, SessionState.current);
      case TargetKind.BREAK:
        return breakDebuggerTask(commandSender, SessionState.current, argument);
      case TargetKind.LIST:
        return listDebuggerTask(commandSender, SessionState.current);
      case TargetKind.DISASM:
        return disasmDebuggerTask(commandSender, SessionState.current);
      case TargetKind.FRAME:
        return frameDebuggerTask(commandSender, SessionState.current, argument);
      default:
        throwInternalError("Unimplemented ${TargetKind.values[kind]}");
    }
    return null;
  }
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
  Session session = state.session;
  if (session == null) {
    throwFatalError(DiagnosticKind.attachToVmBeforeRun);
  }

  state.attachCommandSender(commandSender);

  // TODO(ager): change the backtrace command to not do the printing
  // directly.
  // TODO(ager): deal gracefully with situations where there is a VM
  // session, but the VM terminated.
  await session.backtrace();

  return 0;
}

Future<int> continueDebuggerTask(
    CommandSender commandSender,
    SessionState state) async {
  Session session = state.session;
  if (session == null) {
    throwFatalError(DiagnosticKind.attachToVmBeforeRun);
  }

  state.attachCommandSender(commandSender);

  if (!session.running) {
    // TODO(ager, lukechurch): Fix error reporting.
    throwInternalError('Program not running');
  }

  // TODO(ager): Print information about the stop condition. Which breakpoint
  // was hit? Did the session terminate?
  await session.cont();

  if (session.terminated) state.session = null;

  return 0;
}

Future<int> breakDebuggerTask(
    CommandSender commandSender,
    SessionState state,
    String breakpointSpecification) async {
  Session session = state.session;
  if (session == null) {
    throwFatalError(DiagnosticKind.attachToVmBeforeRun);
  }

  state.attachCommandSender(commandSender);

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

    if (line == -1 || column == -1) {
      // TODO(ager, lukechurch): Fix error reporting.
      throwInternalError('Invalid line or column number');
    }

    // TODO(ager): Refactor session so that setFileBreakpoint
    // does not print automatically but gives us information about what
    // happened.
    Breakpoint breakpoint =
        await session.setFileBreakpoint(file, line, column);
    if (breakpoint != null) {
      print("Breakpoint set: $breakpoint");
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
  Session session = state.session;
  if (session == null) {
    throwFatalError(DiagnosticKind.attachToVmBeforeRun);
  }

  state.attachCommandSender(commandSender);

  String listing = await session.list();

  if (listing == null) {
    // TODO(ager,lukechurch): Fix error reporting.
    throwInternalError('Source listing failed');
  }

  print(listing);

  return 0;
}

Future<int> disasmDebuggerTask(
    CommandSender commandSender, SessionState state) async {
  Session session = state.session;
  if (session == null) {
    throwFatalError(DiagnosticKind.attachToVmBeforeRun);
  }

  state.attachCommandSender(commandSender);

  String disasm = await session.disasm();

  if (disasm == null) {
    // TODO(ager,lukechurch): Fix error reporting.
    throwInternalError('Bytecode disassembly failed');
  }

  print(disasm);

  return 0;
}

Future<int> frameDebuggerTask(
    CommandSender commandSender, SessionState state, String frame) async {
  Session session = state.session;
  if (session == null) {
    throwFatalError(DiagnosticKind.attachToVmBeforeRun);
  }

  state.attachCommandSender(commandSender);

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
