// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver;

import 'dart:io' hide
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

import '../compiler.dart' show
    FletchCompiler;

import '../commands.dart' as commands_lib;

const COMPILER_CRASHED = 253;
const DART_VM_EXITCODE_COMPILE_TIME_ERROR = 254;
const DART_VM_EXITCODE_UNCAUGHT_EXCEPTION = 255;

const Endianness commandEndianness = Endianness.LITTLE_ENDIAN;

const headerSize = 5;

const fletchDriverSuffix = "_driver";

enum DriverCommand {
  Stdin,  // Data on stdin.
  Stdout,  // Data on stdout.
  Stderr,  // Data on stderr.
  Arguments,  // Command-line arguments.
  Signal,  // Unix process signal received.
  ExitCode,  // Set process exit code.

  DriverConnectionError,  // Error in connection.
}

class Command {
  final DriverCommand code;
  final data;

  Command(this.code, this.data);

  String toString() => 'Command($code, $data)';
}

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

class CommandSender {
  final Sink<List<int>> sink;

  CommandSender(this.sink);

  void sendExitCode(int exitCode) {
    int payloadSize = 4;
    Uint8List list = new Uint8List(headerSize + payloadSize);
    ByteData view = list.buffer.asByteData();
    view.setUint32(0, payloadSize, commandEndianness);
    view.setUint8(4, DriverCommand.ExitCode.index);
    view.setUint32(headerSize, exitCode, commandEndianness);
    sink.add(list);
  }

  void sendStdout(String data) {
    sendStdoutBytes(new Uint8List.fromList(UTF8.encode(data)));
  }

  void sendStdoutBytes(List<int> data) {
    sendDataCommand(DriverCommand.Stdout, data);
  }

  void sendStderr(String data) {
    sendStderrBytes(new Uint8List.fromList(UTF8.encode(data)));
  }

  void sendStderrBytes(List<int> data) {
    sendDataCommand(DriverCommand.Stderr, data);
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

  ServerSocket server =
      await ServerSocket.bind(new UnixDomainAddress(socketFile.path), 0);

  // Write the socket file to a config file. This lets multiple command line
  // programs share this persistent driver process, which in turn eliminates
  // start up overhead.
  configFile.writeAsStringSync(socketFile.path, flush: true);


  // Print the temporary directory so the launching process knows where to
  // connect, and that the socket is ready.
  print(socketFile.path);

  var connectionIterator = new StreamIterator(server);

  try {
    while (await connectionIterator.moveNext()) {
      await handleClient(
          handleSocketErrors(connectionIterator.current, "controlSocket"));
    }
  } finally {
    // TODO(ahe): Do this in a SIGTERM handler.
    configFile.delete();
  }
}

Function makeErrorHandler(String info) {
  return (error, StackTrace stackTrace) {
    Zone.ROOT.print("Error on $info: ${stringifyError(error, stackTrace)}");
  };
}

Socket handleSocketErrors(Socket socket, String name) {
  String remotePort = "?";
  try {
    remotePort = "${socket.remotePort}";
  } catch (_) {
    // Ignored, socket.remotePort may fail if the socket was closed on the
    // other side.
  }
  String info = "$name ${socket.port} -> $remotePort";
  // TODO(ahe): Remove the following line when things get more stable.
  Zone.ROOT.print(info);
  socket.done.catchError(makeErrorHandler(info));
  return socket;
}

StreamSubscription handleSubscriptionErrors(
    StreamSubscription subscription,
    String name) {
  String info = "$name subscription";
  Zone.ROOT.print(info);
  return subscription
      ..onError(makeErrorHandler(info));
}

String stringifyError(error, StackTrace stackTrace) {
  String safeToString(object) {
    try {
      return '$object';
    } catch (e) {
      return Error.safeToString(object);
    }
  }
  StringBuffer buffer = new StringBuffer();
  buffer.writeln(safeToString(error));
  if (stackTrace != null) {
    buffer.writeln(safeToString(stackTrace));
  } else {
    buffer.writeln("No stack trace.");
  }
  return '$buffer';
}

Future handleClient(Socket controlSocket) async {
  CommandSender commandSender = new CommandSender(controlSocket);

  StreamIterator<Command> commandIterator = new StreamIterator<Command>(
      new ControlStream(controlSocket).commandStream);

  await commandIterator.moveNext();
  Command command = commandIterator.current;
  if (command.code != DriverCommand.Arguments) {
    print("Expected arguments from clients but got: $command");
    // The client is misbehaving, shut it down now.
    controlSocket.destroy();
    return;
  }

  // This is argv from a C/C++ program. The first entry is the program name
  // which isn't normally included in Dart arguments (as passed to main).
  List<String> arguments = command.data;
  String programName = arguments.first;
  String fletchVm = null;
  if (programName.endsWith(fletchDriverSuffix)) {
    fletchVm = programName.substring(
        0, programName.length - fletchDriverSuffix.length);
  }
  arguments = arguments.skip(1).toList();

  ZoneSpecification specification =
      new ZoneSpecification(print: (_1, _2, _3, String line) {
        commandSender.sendStdout('$line\n');
      },
      handleUncaughtError: (_1, _2, _3, error, StackTrace stackTrace) {
        String message =
            "\n\nExiting due to uncaught error.\n"
            "${stringifyError(error, stackTrace)}";
        Zone.ROOT.print(message);
        commandSender.sendStderr('$message\n');
        exit(1);
      });

  int exitCode = await Zone.current.fork(specification: specification)
      .run(() => compileAndRun(
          fletchVm, arguments, commandSender, commandIterator));

  commandSender.sendExitCode(exitCode);

  commandIterator.cancel();

  await controlSocket.flush();
  controlSocket.close();
}

Future<int> compileAndRun(
    String fletchVm,
    List<String> arguments,
    CommandSender commandSender,
    StreamIterator<Command> commandIterator) async {
  List<String> options = const bool.fromEnvironment("fletchc-verbose")
      ? <String>['--verbose'] : <String>[];
  FletchCompiler compiler =
      new FletchCompiler(
          options: options, script: arguments.single, fletchVm: fletchVm,
          // TODO(ahe): packageRoot should be an option.
          packageRoot: "package/");
  bool compilerCrashed = false;
  List commands = await compiler.run().catchError((e, trace) {
    compilerCrashed = true;
    // TODO(ahe): Remove this catchError block when this bug is fixed:
    // https://code.google.com/p/dart/issues/detail?id=22437.
    print(e);
    print(trace);
    return [];
  });
  if (compilerCrashed) {
    return COMPILER_CRASHED;
  }

  var server = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);

  List<String> vmOptions = <String>[
      '--port=${server.port}',
      '-Xvalidate-stack',
  ];

  var connectionIterator = new StreamIterator(server);

  String vmPath = compiler.fletchVm.toFilePath();

  if (compiler.verbose) {
    print("Running '$vmPath ${vmOptions.join(" ")}'");
  }
  Process vmProcess = await Process.start(vmPath, vmOptions);

  readCommands(commandIterator, vmProcess);

  StreamSubscription vmStdoutSubscription = handleSubscriptionErrors(
      vmProcess.stdout.listen(commandSender.sendStdoutBytes), "vm stdout");
  StreamSubscription vmStderrSubscription = handleSubscriptionErrors(
      vmProcess.stderr.listen(commandSender.sendStderrBytes), "vm stderr");

  bool hasValue = await connectionIterator.moveNext();
  assert(hasValue);
  var vmSocket = handleSocketErrors(connectionIterator.current, "vmSocket");
  server.close();

  vmSocket.listen(null).cancel();
  commands.forEach((command) => command.addTo(vmSocket));
  const commands_lib.ProcessSpawnForMain().addTo(vmSocket);
  const commands_lib.ProcessRun().addTo(vmSocket);
  vmSocket.close();

  exitCode = await vmProcess.exitCode;

  await vmProcess.stdin.close();
  await vmStdoutSubscription.cancel();
  await vmStderrSubscription.cancel();

  if (exitCode != 0) {
    print("Non-zero exit code from '$vmPath' ($exitCode).");
  }

  return exitCode;
}

Future<Null> readCommands(
    StreamIterator<Command> commandIterator,
    Process vmProcess) async {
  while (await commandIterator.moveNext()) {
    Command command = commandIterator.current;
    switch (command.code) {
      case DriverCommand.Stdin:
        if (command.data.length == 0) {
          await vmProcess.stdin.close();
        } else {
          vmProcess.stdin.add(command.data);
        }
        break;

      case DriverCommand.Signal:
        int signalNumber = command.data;
        ProcessSignal signal = ProcessSignal.SIGTERM;
        switch (signalNumber) {
          case 2:
            signal = ProcessSignal.SIGINT;
            break;

          case 15:
            signal = ProcessSignal.SIGTERM;
            break;

          default:
            Zone.ROOT.print("Warning: unknown signal number: $signalNumber");
            signal = ProcessSignal.SIGTERM;
            break;
        }
        vmProcess.kill(signal);
        break;

      default:
        Zone.ROOT.print("Unexpected command from client: $command");
    }
  }
}
