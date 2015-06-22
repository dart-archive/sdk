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
    Future,
    Stream,
    StreamController,
    StreamIterator,
    StreamSubscription,
    Zone,
    ZoneSpecification;

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

import 'exit_codes.dart' show
    DART_VM_EXITCODE_UNCAUGHT_EXCEPTION;

import 'driver_commands.dart' show
    Command,
    CommandSender,
    DriverCommand,
    handleSocketErrors,
    stringifyError;

import 'driver_isolate.dart' show
    isolateMain;

import 'verbs.dart' show
    Verb,
    commonVerbs,
    uncommonVerbs;

const Endianness commandEndianness = Endianness.LITTLE_ENDIAN;

const headerSize = 5;

Function gracefulShutdown;

class ControlStream {
  final Stream<List<int>> stream;

  final StreamSubscription<List<int>> subscription;

  final BytesBuilder builder = new BytesBuilder(copy: false);

  final StreamController<Command> controller = new StreamController<Command>();

  final ClientLogger log;

  ControlStream(Stream<List<int>> stream, this.log)
      : this.stream = stream,
        this.subscription = stream.listen(null) {
    subscription
        ..onData(handleData)
        ..onError(handleError)
        ..onDone(handleDone);
  }

  Stream<Command> get commandStream => controller.stream;

  void handleData(Uint8List data) {
    builder.add(toUint8ListView(data));
    Uint8List list = builder.takeBytes();

    ByteData view = toByteData(list);

    while (view.lengthInBytes >= headerSize) {
      int length = view.getUint32(0, commandEndianness);
      if ((view.lengthInBytes - headerSize) < length) {
        // Not all of the payload has arrived yet.
        break;
      }
      int commandCode = view.getUint8(4);
      DriverCommand driverCommand = DriverCommand.values[commandCode];

      ByteData payload = toByteData(view, headerSize, length);

      Command command = makeCommand(driverCommand, payload);

      if (command != null) {
        controller.add(command);
      } else {
        controller.addError("Command not implemented yet: $driverCommand");
      }

      view = toByteData(payload, length);
    }

    if (view.lengthInBytes > 0) {
      builder.add(toUint8ListView(view));
    }
  }

  Command makeCommand(DriverCommand code, ByteData payload) {
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

  void handleError(error, StackTrace stackTrace) {
    controller.addError(error, stackTrace);
  }

  void handleDone() {
    List trailing = builder.takeBytes();
    if (trailing.length != 0) {
      controller.addError(
          new StateError("Stream closed with trailing bytes : $trailing"));
    }
    controller.close();
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

ByteData toByteData(TypedData data, [int offset = 0, int length]) {
  return data.buffer.asByteData(data.offsetInBytes + offset, length);
}

class ByteCommandSender extends CommandSender {
  final Sink<List<int>> sink;

  ByteCommandSender(this.sink);

  void sendExitCode(int exitCode) {
    int payloadSize = 4;
    Uint8List list = new Uint8List(headerSize + payloadSize);
    ByteData view = list.buffer.asByteData();
    view.setUint32(0, payloadSize, commandEndianness);
    view.setUint8(4, DriverCommand.ExitCode.index);
    view.setUint32(headerSize, exitCode, commandEndianness);
    sink.add(list);
  }

  void sendDataCommand(DriverCommand command, List<int> data) {
    int payloadSize = data.length + 4;
    Uint8List list = new Uint8List(headerSize + payloadSize);
    ByteData view = list.buffer.asByteData();
    view.setUint32(0, payloadSize, commandEndianness);
    view.setUint8(4, command.index);
    view.setUint32(headerSize, data.length, commandEndianness);
    int dataOffset = headerSize + 4;
    list.setRange(dataOffset, dataOffset + data.length, data);
    sink.add(list);
  }

  void sendClose() {
    throw new UnsupportedError(
        "Client (C++) doesn't support DriverCommand.Close.");
  }

  void sendEventLoopStarted() {
    throw new UnsupportedError(
        "Client (C++) doesn't support DriverCommand.EventLoopStarted.");
  }
}

Uint8List toUint8ListView(TypedData list, [int offset = 0, int length]) {
  return new Uint8List.view(list.buffer, list.offsetInBytes + offset, length);
}

Future main(List<String> arguments) async {
  File configFile = new File.fromUri(Uri.base.resolve(arguments.first));
  Directory tmpdir = Directory.systemTemp.createTempSync("fletch_driver");

  File socketFile = new File("${tmpdir.path}/socket");
  try {
    socketFile.deleteSync();
  } on FileSystemException catch (e) {
    // Ignored. There's no way to check if a socket file exists.
  }

  ServerSocket server;

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

  var connectionIterator = new StreamIterator(server);

  IsolatePool pool = new IsolatePool(isolateMain);
  try {
    while (await connectionIterator.moveNext()) {
      await handleClient(
          pool,
          handleSocketErrors(connectionIterator.current, "controlSocket"));
    }
  } finally {
    gracefulShutdown();
  }
}

Future<Null> handleClient(IsolatePool pool, Socket controlSocket) async {
  ClientLogger log = ClientLogger.allocate();

  ClientController client = new ClientController(controlSocket, log)..start();
  List<String> arguments = await client.arguments;
  log.gotArguments(arguments);

  arguments = client.parseArguments(arguments);

  if (client.requiresWorker) {
    handleClientInWorker(pool, client);
  } else {
    await handleVerbHere(arguments, client);
  }
}

void handleClientInWorker(IsolatePool pool, ClientController client) {
  // This method needs to do the following:
  // * Spawn a new worker isolate (or reuse an existing) to perform the task.
  //
  // * Forward commands from C++ client to isolate.
  //
  // * Intercept signal command and potentially kill isolate (isolate needs to
  //   tell if it is interuptible or needs to be killed, latter, for example,
  //   if compiler is running).
  //
  // * Forward commands from isolate to C++.
  //
  // * Store completed isolates in a pool.

  // This is asynchronous, so we can respond to other requests.
  new Future(() async {
    ClientLogger log = client.log;
    // Spawn/reuse a worker isolate.
    IsolateController worker =
        new IsolateController(await pool.getIsolate(exitOnError: false));

    // Forward commands between C++ client [client], and worker isolate
    // [worker].  This is done with two asynchronous tasks that communicate
    // with each other.  Also handles the signal command as mentioned above.
    await worker.beginSession();
    log.note("After beginSession.");
    await worker.attachClient(client);
    log.note("After attachClient.");

    // Return the isolate to the pool *before* shutting down the client. This
    // ensures that the next client will be able to reuse the isolate instead
    // of spawning a new.
    worker.endSession();
    client.endSession();

    try {
      await client.done;
    } catch (error, stackTrace) {
      log.error(error, stackTrace);
    }
    log.done();
  });
}

Future<Null> handleVerbHere(
    List<String> arguments,
    ClientController client) async {
  ZoneSpecification specification =
      new ZoneSpecification(print: (_1, _2, _3, String line) {
        client.printLineOnStdout(line);
      },
      handleUncaughtError: (_1, _2, _3, error, StackTrace stackTrace) {
        String message =
            "\n\nExiting due to uncaught error.\n"
            "${stringifyError(error, stackTrace)}";
        Zone.ROOT.print(message);
        client.printLineOnStderr(message);
        exit(DART_VM_EXITCODE_UNCAUGHT_EXCEPTION);
      });

  int exitCode = await Zone.current.fork(specification: specification).run(
      () async {
        try {
          return await client.verb.perform(
              client.fletchVm,
              arguments,
              null,
              null);
        } catch (error, stackTrace) {
          String message =
              "\n\nExiting due to uncaught error.\n"
              "${stringifyError(error, stackTrace)}";
          Zone.ROOT.print(message);
          client.printLineOnStderr(message);
          return DART_VM_EXITCODE_UNCAUGHT_EXCEPTION;
        }
      });
  client.exit(exitCode);
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

  /// The verb request by the client. Updated by [parseArguments].
  Verb verb;

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

  bool get requiresWorker => verb.requiresWorker;

  /// Start processing commands from the client.
  void start() {
    commandSender = new ByteCommandSender(socket);
    subscription = new ControlStream(socket, log).commandStream.listen(null);
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
    }
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
        throw "Unexpected command: $command";
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
    commandSender.sendExitCode(exitCode);
    endSession();
  }

  List<String> parseArguments(List<String> arguments) {
    /// [programName] is the canonicalized absolute path to the fletch
    /// executable (the C++ program).
    String programName = arguments.first;
    String fletchVm = "$programName-vm";
    String verbName;
    if (arguments.length < 2) {
      verbName = 'help';
      arguments = <String>[];
    } else {
      verbName = arguments[1];
      arguments = arguments.skip(2).toList();
    }
    Verb verb = commonVerbs[verbName];
    if (verb == null) {
      verb = uncommonVerbs[verbName];
    }
    if (verb == null) {
      printLineOnStderr("Unknown argument: $verbName");
      verb = commonVerbs['help'];
    }

    this.verb = verb;
    this.fletchVm = fletchVm;
    return arguments;
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
      throw "Didn't get a sendPort from worker isolate.";
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
  Future<Null> attachClient(ClientController client) async {
    errorSubscription.onData((errorList) {
      String error = errorList[0];
      String stackTrace = errorList[1];
      client.printLineOnStderr(error);
      if (stackTrace != null) {
        client.printLineOnStderr(stackTrace);
      }
      workerReceivePort.close();
    });
    errorSubscription.resume();
    handleCommand(Command command) {
      if (command.code == DriverCommand.Signal && !eventLoopStarted) {
        isolate.kill();
        workerReceivePort.close();
      } else {
        workerSendPort.send([command.code.index, command.data]);
      }
    }
    // TODO(ahe): Add onDone event handler to detach the client.
    client.commands.listen(handleCommand);

    while (await workerCommands.moveNext()) {
      Command command = workerCommands.current;
      switch (command.code) {
        case DriverCommand.ClosePort:
          workerReceivePort.close();
          break;

        case DriverCommand.EventLoopStarted:
          eventLoopStarted = true;
          break;

        default:
          client.sendCommand(command);
          break;
      }
    }
    errorSubscription.pause();
  }

  void endSession() {
    isolate.endSession();
  }
}

class ManagedIsolate {
  final IsolatePool pool;
  final Isolate isolate;
  final SendPort port;
  final Stream errors;
  bool wasKilled = false;

  ManagedIsolate(this.pool, this.isolate, this.port, this.errors);

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
    isolate.kill();
    // TODO(ahe): Should be:
    // isolate.kill(priority: Isolate.IMMEDIATE);
    // This is due to this (unannounced) breaking change: 1074223002.
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
        exit(DART_VM_EXITCODE_UNCAUGHT_EXCEPTION);
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
    isolate.resume(isolate.pauseCapability);
    StreamIterator iterator = new StreamIterator(receivePort);
    bool hasElement = await iterator.moveNext();
    if (!hasElement) throw new StateError("No port received from isolate.");
    SendPort port = iterator.current;
    receivePort.close();
    managedIsolate =
        new ManagedIsolate(this, isolate, port, errorController.stream);
    return managedIsolate;
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

  List<String> arguments;

  ClientLogger(this.id);

  void note(object) {
    String note = "$object";
    notes.add(note);
    print("$id: $note");
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
