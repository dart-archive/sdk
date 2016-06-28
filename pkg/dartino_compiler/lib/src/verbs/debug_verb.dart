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

import 'attach_verb.dart';

import 'documentation.dart' show
    debugDocumentation;

import '../diagnostic.dart' show
    throwInternalError;

import '../worker/developer.dart' show
    Address,
    ClientEventHandler,
    combineTasks,
    compileAndAttachToVmThen,
    handleSignal,
    parseAddress,
    setupClientInOut;

import '../hub/client_commands.dart' show
    ClientCommandCode;

import 'package:dartino_compiler/debug_state.dart' show
    Breakpoint;

import '../../debug_state.dart' show
    RemoteObject,
    BackTrace;

import '../debug_service_protocol.dart' show
    DebugServer;

import '../../vm_commands.dart' show
    VmCommand;

import '../../cli_debugger.dart' show
    CommandLineDebugger,
    processVariable,
    processVariableStructure,
    remoteObjectToString;

const Action debugAction =
    const Action(
        debug,
        debugDocumentation,
        requiresSession: true,
        supportsWithUri: true,
        supportsOn: true,
        supportedTargets: const [TargetKind.FILE, TargetKind.SERVE]);

const int sigQuit = 3;

Future debug(AnalyzedSentence sentence, VerbContext context) async {
  Uri base = sentence.base;
  if (sentence.target == null) {
    return context.performTaskInWorker(
        new InteractiveDebuggerTask(base, snapshotLocation: sentence.withUri));
  }

  SharedTask attachTask;

  if (sentence.onTarget != null) {
    switch (sentence.onTarget.kind) {
      case TargetKind.TTY:
        attachTask = new AttachTtyTask(sentence.onTarget.name);
        break;
      case TargetKind.TCP_SOCKET:
        Address address = parseAddress(sentence.onTarget.name);
        attachTask = new AttachTcpTask(address.host, address.port);
        break;
      default:
        throw "Unsupported on target.";
    }
  }

  DebuggerTask debugTask;
  switch (sentence.target.kind) {
    case TargetKind.SERVE:
      debugTask = new DebuggerTask(TargetKind.SERVE.index, base,
          argument: sentence.targetUri, snapshotLocation: sentence.withUri);
      break;
    case TargetKind.FILE:
      debugTask = new DebuggerTask(TargetKind.FILE.index, base,
          argument: sentence.targetUri, snapshotLocation: sentence.withUri);
      break;
    default:
      throwInternalError("Unimplemented ${sentence.target}");
  }

  return context.performTaskInWorker(combineTasks(attachTask, debugTask));
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

Future<int> serveDebuggerTask(
    CommandSender commandSender,
    StreamIterator<ClientCommand> commandIterator,
    SessionState state,
    Uri script,
    Uri base,
    {Uri snapshotLocation}) {

  return compileAndAttachToVmThen(
      commandSender,
      commandIterator,
      state,
      script,
      base,
      true,
      () => new DebugServer().serveSingleShot(
          state, snapshotLocation: snapshotLocation));
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

  return await new CommandLineDebugger(
      vmContext,
      inputStream,
      base,
      state.stdoutSink,
      echo: false).run(state, snapshotLocation: snapshotLocation);
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
      case TargetKind.SERVE:
        return serveDebuggerTask(
            commandSender,
            commandIterator,
            SessionState.current,
            argument,
            base,
            snapshotLocation: snapshotLocation);
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
