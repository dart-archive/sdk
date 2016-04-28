// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Abstraction of a connection to a VM.

import "dart:async" show
    Completer,
    Future,
    Stream;

import "dart:io" show
    File,
    FileMode,
    IOSink,
    RandomAccessFile,
    Socket,
    SocketException,
    SocketOption;

import "dart:typed_data" show
    Uint8List;

import 'verbs/infrastructure.dart' show
    DiagnosticKind,
    throwFatalError;

import 'hub/client_commands.dart' show
    handleSocketErrors;

abstract class VmConnection {
  Stream<List<int>> get input;
  Sink<List<int>> get output;

  String get description;

  Future<Null> close();
  Future<Null> get done;
}

class TcpConnection extends VmConnection {
  final Socket socket;

  Stream<List<int>> get input => socket;
  IOSink get output => socket;

  String get host => socket.remoteAddress.host;
  int get port => socket.remotePort;

  // This is a workaround for dartbug.com/26288. When that is resolved we should
  // be able to use `socket.done` directly
  Completer<Null> doneCompleter = new Completer<Null>();

  TcpConnection(this.socket);

  static Future<TcpConnection> connect(
      host,
      int port,
      String socketDescription,
      void log(String message),
      {void onConnectionError(SocketException e),
       DiagnosticKind messageKind: DiagnosticKind.socketVmConnectError}) async {
    onConnectionError ??= (SocketException error) {
      String message = error.message;
      if (error.osError != null) {
        message = error.osError.message;
      }
      throwFatalError(
          messageKind,
          address: '$host:$port',
          message: message);
    };
    // We are using .catchError rather than try/catch because we have seen
    // incorrect stack traces using the latter.
    Socket socket = await Socket.connect(host, port).catchError(
        onConnectionError,
        test: (e) => e is SocketException);
    handleSocketErrors(socket, socketDescription, log: (String info) {
      log("Connected to TCP $socketDescription  $info");
    });
    // We send many small packages, so use no-delay.
    socket.setOption(SocketOption.TCP_NODELAY, true);
    return new TcpConnection(socket);
  }

  String get description => "$host:$port";

  Future<Null> close() async {
    socket.destroy();
    doneCompleter.complete();
  }

  Future<Null> get done => doneCompleter.future;
}

class RandomAccessFileSink implements Sink<List<int>> {
  final RandomAccessFile f;
  RandomAccessFileSink(this.f);
  Future lastAction = new Future.value(null);

  @override
  void add(List<int> data) {
    lastAction.then((_) {
      lastAction = f.writeFrom(data);
    });
  }

  @override
  void close() {
    lastAction.then((_) {
      lastAction = f.close();
    });
  }
}

Stream<List<int>> readingStream(RandomAccessFile f) async* {
  while (true) {
    int a = await f.readByte();
    Uint8List x = new Uint8List(1);
    x[0] = a;
    yield x;
  }
}

class TtyConnection extends VmConnection {
  final Stream<List<int>> input;
  final RandomAccessFileSink output;
  final String address;
  final RandomAccessFile inputFile;
  final RandomAccessFile outputFile;

  TtyConnection(RandomAccessFile input,
      RandomAccessFile output, this.address)
      : inputFile = input,
        outputFile = output,
        input = readingStream(input),
        output = new RandomAccessFileSink(output);

  static Future<TtyConnection> connect(
      String address,
      String connectionDescription,
      void log(String message)) async {
    File device = new File(address);
    log("Connected to device $connectionDescription $address");
    return new TtyConnection(await device.open(mode: FileMode.READ),
        await device.open(mode: FileMode.WRITE_ONLY), address);
  }

  String get description => "$address";

  Future<Null> close() async {
    print("Closing tty-connection");
    await inputFile.close();
    await output.close();
    doneCompleter.complete(null);
  }

  Completer doneCompleter = new Completer();

  Future<Null> get done => doneCompleter.future;
}