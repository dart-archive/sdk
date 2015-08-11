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

const Verb debugVerb =
    const Verb(debug, debugDocumentation, requiresSession: true);

Future debug(AnalyzedSentence sentence, VerbContext context) async {
  context.performTaskInWorker(new InteractiveDebuggerTask());
  return null;
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
