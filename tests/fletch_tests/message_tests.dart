// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async' show
    Completer,
    Future,
    Stream,
    Zone;

import 'dart:convert' show
    UTF8;

import 'package:expect/expect.dart' show
    Expect;

import 'package:fletchc/src/diagnostic.dart';

import 'package:fletchc/src/messages.dart';

import 'package:fletchc/src/message_examples.dart';

import 'package:fletchc/src/driver/sentence_parser.dart' show
    Sentence,
    parseSentence;

import 'package:fletchc/src/verbs/verbs.dart' show
    Verb;

import 'package:fletchc/src/driver/driver_main.dart' show
    ClientController,
    ClientLogger,
    IsolatePool,
    handleClientInWorker,
    handleVerbHere;

import 'package:fletchc/src/driver/driver_isolate.dart' show
    isolateMain;

import 'package:fletchc/src/driver/session_manager.dart' show
    endAllSessions;

import 'package:fletchc/src/driver/driver_commands.dart' show
    Command,
    DriverCommand;

final IsolatePool pool = new IsolatePool(isolateMain);

Future<Null> main() async {
  for (DiagnosticKind kind in DiagnosticKind.values) {
    Expect.isNotNull(getMessage(kind));
    if (kind == DiagnosticKind.internalError) continue;

    print("Testing $kind");
    List<Example> examples = getExamples(kind);
    Expect.isNotNull(examples);
    Expect.isFalse(examples.isEmpty);
    for (Example example in examples) {
      Expect.isNotNull(example);
      await checkExample(kind, example);
    }
    endAllSessions();
    pool.shutdown();
    print("Done testing $kind");
  }
}

Future<Null> checkExample(DiagnosticKind kind, Example example) async {
  if (example is CommandLineExample) {
    await checkCommandLineExample(kind, example);
  } else {
    throw "Unknown kind of example: $example";
  }
}

Future<Null> checkCommandLineExample(
    DiagnosticKind kind,
    CommandLineExample example) async {
  List<String> setup;
  List<String> lastLine;
  if (example.line2 == null) {
    setup = null;
    lastLine = example.line1;
  } else {
    setup = example.line1;
    lastLine = example.line2;
  }
  if (setup != null) {
    MockClientController mock = await mockCommandLine(setup);
    Expect.isNull(mock.recordedError);
    Expect.equals(0, mock.recordedExitCode);
  }
  MockClientController mock = await mockCommandLine(lastLine);
  // TODO(ahe): NO_FILE_TARGET and COMPILE_REQUIRES_FILE_TARGET are processed
  // in worker isolate. Move them to the main isolate, or serialze InputError
  // and send it over the command port from the worker isolate to the main
  // isolate.
  if (kind == DiagnosticKind.noFileTarget) {
    String message = mock.stderrMessages.single;
    Expect.stringEquals('${getMessage(kind)}\n', message);
  } else if (kind == DiagnosticKind.compileRequiresFileTarget) {
    Sentence sentence = parseSentence(lastLine);
    String message = mock.stderrMessages.single;
    String expectedMessage = new Diagnostic(
        kind, getMessage(kind), {DiagnosticParameter.target: sentence.target})
        .formatMessage();
    Expect.stringEquals('$expectedMessage\n', message);
  } else {
    Expect.isNotNull(mock.recordedError);
    Expect.equals(kind, mock.recordedError.kind);
  }
  Expect.equals(1, mock.recordedExitCode);
}

Future<MockClientController> mockCommandLine(List<String> arguments) async {
  Sentence sentence = parseSentence(arguments, includesProgramName: false);

  MockClientController client = new MockClientController(
      sentence.verb.verb, arguments);

  if (sentence.verb.verb.requiresWorker) {
    handleClientInWorker(pool, client);
    await client.done;
  } else {
    await handleVerbHere(sentence, client, pool);
    if (sentence.verb.verb.requiresSession) {
      await client.done;
    }
  }

  return client;
}

@proxy
class MockClientController implements ClientController {
  InputError recordedError;

  int recordedExitCode;

  final ClientLogger log = new MockClientLogger();

  final Verb mockVerb;

  final List<String> mockArguments;

  final Completer mockCompleter = new Completer();

  final List<String> stderrMessages = <String>[];

  MockClientController(this.mockVerb, this.mockArguments);

  get completer => mockCompleter;

  get verb => mockVerb;

  get commands {
    return new Stream<Command>.fromIterable(
        [new Command(DriverCommand.Arguments, [null]..addAll(mockArguments))]);
  }

  get done => completer.future;

  sendCommand(Command command) {
    switch (command.code) {
      case DriverCommand.ExitCode:
        exit(command.data);
        break;

      case DriverCommand.Stderr:
        printLineOnStderr(UTF8.decode(command.data));
        break;

      case DriverCommand.Stdout:
        printLineOnStdout(UTF8.decode(command.data));
        break;

      default:
        throw "Unexpected command: ${command.code}";
    }
  }

  endSession() {
    completer.complete(null);
  }

  printLineOnStderr(line) {
    stderrMessages.add(line);
    Zone.current.parent.print('stderr: $line');
  }

  printLineOnStdout(line) {
    Zone.current.parent.print('stdout: $line');
  }

  exit(int exitCode) {
    recordedExitCode = exitCode;
  }

  int reportErrorToClient(InputError error, StackTrace stackTrace) {
    recordedError = error;
    completer.complete(null);
    return 1;
  }

  noSuchMethod(Invocation invocation) {
    // Override noSuchMethod to enable @proxy. Use as dynamic to work around
    // dart2js issue 23843.
    return super.noSuchMethod(invocation) as dynamic;
  }
}

@proxy
class MockClientLogger implements ClientLogger {
  static int clientsAllocated = 0;

  final int id = clientsAllocated++;

  void note(object) {
    print("$id: $object");
  }

  void gotArguments(_) {
  }

  void done() {
  }

  void error(error, StackTrace stackTrace) {
    throw error;
  }

  noSuchMethod(Invocation invocation) {
    // Override noSuchMethod to enable @proxy. Use as dynamic to work around
    // dart2js issue 23843.
    return super.noSuchMethod(invocation) as dynamic;
  }
}
