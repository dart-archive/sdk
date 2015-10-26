// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver_main;

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
    ByteData,
    Endianness,
    TypedData,
    Uint8List;

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

import 'driver_commands.dart' show
    DriverCommand,
    handleSocketErrors;

import 'driver_isolate.dart' show
    isolateMain;

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
    headerSize,
    toUint8ListView;

import 'developer.dart' show
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
    Options;

import '../console_print.dart' show
    printToConsole;

import '../please_report_crash.dart' show
    stringifyError;

Function gracefulShutdown;

final List<String> mainArguments = <String>[];

class DriverCommandTransformerBuilder
    extends CommandTransformerBuilder<Command> {
  Command makeCommand(int commandCode, ByteData payload) {
    DriverCommand code = DriverCommand.values[commandCode];
    switch (code) {
      case DriverCommand.Arguments:
        return new Command(code, decodeArgumentsCommand(payload));

      case DriverCommand.Stdin:
        int length = payload.getUint32(0, commandEndianness);
        return new Command(code, toUint8ListView(payload, 4, length));

      case DriverCommand.Signal:
        int signal = payload.getUint32(0, commandEndianness);
        return new Command(code, signal);

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

class ByteCommandSender extends CommandSender {
  final Sink<List<int>> sink;

  ByteCommandSender(this.sink);

  void sendExitCode(int exitCode) {
    new CommandBuffer<DriverCommand>()
        ..addUint32(exitCode)
        ..sendOn(sink, DriverCommand.ExitCode);
  }

  void sendDataCommand(DriverCommand command, List<int> data) {
    new CommandBuffer<DriverCommand>()
        ..addUint32(data.length)
        ..addUint8List(data)
        ..sendOn(sink, command);
  }

  void sendClose() {
    throwInternalError("Client (C++) doesn't support DriverCommand.Close.");
  }

  void sendEventLoopStarted() {
    throwInternalError(
        "Client (C++) doesn't support DriverCommand.EventLoopStarted.");
  }
}

Future main(List<String> arguments) async {
  mainArguments.addAll(arguments);
  configFileUri = Uri.base.resolve(arguments.first);
  File configFile = new File.fromUri(configFileUri);
  Directory tmpdir = Directory.systemTemp.createTempSync("fletch_driver");

  File socketFile = new File("${tmpdir.path}/socket");
  try {
    socketFile.deleteSync();
  } on FileSystemException catch (e) {
    // Ignored. There's no way to check if a socket file exists.
  }

  ServerSocket server;

  Completer shutdown = new Completer();

  gracefulShutdown = () {
    try {
      socketFile.deleteSync();
    } catch (e) {
      print("Unable to delete ${socketFile.path}: $e");
    }

    try {
      tmpdir.deleteSync(recursive: true);
    } catch (e) {
      print("Unable to delete ${tmpdir.path}: $e");
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
      print("Received signal $signal");
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

  server = await ServerSocket.bind(new UnixDomainAddress(socketFile.path), 0);

  // Write the socket file to a config file. This lets multiple command line
  // programs share this persistent driver process, which in turn eliminates
  // start up overhead.
  configFile.writeAsStringSync(socketFile.path, flush: true);

  // Print the temporary directory so the launching process knows where to
  // connect, and that the socket is ready.
  print(socketFile.path);

  IsolatePool pool = new IsolatePool(isolateMain);
  try {
    await server.listen((Socket controlSocket) {
      handleClient(pool, handleSocketErrors(controlSocket, "controlSocket"));
    }).asFuture();
  } finally {
    gracefulShutdown();
  }
}

Future<Null> handleClient(IsolatePool pool, Socket controlSocket) async {
  ClientLogger log = ClientLogger.allocate();

  ClientController client = new ClientController(controlSocket, log)..start();
  List<String> arguments = await client.arguments;
  log.gotArguments(arguments);

  await handleVerb(arguments, client, pool);
}

Future<Null> handleVerb(
    List<String> arguments,
    ClientController client,
    IsolatePool pool) async {
  crashReportRequested = false;

  Future<int> performVerb() async {
    client.parseArguments(arguments);
    String sessionName = client.sentence.sessionName;
    UserSession session;
    SharedTask initializer;
    if (sessionName != null) {
      session = lookupSession(sessionName);
      if (session == null) {
        session = await createSession(sessionName, () => allocateWorker(pool));
        initializer = new CreateSessionTask(
            sessionName, null, client.sentence.base, configFileUri);
      }
    }
    DriverVerbContext context =
        new DriverVerbContext(client, pool, session, initializer: initializer);
    return await client.sentence.performVerb(context);
  }

  int exitCode = await runGuarded(
      performVerb,
      printLineOnStdout: client.printLineOnStdout,
      handleLateError: client.log.error)
      .catchError(client.reportErrorToClient, test: (e) => e is InputError)
      .catchError((error, StackTrace stackTrace) {
        if (!crashReportRequested) {
          client.printLineOnStderr(requestBugReportOnOtherCrashMessage);
          crashReportRequested = true;
        }
        client.printLineOnStderr('$error');
        if (stackTrace != null) {
          client.printLineOnStderr('$stackTrace');
        }
        return COMPILER_EXITCODE_CRASH;
      });
  client.exit(exitCode);
}

class DriverVerbContext extends VerbContext {
  SharedTask initializer;

  DriverVerbContext(
      ClientController client,
      IsolatePool pool,
      UserSession session,
      {this.initializer})
      : super(client, pool, session);

  DriverVerbContext copyWithSession(UserSession session) {
    return new DriverVerbContext(client, pool, session);
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
        combineTasks(initializer, task), client, userSession: session)
        .whenComplete(() {
          session.hasActiveWorkerTask = false;
        });
  }
}

/// Handles communication with the C++ client.
class ClientController {
  final Socket socket;

  /// Used to implement [commands].
  final StreamController<Command> controller = new StreamController<Command>();

  final ClientLogger log;

  CommandSender commandSender;
  StreamSubscription<Command> subscription;
  Completer<Null> completer;

  Completer<List<String>> argumentsCompleter = new Completer<List<String>>();

  /// The request from the client. Updated by [parseArguments].
  AnalyzedSentence sentence;

  /// Path to the fletch VM. Updated by [parseArguments].
  String fletchVm;

  ClientController(this.socket, this.log);

  /// A stream of commands from the client that should be forwarded to a worker
  /// isolate.
  Stream<Command> get commands => controller.stream;

  /// Completes when [endSession] is called.
  Future<Null> get done => completer.future;

  /// Completes with the command-line arguments from the client.
  Future<List<String>> get arguments => argumentsCompleter.future;

  /// Start processing commands from the client.
  void start() {
    commandSender = new ByteCommandSender(socket);
    StreamTransformer<List<int>, Command> transformer =
        new DriverCommandTransformerBuilder().build();
    subscription = socket.transform(transformer).listen(null);
    subscription
        ..onData(handleCommand)
        ..onError(handleCommandError)
        ..onDone(handleCommandsDone);
    completer = new Completer<Null>();
  }

  void handleCommand(Command command) {
    if (command.code == DriverCommand.Arguments) {
      // This intentionally throws if arguments are sent more than once.
      argumentsCompleter.complete(command.data);
    } else {
      enqueCommandToWorker(command);
    }
  }

  void enqueCommandToWorker(Command command) {
    // TODO(ahe): It is a bit weird that this method is on the client. Ideally,
    // this would be a method on IsolateController.
    controller.add(command);
  }

  void handleCommandError(error, StackTrace trace) {
    print(stringifyError(error, trace));
    completer.completeError(error, trace);
    // Cancel the subscription if an error occurred, this prevents
    // [handleCommandsDone] from being called and attempt to complete
    // [completer].
    subscription.cancel();
  }

  void handleCommandsDone() {
    completer.complete();
  }

  void sendCommand(Command command) {
    switch (command.code) {
      case DriverCommand.Stdout:
        commandSender.sendStdoutBytes(command.data);
        break;

      case DriverCommand.Stderr:
        commandSender.sendStderrBytes(command.data);
        break;

      case DriverCommand.ExitCode:
        commandSender.sendExitCode(command.data);
        break;

      default:
        throwInternalError("Unexpected command: $command");
    }
  }

  void endClientSession() {
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
    endClientSession();
  }

  AnalyzedSentence parseArguments(List<String> arguments) {
    Options options = Options.parse(arguments);
    Sentence sentence =
        parseSentence(options.nonOptionArguments, includesProgramName: true);
    /// [programName] is the canonicalized absolute path to the fletch
    /// executable (the C++ program).
    String programName = sentence.programName;
    String fletchVm = "$programName-vm";
    this.sentence = analyzeSentence(sentence, options);
    this.fletchVm = fletchVm;
    return this.sentence;
  }

  int reportErrorToClient(InputError error, StackTrace stackTrace) {
    bool isInternalError = error.kind == DiagnosticKind.internalError;
    if (isInternalError && !crashReportRequested) {
      printLineOnStderr(requestBugReportOnOtherCrashMessage);
      crashReportRequested = true;
    }
    printLineOnStderr(error.asDiagnostic().formatMessage());
    if (isInternalError) {
      printLineOnStderr('$stackTrace');
      return COMPILER_EXITCODE_CRASH;
    } else {
      return DART_VM_EXITCODE_COMPILE_TIME_ERROR;
    }
  }
}

/// Handles communication with a worker isolate.
class IsolateController {
  /// The worker isolate.
  final ManagedIsolate isolate;

  /// An iterator commands from the worker isolate.
  StreamIterator<Command> workerCommands;

  /// A port used to send commands to the worker isolate.
  SendPort workerSendPort;

  /// A port used to read commands from the worker isolate.
  ReceivePort workerReceivePort;

  /// When true, the worker can be shutdown by sending it a
  /// DriverCommand.Signal command.  Otherwise, it must be killed.
  bool eventLoopStarted = false;

  /// Subscription for errors from [isolate].
  StreamSubscription errorSubscription;

  bool crashReportRequested = false;

  IsolateController(this.isolate);

  /// Begin a session with the worker isolate.
  Future<Null> beginSession() async {
    errorSubscription = isolate.errors.listen(null);
    errorSubscription.pause();
    workerReceivePort = isolate.beginSession();
    Stream<Command> workerCommandStream = workerReceivePort.map(
        (message) => new Command(DriverCommand.values[message[0]], message[1]));
    workerCommands = new StreamIterator<Command>(workerCommandStream);
    if (!await workerCommands.moveNext()) {
      // The worker must have been killed, or died in some other way.
      // TODO(ahe): Add this assertion: assert(isolate.wasKilled);
      endWorkerSession();
      return;
    }
    Command command = workerCommands.current;
    assert(command.code == DriverCommand.SendPort);
    assert(command.data != null);
    workerSendPort = command.data;
  }

  /// Attach to a C++ client and forward commands to the worker isolate, and
  /// vice versa.  The returned future normally completes when the worker
  /// isolate sends DriverCommand.ClosePort, or if the isolate is killed due to
  /// DriverCommand.Signal arriving through client.commands.
  Future<int> attachClient(
      ClientController client,
      UserSession userSession) async {
    eventLoopStarted = false;
    crashReportRequested = false;
    errorSubscription.onData((errorList) {
      String error = errorList[0];
      String stackTrace = errorList[1];
      if (!crashReportRequested) {
        client.printLineOnStderr(requestBugReportOnOtherCrashMessage);
        crashReportRequested = true;
      }
      client.printLineOnStderr(error);
      if (stackTrace != null) {
        client.printLineOnStderr(stackTrace);
      }
      if (userSession != null) {
        userSession.kill(client.printLineOnStderr);
      } else {
        isolate.kill();
      }
      workerReceivePort.close();
    });
    errorSubscription.resume();
    handleCommand(Command command) {
      if (command.code == DriverCommand.Signal && !eventLoopStarted) {
        if (userSession != null) {
          userSession.kill(client.printLineOnStderr);
        } else {
          isolate.kill();
        }
        workerReceivePort.close();
      } else {
        workerSendPort.send([command.code.index, command.data]);
      }
    }
    // TODO(ahe): Add onDone event handler to detach the client.
    client.commands.listen(handleCommand);

    int exitCode = COMPILER_EXITCODE_CRASH;
    while (await workerCommands.moveNext()) {
      Command command = workerCommands.current;
      switch (command.code) {
        case DriverCommand.ClosePort:
          workerReceivePort.close();
          break;

        case DriverCommand.EventLoopStarted:
          eventLoopStarted = true;
          break;

        case DriverCommand.ExitCode:
          exitCode = command.data;
          break;

        default:
          client.sendCommand(command);
          break;
      }
    }
    errorSubscription.pause();
    return exitCode;
  }

  void endWorkerSession() {
    workerReceivePort.close();
    isolate.endIsolateSession();
  }

  Future<Null> detachClient() async {
    if (isolate.wasKilled) {
      // Setting these to null will ensure that [attachClient] causes a crash
      // if called after isolate was killed.
      errorSubscription = null;
      workerReceivePort = null;
      workerCommands = null;
      workerSendPort = null;

      // TODO(ahe): The session is dead. Tell the user about this.
      return null;
    }
    // TODO(ahe): Perform the reverse of attachClient here.
    await beginSession();
  }

  Future<int> performTask(
      SharedTask task,
      ClientController client,
      {
       UserSession userSession,
       /// End this session and return this isolate to the pool.
       bool endSession: false}) async {
    ClientLogger log = client.log;

    client.done.catchError((error, StackTrace stackTrace) {
      log.error(error, stackTrace);
    }).then((_) {
      log.done();
    });

    client.enqueCommandToWorker(new Command(DriverCommand.PerformTask, task));

    // Forward commands between the C++ client [client], and the worker isolate
    // `this`.  Also, Intercept the signal command and potentially kill the
    // isolate (the isolate needs to tell if it is interuptible or needs to be
    // killed, an example of the latter is, if compiler is running).
    int exitCode = await attachClient(client, userSession);
    // The verb (which was performed in the worker) is done.
    log.note("After attachClient (exitCode = $exitCode)");

    if (endSession) {
      // Return the isolate to the pool *before* shutting down the client. This
      // ensures that the next client will be able to reuse the isolate instead
      // of spawning a new.
      this.endWorkerSession();
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

  void endIsolateSession() {
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
  static int clientsAllocated = 0;

  static Set<ClientLogger> pendingClients = new Set<ClientLogger>();

  static Set<ClientLogger> erroneousClients = new Set<ClientLogger>();

  static ClientLogger allocate() {
    ClientLogger client = new ClientLogger(clientsAllocated++);
    pendingClients.add(client);
    return client;
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
    // TODO(ahe): Modify shutdown verb to report these errors.
    erroneousClients.add(this);
    note("Crash (${arguments.join(' ')}).\n"
         "${stringifyError(error, stackTrace)}");
  }

  String toString() => "$id";
}
