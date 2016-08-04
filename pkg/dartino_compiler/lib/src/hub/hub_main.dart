// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.hub_main;

import 'dart:collection' show
    Queue;

import 'dart:io' hide
    exitCode,
    stderr,
    stdin,
    stdout;

import 'dart:io' as io;

import 'dart:async' show
    Completer,
    Stream,
    StreamController,
    StreamSubscription,
    StreamTransformer;

import 'dart:typed_data' show
    ByteData;

import 'dart:convert' show
    UTF8;

import 'dart:isolate' show
    Isolate,
    ReceivePort,
    SendPort;

import '../zone_helper.dart' show
    acknowledgeControlMessages,
    runGuarded;

import 'exit_codes.dart' show
    COMPILER_EXITCODE_CRASH,
    DART_VM_EXITCODE_COMPILE_TIME_ERROR;

import 'client_commands.dart' show
    ClientCommandCode,
    handleSocketErrors;

import '../worker/worker_main.dart' show
    workerMain;

import '../verbs/infrastructure.dart';

import 'sentence_parser.dart' show
    Sentence,
    parseSentence;

import '../diagnostic.dart' show
    InputError,
    throwInternalError;

import '../shared_command_infrastructure.dart' show
    CommandBuffer,
    CommandTransformerBuilder,
    commandEndianness,
    toUint8ListView;

import '../worker/developer.dart' show
    allocateWorker,
    combineTasks,
    configFileUri;

import 'session_manager.dart' show
    lookupSession;

import '../verbs/create_verb.dart' show
    CreateSessionTask;

import '../please_report_crash.dart' show
    crashReportRequested,
    requestBugReportOnOtherCrashMessage;

import '../verbs/options.dart' show
    Options,
    isBatchMode;

import '../console_print.dart' show
    printToConsole;

import '../please_report_crash.dart' show
    stringifyError;

import 'analytics.dart' show
    Analytics;

Function gracefulShutdown;

final List<String> mainArguments = <String>[];

class ClientCommandTransformerBuilder
    extends CommandTransformerBuilder<ClientCommand> {
  ClientCommand makeCommand(int commandCode, ByteData payload) {
    ClientCommandCode code = ClientCommandCode.values[commandCode];
    switch (code) {
      case ClientCommandCode.Arguments:
        return new ClientCommand(code, decodeArgumentsCommand(payload));

      case ClientCommandCode.Stdin:
        int length = payload.getUint32(0, commandEndianness);
        return new ClientCommand(code, toUint8ListView(payload, 4, length));

      case ClientCommandCode.Signal:
        int signal = payload.getUint32(0, commandEndianness);
        return new ClientCommand(code, signal);

      default:
        return null;
    }
  }

  List<String> decodeArgumentsCommand(ByteData view) {
    int offset = 0;
    int argc = view.getUint32(offset, commandEndianness);
    offset += 4;
    List<String> argv = <String>[];
    for (int i = 0; i < argc; i++) {
      int length = view.getUint32(offset, commandEndianness);
      offset += 4;
      argv.add(UTF8.decode(toUint8ListView(view, offset, length)));
      offset += length;
    }
    return argv;
  }
}

// Class for sending client commands from the hub (main isolate) to the
// dartino c++ client.
class ClientCommandSender extends CommandSender {
  final Sink<List<int>> sink;

  ClientCommandSender(this.sink);

  void sendExitCode(int exitCode) {
    new CommandBuffer<ClientCommandCode>()
        ..addUint32(exitCode)
        ..sendOn(sink, ClientCommandCode.ExitCode);
  }

  void sendDataCommand(ClientCommandCode code, List<int> data) {
    new CommandBuffer<ClientCommandCode>()
        ..addUint32(data.length)
        ..addUint8List(data)
        ..sendOn(sink, code);
  }

  void sendClose() {
    throwInternalError("Client (C++) doesn't support ClientCommandCode.Close.");
  }

  void sendEventLoopStarted() {
    throwInternalError(
        "Client (C++) doesn't support ClientCommandCode.EventLoopStarted.");
  }
}

Future main(List<String> arguments) async {
  // When running this program, -Ddartino.version must be provided on the Dart
  // VM command line.
  assert(const String.fromEnvironment('dartino.version') != null);

  mainArguments.addAll(arguments);
  configFileUri = Uri.base.resolve(arguments.first);
  File configFile;
  if (!isBatchMode) {
    configFile = new File.fromUri(configFileUri);
  }
  ServerSocket server;

  Completer shutdown = new Completer();

  Analytics analytics = new Analytics(printToConsole);

  gracefulShutdown = () {
    if (analytics != null) {
      analytics.shutdown();
      analytics = null;
    }
    if (server != null) {
      server.close();
    }
    if (!shutdown.isCompleted) {
      shutdown.complete();
    }
  };

  void handleSignal(StreamSubscription<ProcessSignal> subscription) {
    subscription.onData((ProcessSignal signal) {
      // Cancel the subscription to restore default signal handler.
      subscription.cancel();
      print("Received signal $signal, sending signal to pid 0");
      print("Our pid was: ${io.pid}");
      gracefulShutdown();
      // 0 means kill the current process group (including this process, which
      // will now die as we restored the default signal handler above).  In
      // addition, killing this process ensures that any processes waiting for
      // it will observe that it was killed due to a signal. There's no way to
      // fake that status using exit.
      Process.killPid(0, signal);
    });
    shutdown.future.then((_) {
      subscription.cancel();
    });
  }

  // When receiving SIGTERM or gracefully shut down.
  handleSignal(ProcessSignal.SIGTERM.watch().listen(null));
  handleSignal(ProcessSignal.SIGINT.watch().listen(null));

  server = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);

  if (configFile != null) {
    // Write the TCP port to a config file. This lets multiple command line
    // programs share this persistent driver process, which in turn eliminates
    // start up overhead.
    configFile.writeAsStringSync("${server.port}", flush: true);
  }

  // Print the temporary directory so the launching process knows where to
  // connect, and that the socket is ready.
  print(server.port);

  IsolatePool pool = new IsolatePool(workerMain);
  try {
    analytics.loadUuid();
    analytics.logStartup();
    await server.listen((Socket controlSocket) {
      if (isBatchMode) {
        server.close();
      }
      handleSocketErrors(controlSocket, "controlSocket");
      handleClient(pool, analytics, controlSocket);
    }).asFuture();
  } finally {
    gracefulShutdown();
  }
}

Future<Null> handleClient(IsolatePool pool, Analytics analytics,
    Socket controlSocket) async {
  ClientLogger log = ClientLogger.allocate();

  ClientConnection clientConnection =
      new ClientConnection(controlSocket, analytics, log)..start();
  List<String> arguments = await clientConnection.arguments;
  log.gotArguments(arguments);

  await handleVerb(arguments, clientConnection, analytics, pool);
}

Future<Null> handleVerb(
    List<String> arguments,
    ClientConnection clientConnection,
    Analytics analytics,
    IsolatePool pool) async {
  crashReportRequested = false;

  Future<int> performVerb() async {

    // Extract additional information passed by driver/main.cc
    String version = arguments[0];
    String currentDirectory = arguments[1];
    // "interactive" indicating that a user is typing
    // or "detached" indicating that dartino is executed as part of a script
    bool interactive;
    if (arguments[2] == 'interactive') {
      interactive = true;
    } else if (arguments[2] == 'detached') {
      interactive = false;
    } else {
      // Fast fail if arguments do not meet expectations.
      throw 'unexpected arguments from driver';
    }
    String startTimeMillis = arguments[3];
    // arguments[4] is the program name and is ignored
    List<String> remaining = arguments.sublist(5);

    analytics?.logRequest(
        version, currentDirectory, interactive, startTimeMillis, remaining);
    clientConnection.parseArguments(
        version, currentDirectory, interactive, remaining);
    String sessionName = clientConnection.sentence.sessionName;
    UserSession session;
    SharedTask initializer;
    if (sessionName != null) {
      session = lookupSession(sessionName);
      if (session == null) {
        session = await createSession(sessionName, () => allocateWorker(pool));
        initializer = new CreateSessionTask(
            sessionName, null, clientConnection.sentence.base);
      }
    }
    ClientVerbContext context = new ClientVerbContext(
        clientConnection, pool, session, initializer: initializer);
    return await clientConnection.sentence.performVerb(context);
  }

  int exitCode = await runGuarded(
      performVerb,
      printLineOnStdout: clientConnection.printLineOnStdout,
      handleLateError: clientConnection.log.error)
      .catchError(
          clientConnection.reportErrorToClient, test: (e) => e is InputError)
      .catchError((error, StackTrace stackTrace) {
        analytics?.logError(error, stackTrace);
        if (!crashReportRequested) {
          clientConnection.printLineOnStderr(
              requestBugReportOnOtherCrashMessage);
          crashReportRequested = true;
        }
        clientConnection.printLineOnStderr('$error');
        if (stackTrace != null) {
          clientConnection.printLineOnStderr('$stackTrace');
        }
        return COMPILER_EXITCODE_CRASH;
      });
  analytics?.logComplete(exitCode);
  clientConnection.exit(exitCode);
}

class ClientVerbContext extends VerbContext {
  SharedTask initializer;

  ClientVerbContext(
      ClientConnection clientConnection,
      IsolatePool pool,
      UserSession session,
      {this.initializer})
      : super(clientConnection, pool, session);

  ClientVerbContext copyWithSession(UserSession session) {
    return new ClientVerbContext(clientConnection, pool, session);
  }

  Future<int> performTaskInWorker(SharedTask task) async {
    if (session.worker.isolate.wasKilled) {
      throwInternalError(
          "session ${session.name}: worker isolate terminated unexpectedly");
    }
    if (session.hasActiveWorkerTask) {
      throwFatalError(DiagnosticKind.busySession, sessionName: session.name);
    }
    session.hasActiveWorkerTask = true;
    return session.worker.performTask(
        combineTasks(initializer, task), clientConnection, userSession: session)
        .whenComplete(() {
          session.hasActiveWorkerTask = false;
        });
  }
}

/// Handles communication with the Dartino C++ client.
class ClientConnection {
  /// Socket used for receiving and sending commands from/to the Dartino C++
  /// client.
  final Socket socket;

  /// Controller used to send commands to the from the ClientConnection to
  /// anyone listening on ClientConnection.commands (see [commands] below). The
  /// only listener as of now is the WorkerConnection which typically forwards
  /// the commands to the worker isolate.
  final StreamController<ClientCommand> controller =
      new StreamController<ClientCommand>();

  final ClientLogger log;

  final Analytics analytics;

  /// The commandSender is used to send commands back to the Dartino C++ client.
  ClientCommandSender commandSender;

  StreamSubscription<ClientCommand> subscription;
  Completer<Null> completer;

  Completer<List<String>> argumentsCompleter = new Completer<List<String>>();

  /// The analysed version of the request from the client.
  /// Updated by [parseArguments].
  AnalyzedSentence sentence;

  /// The completer used to process a response from the client
  /// or `null` if no response is expected.
  Completer<String> responseCompleter;

  ClientConnection(this.socket, this.analytics, this.log);

  /// Stream of commands from the Dartino C++ client to the hub (main isolate).
  /// The commands are typically forwarded to a worker isolate, see
  /// handleClientCommand.
  Stream<ClientCommand> get commands => controller.stream;

  /// Completes when [endSession] is called.
  Future<Null> get done => completer.future;

  /// Completes with the command-line arguments from the client.
  Future<List<String>> get arguments => argumentsCompleter.future;

  /// Start processing commands from the client.
  void start() {
    // Setup a command sender used to send responses from the hub (main isolate)
    // back to the Dartino C++ client.
    commandSender = new ClientCommandSender(socket);

    // Setup a listener for handling commands coming from the Dartino C++
    // client.
    StreamTransformer<List<int>, ClientCommand> transformer =
        new ClientCommandTransformerBuilder().build();
    subscription = socket.transform(transformer).listen(null);
    subscription
        ..onData(handleClientCommand)
        ..onError(handleClientCommandError)
        ..onDone(handleClientCommandsDone);
    completer = new Completer<Null>();
  }

  void handleClientCommand(ClientCommand command) {
    if (command.code == ClientCommandCode.Arguments) {
      // This intentionally throws if arguments are sent more than once.
      argumentsCompleter.complete(command.data);
    } else if (responseCompleter != null) {
      if (command.code == ClientCommandCode.Stdin) {
        responseCompleter.complete(UTF8.decode(command.data));
        responseCompleter = null;
      }
    } else {
      sendCommandToWorker(command);
    }
  }

  /// Prompt the user and return a future that completes with the response.
  Future<String> promptUser(String promptText) {
    if (responseCompleter != null) {
      throwInternalError("Already waiting for user response");
    }
    // Print without the trailing newline character.
    commandSender.sendStdout(promptText);
    responseCompleter = new Completer<String>();
    return responseCompleter.future;
  }

  void sendCommandToWorker(ClientCommand command) {
    // TODO(ahe): It is a bit weird that this method is on the client proxy.
    // Ideally, this would be a method on WorkerConnection. However the client
    // is created before the WorkerConnection which is not created until/if
    // needed. The WorkerConnection will start listening to the client's
    // commands when attaching, see WorkerConnection.attachClient.
    controller.add(command);
  }

  void handleClientCommandError(error, StackTrace trace) {
    print(stringifyError(error, trace));
    completer.completeError(error, trace);
    // Cancel the subscription if an error occurred, this prevents
    // [handleCommandsDone] from being called and attempt to complete
    // [completer].
    subscription.cancel();
  }

  void handleClientCommandsDone() {
    completer.complete();
  }

  // Send a command back to the Dartino C++ client.
  void sendCommandToClient(ClientCommand command) {
    switch (command.code) {
      case ClientCommandCode.Stdout:
        commandSender.sendStdoutBytes(command.data);
        break;

      case ClientCommandCode.Stderr:
        commandSender.sendStderrBytes(command.data);
        break;

      case ClientCommandCode.ExitCode:
        commandSender.sendExitCode(command.data);
        break;

      default:
        throwInternalError("Unexpected command: $command");
    }
  }

  void endSession() {
    socket.flush().then((_) {
      socket.close();
    });
  }

  void printLineOnStderr(String line) {
    commandSender.sendStderrBytes(UTF8.encode("$line\n"));
  }

  void printLineOnStdout(String line) {
    commandSender.sendStdoutBytes(UTF8.encode('$line\n'));
  }

  void exit(int exitCode) {
    if (exitCode == null) {
      exitCode = COMPILER_EXITCODE_CRASH;
      try {
        throwInternalError("Internal error: exitCode is null");
      } on InputError catch (error, stackTrace) {
        // We can't afford to throw an error here as it will take down the
        // entire process.
        exitCode = reportErrorToClient(error, stackTrace);
      }
    }
    commandSender.sendExitCode(exitCode);
    endSession();
  }

  AnalyzedSentence parseArguments(String version, String currentDirectory,
      bool interactive, List<String> arguments) {
    Options options = Options.parse(arguments);
    Sentence sentence = parseSentence(options.nonOptionArguments,
        version: version,
        currentDirectory: currentDirectory,
        interactive: interactive);
    this.sentence = analyzeSentence(sentence, options);
    return this.sentence;
  }

  int reportErrorToClient(InputError error, StackTrace stackTrace) {
    analytics?.logError(error, stackTrace);
    bool isInternalError = error.kind == DiagnosticKind.internalError;
    if (isInternalError && !crashReportRequested) {
      printLineOnStderr(requestBugReportOnOtherCrashMessage);
      crashReportRequested = true;
    }
    String userErrMsg = error.asDiagnostic().formatMessage();
    analytics?.logErrorMessage(userErrMsg);
    printLineOnStderr(userErrMsg);
    if (isInternalError) {
      printLineOnStderr('$stackTrace');
      return COMPILER_EXITCODE_CRASH;
    } else {
      return DART_VM_EXITCODE_COMPILE_TIME_ERROR;
    }
  }
}

/// The WorkerConnection represents a worker isolate in the hub (main isolate).
/// Ie. it is the hub's object for communicating with a worker isolate.
class WorkerConnection {
  /// The worker isolate.
  final ManagedIsolate isolate;

  /// A port used to send commands to the worker isolate.
  SendPort sendPort;

  /// A port used to read commands from the worker isolate.
  ReceivePort receivePort;

  /// workerCommands is an iterator over all the commands coming from the
  /// worker isolate. These are typically the outbound messages destined for
  /// the Dartino C++ client.
  /// It iterates over the data coming on the receivePort.
  StreamIterator<ClientCommand> workerCommands;

  /// When true, the worker can be shutdown by sending it a
  /// ClientCommandCode.Signal command.  Otherwise, it must be killed.
  bool eventLoopStarted = false;

  /// Subscription for errors from [isolate].
  StreamSubscription errorSubscription;

  bool crashReportRequested = false;

  WorkerConnection(this.isolate);

  /// Begin a session with the worker isolate.
  Future<Null> beginSession() async {
    errorSubscription = isolate.errors.listen(null);
    errorSubscription.pause();
    receivePort = isolate.beginSession();
    // Setup the workerCommands iterator using a stream converting the
    // incoming data to [ClientCommand]s.
    Stream<ClientCommand> workerCommandStream = receivePort.map(
        (message) => new ClientCommand(
            ClientCommandCode.values[message[0]], message[1]));
    workerCommands = new StreamIterator<ClientCommand>(workerCommandStream);
    if (!await workerCommands.moveNext()) {
      // The worker must have been killed, or died in some other way.
      // TODO(ahe): Add this assertion: assert(isolate.wasKilled);
      endSession();
      return;
    }
    ClientCommand command = workerCommands.current;
    assert(command.code == ClientCommandCode.SendPort);
    assert(command.data != null);
    sendPort = command.data;
  }

  /// Attach to a dartino C++ client and forward commands to the worker isolate,
  /// and vice versa.  The returned future normally completes when the worker
  /// isolate sends ClientCommandCode.ClosePort, or if the isolate is killed due
  /// to ClientCommandCode.Signal arriving through client.commands.
  Future<int> attachClient(
      ClientConnection clientConnection,
      UserSession userSession) async {

    // Method for handling commands coming from the client. The commands are
    // typically forwarded to the worker isolate.
    handleCommandsFromClient(ClientCommand command) {
      if (command.code == ClientCommandCode.Signal && !eventLoopStarted) {
        if (userSession != null) {
          userSession.kill(clientConnection.printLineOnStderr);
        } else {
          isolate.kill();
        }
        receivePort.close();
      } else {
        sendPort.send([command.code.index, command.data]);
      }
    }

    // Method for handling commands coming back from the worker isolate.
    // It typically forwards them to the Dartino C++ client via the
    // clientConnection.
    Future<int> handleCommandsFromWorker(
        ClientConnection clientConnection) async {
      int exitCode = COMPILER_EXITCODE_CRASH;
      while (await workerCommands.moveNext()) {
        ClientCommand command = workerCommands.current;
        switch (command.code) {
          case ClientCommandCode.ClosePort:
            receivePort.close();
            break;

          case ClientCommandCode.EventLoopStarted:
            eventLoopStarted = true;
            break;

          case ClientCommandCode.ExitCode:
            exitCode = command.data;
            break;

          default:
            clientConnection.sendCommandToClient(command);
            break;
        }
      }
      return exitCode;
    }

    eventLoopStarted = false;
    crashReportRequested = false;
    errorSubscription.onData((errorList) {
      String error = errorList[0];
      String stackTrace = errorList[1];
      if (!crashReportRequested) {
        clientConnection.printLineOnStderr(requestBugReportOnOtherCrashMessage);
        crashReportRequested = true;
      }
      clientConnection.printLineOnStderr(error);
      if (stackTrace != null) {
        clientConnection.printLineOnStderr(stackTrace);
      }
      if (userSession != null) {
        userSession.kill(clientConnection.printLineOnStderr);
      } else {
        isolate.kill();
      }
      receivePort.close();
    });
    errorSubscription.resume();

    // Start listening for commands coming from the Dartino C++ client (via
    // clientConnection).
    // TODO(ahe): Add onDone event handler to detach the client.
    clientConnection.commands.listen(handleCommandsFromClient);

    // Start processing commands coming from the worker.
    int exitCode = await handleCommandsFromWorker(clientConnection);

    errorSubscription.pause();
    return exitCode;
  }

  void endSession() {
    receivePort.close();
    isolate.endSession();
  }

  Future<Null> detachClient() async {
    if (isolate.wasKilled) {
      // Setting these to null will ensure that [attachClient] causes a crash
      // if called after isolate was killed.
      errorSubscription = null;
      receivePort = null;
      workerCommands = null;
      sendPort = null;

      // TODO(ahe): The session is dead. Tell the user about this.
      return null;
    }
    // TODO(ahe): Perform the reverse of attachClient here.
    if (!isBatchMode) {
      await beginSession();
    }
  }

  Future<int> performTask(
      SharedTask task,
      ClientConnection clientConnection,
      {
       UserSession userSession,
       /// End this session and return this isolate to the pool.
       bool endSession: false}) async {
    ClientLogger log = clientConnection.log;

    clientConnection.done.catchError((error, StackTrace stackTrace) {
      log.error(error, stackTrace);
    }).then((_) {
      log.done();
    });

    // Indirectly send the task to be performed to the worker isolate via the
    // clientConnection.
    clientConnection.sendCommandToWorker(
        new ClientCommand(ClientCommandCode.PerformTask, task));

    // Forward commands between the C++ dartino client [clientConnection], and
    // the worker isolate `this`.  Also, Intercept the signal command and
    // potentially kill the isolate (the isolate needs to tell if it is
    // interuptible or needs to be killed, an example of the latter is, if
    // compiler is running).
    int exitCode = await attachClient(clientConnection, userSession);
    // The verb (which was performed in the worker) is done.
    log.note("After attachClient (exitCode = $exitCode)");

    if (endSession) {
      // Return the isolate to the pool *before* shutting down the client. This
      // ensures that the next client will be able to reuse the isolate instead
      // of spawning a new.
      this.endSession();
    } else {
      await detachClient();
    }

    return exitCode;
  }
}

class ManagedIsolate {
  final IsolatePool pool;
  final Isolate isolate;
  final SendPort port;
  final Stream errors;
  final ReceivePort exitPort;
  final ReceivePort errorPort;
  bool wasKilled = false;

  ManagedIsolate(
      this.pool, this.isolate, this.port, this.errors,
      this.exitPort, this.errorPort);

  ReceivePort beginSession() {
    ReceivePort receivePort = new ReceivePort();
    port.send(receivePort.sendPort);
    return receivePort;
  }

  void endSession() {
    if (!wasKilled) {
      pool.idleIsolates.addLast(this);
    }
  }

  void kill() {
    wasKilled = true;
    isolate.kill(priority: Isolate.IMMEDIATE);
    isolate.removeOnExitListener(exitPort.sendPort);
    isolate.removeErrorListener(errorPort.sendPort);
    exitPort.close();
    errorPort.close();
  }
}

class IsolatePool {
  // Queue of idle isolates. When an isolate becomes idle, it is added at the
  // end.
  final Queue<ManagedIsolate> idleIsolates = new Queue<ManagedIsolate>();
  final Function isolateEntryPoint;

  IsolatePool(this.isolateEntryPoint);

  Future<ManagedIsolate> getIsolate({bool exitOnError: true}) async {
    if (idleIsolates.isEmpty) {
      return await spawnIsolate(exitOnError: exitOnError);
    } else {
      return idleIsolates.removeFirst();
    }
  }

  Future<ManagedIsolate> spawnIsolate({bool exitOnError: true}) async {
    StreamController errorController = new StreamController.broadcast();
    ReceivePort receivePort = new ReceivePort();
    Isolate isolate = await Isolate.spawn(
        isolateEntryPoint, receivePort.sendPort, paused: true);
    isolate.setErrorsFatal(true);
    ReceivePort errorPort = new ReceivePort();
    ManagedIsolate managedIsolate;
    isolate.addErrorListener(errorPort.sendPort);
    errorPort.listen((errorList) {
      if (exitOnError) {
        String error = errorList[0];
        String stackTrace = errorList[1];
        io.stderr.writeln(error);
        if (stackTrace != null) {
          io.stderr.writeln(stackTrace);
        }
        exit(COMPILER_EXITCODE_CRASH);
      } else {
        managedIsolate.wasKilled = true;
        errorController.add(errorList);
      }
    });
    ReceivePort exitPort = new ReceivePort();
    isolate.addOnExitListener(exitPort.sendPort);
    exitPort.listen((_) {
      isolate.removeErrorListener(errorPort.sendPort);
      isolate.removeOnExitListener(exitPort.sendPort);
      errorPort.close();
      exitPort.close();
      idleIsolates.remove(managedIsolate);
    });
    await acknowledgeControlMessages(isolate, resume: isolate.pauseCapability);
    StreamIterator iterator = new StreamIterator(receivePort);
    bool hasElement = await iterator.moveNext();
    if (!hasElement) {
      throwInternalError("No port received from isolate");
    }
    SendPort port = iterator.current;
    receivePort.close();
    managedIsolate =
        new ManagedIsolate(
            this, isolate, port, errorController.stream, exitPort, errorPort);

    return managedIsolate;
  }

  void shutdown() {
    while (idleIsolates.isNotEmpty) {
      idleIsolates.removeFirst().kill();
    }
  }
}

class ClientLogger {
  static int clientLoggersAllocated = 0;

  static Set<ClientLogger> pendingClients = new Set<ClientLogger>();

  static Set<ClientLogger> erroneousClients = new Set<ClientLogger>();

  static ClientLogger allocate() {
    ClientLogger clientLogger = new ClientLogger(clientLoggersAllocated++);
    pendingClients.add(clientLogger);
    return clientLogger;
  }

  final int id;

  final List<String> notes = <String>[];

  List<String> arguments = <String>[];

  ClientLogger(this.id);

  void note(object) {
    String note = "$object";
    notes.add(note);
    printToConsole("$id: $note");
  }

  void gotArguments(List<String> arguments) {
    this.arguments = arguments;
    note("Got arguments: ${arguments.join(' ')}.");
  }

  void done() {
    pendingClients.remove(this);
    note("Client done ($pendingClients).");
  }

  void error(error, StackTrace stackTrace) {
    // TODO(ahe): Modify quit verb to report these errors.
    erroneousClients.add(this);
    note("Crash (${arguments.join(' ')}).\n"
         "${stringifyError(error, stackTrace)}");
  }

  String toString() => "$id";
}
