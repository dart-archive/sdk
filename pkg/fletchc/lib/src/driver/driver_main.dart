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
    StreamSubscription;

import 'dart:async' show Zone;

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

import 'driver_commands.dart' show
    Command,
    CommandSender,
    DriverCommand,
    handleSocketErrors,
    stringifyError;

import 'driver_isolate.dart' show
    isolateMain;

const Endianness commandEndianness = Endianness.LITTLE_ENDIAN;

const headerSize = 5;

class ControlStream {
  final Stream<List<int>> stream;

  final StreamSubscription<List<int>> subscription;

  final BytesBuilder builder = new BytesBuilder(copy: false);

  final StreamController<Command> controller = new StreamController<Command>();

  ControlStream(Stream<List<int>> stream)
      : this.stream = stream,
        this.subscription = stream.listen(null) {
    subscription
        ..onData(handleData)
        ..onError(handleError)
        ..onDone(handleDone);
  }

  Stream<Command> get commandStream => controller.stream;

  void handleData(Uint8List data) {
    // TODO(ahe): makeView(data, ...) to ensure monomorphism?
    builder.add(data);
    if (builder.length < headerSize) return;
    Uint8List list = builder.takeBytes();
    ByteData view = new ByteData.view(list.buffer, list.offsetInBytes);
    int length = view.getUint32(0, commandEndianness);
    if (list.length - headerSize < length) {
      builder.add(list);
      return;
    }
    int commandCode = view.getUint8(4);

    DriverCommand command = DriverCommand.values[commandCode];
    view = new ByteData.view(list.buffer, list.offsetInBytes + headerSize);
    switch (command) {
      case DriverCommand.Arguments:
        controller.add(new Command(command, decodeArgumentsCommand(view)));
        break;

      case DriverCommand.Stdin:
        int length = view.getUint32(0, commandEndianness);
        controller.add(new Command(command, makeView(view, 4, length)));
        break;

      case DriverCommand.Signal:
        int signal = view.getUint32(0, commandEndianness);
        controller.add(new Command(command, signal));
        break;

      default:
        controller.addError("Command not implemented yet: $command");
        break;
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
  }

  List<String> decodeArgumentsCommand(ByteData view) {
    int offset = 0;
    int argc = view.getUint32(offset, commandEndianness);
    offset += 4;
    List<String> argv = <String>[];
    for (int i = 0; i < argc; i++) {
      int length = view.getUint32(offset, commandEndianness);
      offset += 4;
      argv.add(UTF8.decode(makeView(view, offset, length)));
      offset += length;
    }
    return argv;
  }
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

Uint8List makeView(TypedData list, int offset, int length) {
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

  void gracefulShutdown(ProcessSignal signal) {
    print("Received signal $signal");

    try {
      socketFile.deleteSync();
      tmpdir.deleteSync(recursive: true);
    } catch (e) {
      print(e);
    }

    try {
      configFile.deleteSync();
    } catch (e) {
      print(e);
    }

    int exitCode = signal == ProcessSignal.SIGTERM ? 15 : 2;
    exit(-exitCode);
  }

  // When receiving SIGTERM or SIGINT, remove socket and config file.
  ProcessSignal.SIGTERM.watch().listen(gracefulShutdown);
  ProcessSignal.SIGINT.watch().listen(gracefulShutdown);

  ServerSocket server = await ServerSocket.bind(
      new
      UnixDomainAddress // NO_LINT
      (socketFile.path), 0);

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
      handleClient(
          pool,
          handleSocketErrors(connectionIterator.current, "controlSocket"));
    }
  } finally {
    // TODO(ahe): Do this in a SIGTERM handler.
    configFile.delete();
  }
}

Future handleClient(IsolatePool pool, Socket controlSocket) async {
  // This method needs to do the following:
  // * Spawn a new isolate (or reuse an existing) to perform the task.
  //
  // * Forward commands from C++ client to isolate.
  //
  // * Intercept signal command and potentially kill isolate (isolate needs to
  //   tell if it is interuptible or needs to be killed, latter if compiler is
  //   running).
  //
  // * Forward commands from isolate to C++.
  //
  // * Store completed isolates in a pool.

  // Spawn or reuse isolate.
  ManagedIsolate isolate = await pool.getIsolate();

  // Forward commands between C++ client [client], and compiler isolate
  // [compiler]. This is done with two asynchronous tasks that communicate with
  // each other. Also handles the signal command as mentioned above.
  ClientController client = new ClientController(controlSocket);
  CompilerController compiler = new CompilerController(isolate);
  Future clientFuture = client.start(compiler);
  Future compilerFuture = compiler.start(client);
  await compilerFuture;

  // At this point, the isolate has already been returned to the pool by
  // [compiler].

  await clientFuture;

}

/// Handles communication with the C++ client.
class ClientController {
  final Socket socket;

  CompilerController compiler;
  CommandSender commandSender;
  StreamSubscription<Command> subscription;
  Completer<Null> completer;

  ClientController(this.socket);

  /// Start processing commands from the client. The returned future completes
  /// when [endSession] is called.
  Future<Null> start(CompilerController compiler) {
    this.compiler = compiler;
    commandSender = new ByteCommandSender(socket);
    subscription = new ControlStream(socket).commandStream.listen(null);
    subscription
        ..onData(handleCommand)
        ..onError(handleCommandError)
        ..onDone(handleCommandsDone);
    completer = new Completer<Null>();
    return completer.future;
  }

  void handleCommand(Command command) {
    compiler.controller.add(command);
  }

  void handleCommandError(error, StackTrace trace) {
    print(stringifyError(error, trace));
    completer.completeError(error, trace);
  }

  void handleCommandsDone() {
    completer.complete();
  }

  void sendCommand(DriverCommand code, data) {
    switch (code) {
      case DriverCommand.Stdout:
        commandSender.sendStdoutBytes(data);
        break;

      case DriverCommand.Stderr:
        commandSender.sendStderrBytes(data);
        break;

      case DriverCommand.ExitCode:
        commandSender.sendExitCode(data);
        break;

      default:
        throw "Unexpected command: $code";
    }
  }

  void endSession() {
    subscription.cancel();
    socket.flush().then((_) {
      socket.close();
    });
  }
}

/// Handles communication with the compiler running in its own isolate.
class CompilerController {
  final ManagedIsolate isolate;

  /// [ClientController] uses this [controller] to notify this object about
  /// commands that should be forwarded to the compiler isolate.
  final StreamController<Command> controller = new StreamController<Command>();

  bool eventLoopStarted = false;

  CompilerController(this.isolate);

  /// Start processing commands from the compiler isolate (and forward commands
  /// from the C++ client). The returned future normally completes when the
  /// compiler isolate sends DriverCommand.ClosePort, or if the isolate is
  /// killed due to DriverCommand.Signal arriving through controller.stream.
  Future<Null> start(ClientController client) async {
    ReceivePort port = isolate.beginSession();
    StreamIterator iterator = new StreamIterator(port);
    bool hasPort = await iterator.moveNext();
    assert(hasPort);
    SendPort sendPort = iterator.current;

    handleCommand(Command command) {
      if (command.code == DriverCommand.Signal && !eventLoopStarted) {
        isolate.kill();
        port.close();
      } else {
        sendPort.send([command.code.index, command.data]);
      }
    }
    StreamSubscription subscription = controller.stream.listen(handleCommand);

    while (await iterator.moveNext()) {
      /// [message] is a pair of int (index into DriverCommand.values), and
      /// command payload data.
      List message = iterator.current;
      DriverCommand code = DriverCommand.values[message[0]];
      switch (code) {
        case DriverCommand.ClosePort:
          port.close();
          break;

        case DriverCommand.EventLoopStarted:
          eventLoopStarted = true;
          break;

        default:
          client.sendCommand(code, message[1]);
          break;
      }
    }

    // Return the isolate to the pool *before* shutting down the client.
    isolate.endSession();
    client.endSession();
  }
}

class ManagedIsolate {
  final IsolatePool pool;
  final Isolate isolate;
  final SendPort port;
  bool wasKilled = false;

  ManagedIsolate(this.pool, this.isolate, this.port);

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
  }
}

class IsolatePool {
  // Queue of idle isolates. When an isolate becomes idle, it is added at the
  // end.
  final Queue<ManagedIsolate> idleIsolates = new Queue<ManagedIsolate>();
  final Function isolateEntryPoint;

  IsolatePool(this.isolateEntryPoint);

  Future<ManagedIsolate> getIsolate() async {
    if (idleIsolates.isEmpty) {
      return await spawnIsolate();
    } else {
      return idleIsolates.removeFirst();
    }
  }

  Future<ManagedIsolate> spawnIsolate() async {
    ReceivePort receivePort = new ReceivePort();
    Isolate isolate = await Isolate.spawn(
        isolateEntryPoint, receivePort.sendPort, paused: true);
    ReceivePort errorPort = new ReceivePort();
    ManagedIsolate managedIsolate;
    isolate.addErrorListener(errorPort.sendPort);
    errorPort.listen((errorList) {
      String error = errorList[0];
      String stackTrace = errorList[1];
      io.stderr.writeln(error);
      if (stackTrace != null) {
        io.stderr.writeln(stackTrace);
      }
      exit(1);
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
    await iterator.cancel();
    managedIsolate = new ManagedIsolate(this, isolate, port);
    return managedIsolate;
  }
}
