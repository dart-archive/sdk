// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async' show
    Completer,
    Future,
    StreamController,
    Zone;

import 'dart:convert' show
    LineSplitter,
    UTF8;

import 'package:expect/expect.dart' show
    Expect;

import 'package:dartino_compiler/src/diagnostic.dart';

import 'package:dartino_compiler/src/messages.dart';

import 'package:dartino_compiler/src/message_examples.dart';

import 'package:dartino_compiler/src/hub/sentence_parser.dart' show
    NamedTarget,
    Sentence,
    parseSentence;

import 'package:dartino_compiler/src/hub/hub_main.dart' show
    ClientLogger,
    ClientCommandSender,
    ClientConnection,
    IsolatePool,
    handleVerb;

import 'package:dartino_compiler/src/worker/worker_main.dart' show
    workerMain;

import 'package:dartino_compiler/src/hub/session_manager.dart' show
    endAllSessions;

import 'package:dartino_compiler/src/hub/client_commands.dart' show
    ClientCommand,
    ClientCommandCode;

import 'package:dartino_compiler/src/verbs/infrastructure.dart' show
    AnalyzedSentence,
    Options,
    analyzeSentence;

import 'package:dartino_compiler/src/worker/developer.dart' show
    parseSettings,
    parseDevice;

import 'package:dartino_compiler/src/guess_configuration.dart' show
    dartinoVersion;

import 'package:dartino_compiler/src/hub/analytics.dart';

final IsolatePool pool = new IsolatePool(workerMain);

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
  } else if (example is DeviceExample) {
    checkDeviceConfigurationExample(kind, example);
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

void checkDeviceConfigurationExample(
    DiagnosticKind kind, DeviceExample example) {
  Uri mockUri = new Uri(scheme: "org.dartlang.tests.mock");
  Uri mockUri2 = new Uri(scheme: "org.dartlang.tests.mock2");
  try {
    parseDevice(example.data, mockUri, mockUri2);
    throw "Device configuration example: '${example.data}' "
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
    MockClientConnection mock = await mockCommandLine(setup);
    await mock.done;
    Expect.isNull(mock.recordedError);
    Expect.equals(0, mock.recordedExitCode);
  }
  MockClientConnection mock = await mockCommandLine(lastLine);
  if (kind == DiagnosticKind.socketVmConnectError) {
    await mock.done;
    Options options = Options.parse(lastLine);
    Sentence sentence = parseSentence(options.nonOptionArguments);
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
  } else {
    Expect.isNotNull(mock.recordedError);
    Expect.equals(kind, mock.recordedError.kind, '${mock.recordedError}');
    // Ensure that the diagnostic can be turned into a formatted error message.
    String message = mock.recordedError.asDiagnostic().formatMessage();
    Expect.isNotNull(message);
  }
  Expect.equals(1, mock.recordedExitCode);
}

Future<MockClientConnection> mockCommandLine(List<String> arguments) async {
  print("Command line: ${arguments.join(' ')}");
  MockClientConnection client = new MockClientConnection();
  List<String> mainArgs =
    [dartinoVersion, '/current/dir', 'detached', '01234', null]
      ..addAll(arguments);
  await handleVerb(mainArgs, client, null, pool);
  return client;
}

class MockClientConnection implements ClientConnection {
  InputError recordedError;

  int recordedExitCode;

  final ClientLogger log = new MockClientLogger();

  final Completer mockCompleter = new Completer();

  final bool debug;

  final List<String> stderrMessages = <String>[];

  List<String> stdoutMessages;

  final StreamController<ClientCommand> controller =
      new StreamController<ClientCommand>();

  final Analytics analytics;

  ClientCommandSender commandSender;

  AnalyzedSentence sentence;

  MockClientConnection({bool shouldPromptForOptIn: false, this.debug: false})
      : analytics = new MockAnalytics(
          shouldPromptForOptInValue: shouldPromptForOptIn) {
    commandSender = new MockClientCommandSender(this);
  }

  get completer => mockCompleter;

  get done => completer.future;

  get commands => controller.stream;

  void sendCommandToWorker(ClientCommand command) {
    controller.add(command);
  }

  sendCommandToClient(ClientCommand command) {
    switch (command.code) {
      case ClientCommandCode.ExitCode:
        exit(command.data);
        break;

      case ClientCommandCode.Stderr:
        printLineOnStderr(mockStripNewline(UTF8.decode(command.data)));
        break;

      case ClientCommandCode.Stdout:
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
    if (!debug) return;
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
    stdoutMessages?.add(line);
    mockPrintLine('stdout: $line');
  }

  exit(int exitCode) {
    recordedExitCode = exitCode;
    if (!completer.isCompleted) {
      endSession();
    }
  }

  int reportErrorToClient(InputError error, StackTrace stackTrace) {
    recordedError = error;
    completer.complete(null);
    return 1;
  }

  AnalyzedSentence parseArguments(String version, String currentDirectory,
      bool interactive, List<String> arguments) {
    Options options = Options.parse(arguments);
    Sentence sentence = parseSentence(options.nonOptionArguments,
        version: version,
        currentDirectory: currentDirectory,
        interactive: interactive);
    this.sentence = analyzeSentence(sentence, null);
    return this.sentence;
  }

  handleClientCommand(_) => throw "not supported";
  handleClientCommandError(e, s) => throw "not supported";
  handleClientCommandsDone() => throw "not supported";
  promptUser(_) => throw "not supported";
  start() => throw "not supported";
  get arguments => throw "not supported";
  get argumentsCompleter => throw "not supported";
  set argumentsCompleter(_) => throw "not supported";
  set completer(_) => throw "not supported";
  get dartinoVm => throw "not supported";
  set dartinoVm(_) => throw "not supported";
  get requiresWorker => throw "not supported";
  get responseCompleter => throw "not supported";
  set responseCompleter(_) => throw "not supported";
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

class MockAnalytics implements Analytics {
  final bool shouldPromptForOptInValue;
  MockAnalytics({this.shouldPromptForOptInValue: false});
  int optInCount = 0;
  get hasOptedIn => false;
  get hasOptedOut => true;
  get shouldPromptForOptIn => shouldPromptForOptInValue;
  set shouldPromptForOptIn(_) => throw "not supported";
  get serverUrl => throw "not supported";
  get uuid => null;
  get uuidUri => null;
  clearUuid() => throw "not supported";
  hash(String original) => throw "not supported";
  hashAllUris(List<String> words) => throw "not supported";
  hashUri(String str) => throw "not supported";
  hashUriWords(String stringOfWords) => throw "not supported";
  loadUuid() => throw "not supported";
  logComplete(int exitCode) { /* ignored */ }
  logError(error, [StackTrace stackTrace]) { /* ignored */ }
  logErrorMessage(String userErrMsg) { /* ignored */ }
  logRequest(String version, String currentDirectory, bool interactive,
      String startTimeMillis, List<String> arguments) { /* ignored */ }
  logResponse(String responseType, List<String> arguments) { /* ignored */}
  logShutdown() { /* ignored */ }
  logStartup() { /* ignored */ }
  logVersion() { /* ignored */ }
  readUuid() => throw "not supported";
  shutdown() async { /* ignored */ }
  bool writeNewUuid() {
    ++optInCount;
    return true;
  }
  bool writeOptOut() {
    --optInCount;
    return true;
  }
  writeUuid() => throw "not supported";
}

class MockClientCommandSender implements ClientCommandSender {
  final MockClientConnection mockClientConnection;
  final StreamController<List<int>> mockOut = new StreamController();
  final StreamController<List<int>> mockErr = new StreamController();

  MockClientCommandSender(MockClientConnection clientConnection)
      : mockClientConnection = clientConnection {
    mockOut.stream
        .transform(UTF8.decoder)
        .transform(new LineSplitter())
        .listen(mockClientConnection.printLineOnStdout);
    mockErr.stream
        .transform(UTF8.decoder)
        .transform(new LineSplitter())
        .listen(mockClientConnection.printLineOnStderr);
  }

  void sendClose() => throw "not supported";
  void sendDataCommand(ClientCommandCode code, List<int> data) =>
      throw "not supported";
  void sendEventLoopStarted() => throw "not supported";
  void sendExitCode(int exitCode) {
    mockClientConnection.printLineOnStdout('Exit code sent: $exitCode');
  }
  void sendStderr(String data) => throw "not supported";
  void sendStderrBytes(List<int> data) => mockErr.add(data);
  void sendStdout(String data) => throw "not supported";
  void sendStdoutBytes(List<int> data) => mockOut.add(data);
  Sink<List<int>> get sink => null;
}
