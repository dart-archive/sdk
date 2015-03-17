// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver;

import 'dart:io';

import 'dart:io' as io;

import 'dart:async' show
    Completer,
    Future,
    Stream,
    StreamIterator,
    StreamSubscription,
    Zone,
    ZoneSpecification;

import 'dart:typed_data' show
    ByteData,
    Uint8List;

import 'dart:convert' show
    UTF8;

import '../compiler.dart' show
    FletchCompiler;

const COMPILER_CRASHED = 253;
const DART_VM_EXITCODE_COMPILE_TIME_ERROR = 254;
const DART_VM_EXITCODE_UNCAUGHT_EXCEPTION = 255;

class StreamBuffer {
  final Stream<List<int>> stream;

  final StreamSubscription<List<int>> subscription;

  final BytesBuilder builder = new BytesBuilder(copy: false);

  int requestedBytes = 0;

  Completer<Uint8List> completer;

  StreamBuffer(Stream<List<int>> stream)
      : this.stream = stream,
        this.subscription = stream.listen(null) {
    subscription
        ..onData(handleData)
        ..onError(handleError)
        ..onDone(handleDone);
  }

  void handleData(Uint8List data) {
    builder.add(data);
    if (completer != null) {
      completeIfPossible();
    }
  }

  void handleError(error, StackTrace stackTrace) {
    if (stackTrace != null) {
      stderr.write("$error\n$stackTrace\n");
    } else {
      stderr.write("$error\n");
    }
    exit(1);
  }

  void handleDone() {
    builder.takeBytes();
  }

  void completeIfPossible() {
    if (this.requestedBytes > builder.length) return;
    // BytesBuilder always returns a Uint8List.
    Uint8List list = builder.takeBytes();
    Completer<Uint8List> completer = this.completer;
    int requestedBytes = this.requestedBytes;
    this.completer = null;
    this.requestedBytes = 0;
    if (requestedBytes != list.length) {
      builder.add(makeView(list, requestedBytes, list.length - requestedBytes));
    }
    var result = makeView(list, 0, requestedBytes);
    completer.complete(result);
  }

  Future<Uint8List> read(int length) {
    if (completer != null) {
      throw "Previous read not complete";
    }
    completer = new Completer<Uint8List>();
    Future<Uint8List> future = completer.future;
    requestedBytes = length;
    completeIfPossible();
    return future;
  }

  Future<int> readUint32() {
    return read(4).then((Uint8List list) {
      return new ByteData.view(list.buffer, list.offsetInBytes).getUint32(0);
    });
  }
}

Uint8List makeView(Uint8List list, int offset, int length) {
  return new Uint8List.view(list.buffer, list.offsetInBytes + offset, length);
}

Future main(List<String> arguments) async {
  File configFile = new File.fromUri(Uri.base.resolve(arguments.first));

  ServerSocket server =
      await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);
  int port = server.port;

  // Write the port number to a config file. This lets multiple command line
  // programs share this persistent driver process, which in turn eliminates
  // start up overhead.
  configFile.writeAsStringSync("$port");

  // Print the port number so the launching process knows where to connect, and
  // that the socket port is ready.
  print(port);

  var connectionIterator = new StreamIterator(server);

  try {
    while (await connectionIterator.moveNext()) {
      await handleClient(
          handleErrors(connectionIterator.current, "controlSocket"));
    }
  } finally {
    // TODO(ahe): Do this in a SIGTERM handler.
    configFile.delete();
  }
}

handleErrors(thing, String name) {
  String info;

  void onError(error, stackTrace) {
    if (stackTrace != null) {
      io.stderr.write("Error on $info: $error\n$stackTrace\n");
    } else {
      io.stderr.write("Error on $info: $error\n");
    }
  }

  if (thing is Socket) {
    info = "$name ${thing.port} -> ${thing.remotePort}";
    thing.done.catchError(onError);
  } else if (thing is StreamSubscription) {
    info = "$name subscription";
    thing.onError(onError);
  } else {
    throw "Unknown thing: ${thing.runtimeType}";
  }
  io.stderr.write("New $info\n");

  return thing;
}

Future handleClient(Socket controlSocket) async {
  // Start another server socket to set up sockets for stdin, stdout, and
  // stderr.
  ServerSocket server =
      await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);
  int port = server.port;

  writeNetworkUint32(controlSocket, port);
  await controlSocket.flush();

  StreamBuffer controlBuffer = new StreamBuffer(controlSocket);

  List<String> arguments = await readArgv(controlBuffer);

  var connectionIterator = new StreamIterator(server);
  await connectionIterator.moveNext();

  // Socket for stdin and stdout.
  Socket stdio = handleErrors(connectionIterator.current, "stdio");
  await connectionIterator.moveNext();

  // Socket for stderr.
  Socket stderr = handleErrors(connectionIterator.current, "stderr");

  // Now that we have the sockets, close the server.
  server.close();

  ZoneSpecification specification =
      new ZoneSpecification(print: (_1, _2, _3, String line) {
        stdout.writeln(line);
      });

  int exitCode = await Zone.current.fork(specification: specification)
      .run(() => compile(arguments.skip(1).toList(), stdio, stderr));
  stdio.destroy();
  stderr.destroy();

  writeNetworkUint32(controlSocket, exitCode);

  await controlSocket.flush();
  controlSocket.close();
}

void writeNetworkUint32(Socket socket, int i) {
  Uint8List list = new Uint8List(4);
  ByteData view = new ByteData.view(list.buffer);
  view.setUint32(0, i);
  socket.add(list);
}

Future<List<String>> readArgv(StreamBuffer buffer) async {
  int argc = await buffer.readUint32();
  List<String> argv = <String>[];
  for (int i = 0; i < argc; i++) {
    Uint8List bytes = await buffer.read(await buffer.readUint32());
    // [bytes] is zero-terminated.
    bytes = makeView(bytes, 0, bytes.length - 1);
    argv.add(UTF8.decode(bytes));
  }
  return argv;
}

Future<int> compile(List<String> arguments, Socket stdio, Socket stderr) async {
  List<String> options = const bool.fromEnvironment("fletchc-verbose")
      ? <String>['--verbose'] : <String>[];
  FletchCompiler compiler =
      new FletchCompiler(options: options, script: arguments.single);
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

  if (compiler.verbose) {
    print("Running '${compiler.fletchVm.toFilePath()} ${vmOptions.join(" ")}'");
  }
  var vmProcess =
      await Process.start(compiler.fletchVm.toFilePath(), vmOptions);

  handleErrors(stdio.listen(vmProcess.stdin.add), "stdin");
  handleErrors(vmProcess.stdout.listen(stdio.add), "stdout");
  handleErrors(vmProcess.stderr.listen(stderr.add), "stderr");

  bool hasValue = await connectionIterator.moveNext();
  assert(hasValue);
  var vmSocket = handleErrors(connectionIterator.current, "vmSocket");
  server.close();

  vmSocket.listen(null).cancel();
  commands.forEach((command) => command.addTo(vmSocket));
  vmSocket.close();

  exitCode = await vmProcess.exitCode;
  if (exitCode != 0) {
    print("Non-zero exit code from VM ($exitCode).");
  }
  return exitCode;
}
