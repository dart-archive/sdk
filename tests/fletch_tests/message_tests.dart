// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async' show
    Completer,
    Future,
    Stream,
    StreamController,
    Zone;

import 'dart:convert' show
    UTF8;

import 'package:expect/expect.dart' show
    Expect;

import 'package:fletchc/src/diagnostic.dart';

import 'package:fletchc/src/messages.dart';

import 'package:fletchc/src/message_examples.dart';

import 'package:fletchc/src/driver/sentence_parser.dart' show
    NamedTarget,
    Sentence,
    parseSentence;

import 'package:fletchc/src/verbs/actions.dart' show
    Action;

import 'package:fletchc/src/driver/driver_main.dart' show
    ClientController,
    ClientLogger,
    IsolatePool,
    handleVerb;

import 'package:fletchc/src/driver/driver_isolate.dart' show
    isolateMain;

import 'package:fletchc/src/driver/session_manager.dart' show
    endAllSessions;

import 'package:fletchc/src/driver/driver_commands.dart' show
    Command,
    DriverCommand;

import 'package:fletchc/src/verbs/infrastructure.dart' show
    AnalyzedSentence,
    analyzeSentence;

import 'package:fletchc/src/driver/developer.dart' show
    parseSettings;

final IsolatePool pool = new IsolatePool(isolateMain);

Future<Null> main() async {
  for (DiagnosticKind kind in DiagnosticKind.values) {
    Expect.isNotNull(getMessage(kind), "$kind");

    List<Example> examples = getExamples(kind);
    Expect.isNotNull(examples, "$kind");
    Expect.isFalse(examples.isEmpty, "$kind");
    int exampleCount = 1;
    for (Example example in examples) {
      print("\n\nTesting $kind ${exampleCount++}");
      Expect.isNotNull(example);
      await checkExample(kind, example);
      endAllSessions();
      pool.shutdown();
    }
    print("Done testing $kind");
  }
}

Future<Null> checkExample(DiagnosticKind kind, Example example) async {
  if (example is CommandLineExample) {
    await checkCommandLineExample(kind, example);
  } else if (example is SettingsExample) {
    checkSettingsExample(kind, example);
  } else if (example is Untestable) {
    // Ignored.
  } else {
    throw "Unknown kind of example: $example";
  }
}

void checkSettingsExample(DiagnosticKind kind, SettingsExample example) {
  Uri mockUri = new Uri(scheme: "org.dartlang.tests.mock");
  try {
    parseSettings(example.data, mockUri);
    throw "Settings example: '${example.data}' "
        "didn't produce the expected '$kind' error";
  } on InputError catch (e) {
    Expect.isNotNull(e);
    Expect.equals(kind, e.kind, '$e');
    // Ensure that the diagnostic can be turned into a formatted error message.
    String message = e.asDiagnostic().formatMessage();
    Expect.isNotNull(message);
  }
}

Future<Null> checkCommandLineExample(
    DiagnosticKind kind,
    CommandLineExample example) async {
  List<List<String>> lines = <List<String>>[];
  if (example.line1 != null) {
    lines.add(example.line1);
  }
  if (example.line2 != null) {
    lines.add(example.line2);
  }
  if (example.line3 != null) {
    lines.add(example.line3);
  }
  List<String> lastLine = lines.removeLast();
  for (List<String> setup in lines) {
    MockClientController mock = await mockCommandLine(setup);
    await mock.done;
    Expect.isNull(mock.recordedError);
    Expect.equals(0, mock.recordedExitCode);
  }
  MockClientController mock = await mockCommandLine(lastLine);
  if (kind == DiagnosticKind.socketVmConnectError) {
    await mock.done;
    Sentence sentence = parseSentence(lastLine);
    NamedTarget target = sentence.targets.single;
    String message = mock.stderrMessages.single;
    String expectedMessage = new Diagnostic(
        kind, getMessage(kind),
        {DiagnosticParameter.address: target.name,
         DiagnosticParameter.message: '.*'})
        .formatMessage();
    Expect.stringEquals(
        message,
        new RegExp(expectedMessage).stringMatch(message));
  } else if (kind == DiagnosticKind.attachToVmBeforeRun) {
    await mock.done;
    Expect.stringEquals(getMessage(kind), mock.stderrMessages.single);
  } else {
    Expect.isNotNull(mock.recordedError);
    Expect.equals(kind, mock.recordedError.kind, '${mock.recordedError}');
    // Ensure that the diagnostic can be turned into a formatted error message.
    String message = mock.recordedError.asDiagnostic().formatMessage();
    Expect.isNotNull(message);
  }
  Expect.equals(1, mock.recordedExitCode);
}

Future<MockClientController> mockCommandLine(List<String> arguments) async {
  print("Command line: ${arguments.join(' ')}");
  Sentence sentence = parseSentence(arguments, includesProgramName: false);
  MockClientController client = new MockClientController();
  await handleVerb(arguments, client, pool);
  return client;
}

class MockClientController implements ClientController {
  InputError recordedError;

  int recordedExitCode;

  final ClientLogger log = new MockClientLogger();

  final Completer mockCompleter = new Completer();

  final List<String> stderrMessages = <String>[];

  final StreamController<Command> controller = new StreamController<Command>();

  AnalyzedSentence sentence;

  MockClientController();

  get completer => mockCompleter;

  get done => completer.future;

  get commands => controller.stream;

  void enqueCommandToWorker(Command command) {
    controller.add(command);
  }

  sendCommand(Command command) {
    switch (command.code) {
      case DriverCommand.ExitCode:
        exit(command.data);
        break;

      case DriverCommand.Stderr:
        printLineOnStderr(mockStripNewline(UTF8.decode(command.data)));
        break;

      case DriverCommand.Stdout:
        printLineOnStdout(mockStripNewline(UTF8.decode(command.data)));
        break;

      default:
        throw "Unexpected command: ${command.code}";
    }
  }

  mockStripNewline(String line) {
    if (line.endsWith("\n")) {
      return line.substring(0, line.length - 1);
    } else {
      return line;
    }
  }

  endSession() {
    completer.complete(null);
  }

  mockPrintLine(String line) {
    Zone zone = Zone.current.parent;
    if (zone == null) {
      zone = Zone.current;
    }
    zone.print(line);
  }

  printLineOnStderr(line) {
    stderrMessages.add(line);
    mockPrintLine('stderr: $line');
  }

  printLineOnStdout(line) {
    mockPrintLine('stdout: $line');
  }

  exit(int exitCode) {
    recordedExitCode = exitCode;
  }

  int reportErrorToClient(InputError error, StackTrace stackTrace) {
    recordedError = error;
    completer.complete(null);
    return 1;
  }

  AnalyzedSentence parseArguments(List<String> arguments) {
    Sentence sentence = parseSentence(arguments);
    this.sentence = analyzeSentence(sentence);
    return this.sentence;
  }

  handleCommand(_) => throw "not supported";
  handleCommandError(e, s) => throw "not supported";
  handleCommandsDone() => throw "not supported";
  start() => throw "not supported";
  get arguments => throw "not supported";
  get argumentsCompleter => throw "not supported";
  set argumentsCompleter(_) => throw "not supported";
  get commandSender => throw "not supported";
  set commandSender(_) => throw "not supported";
  set completer(_) => throw "not supported";
  get fletchVm => throw "not supported";
  set fletchVm(_) => throw "not supported";
  get requiresWorker => throw "not supported";
  get socket => throw "not supported";
  get subscription => throw "not supported";
  set subscription(_) => throw "not supported";
}

class MockClientLogger implements ClientLogger {
  static int clientsAllocated = 0;

  final int id = clientsAllocated++;

  void note(object) {
    print("$id: $object");
    gotArguments(null); // Removes an "unused" warning from dart2js.
  }

  void gotArguments(_) {
  }

  void done() {
  }

  void error(error, StackTrace stackTrace) {
    throw error;
  }

  get arguments => throw "not supported";
  set arguments(_) => throw "not supported";
  get notes => throw "not supported";
}
