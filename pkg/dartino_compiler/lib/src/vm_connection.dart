// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Abstraction of a connection to a VM.

import "dart:async" show
    Completer,
    Future,
    Stream;

import "dart:collection" show
    Queue;

import "dart:io" show
    FileSystemException,
    IOSink,
    Socket,
    SocketException,
    SocketOption;

import "package:serial_port/serial_port.dart";

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

class SerialPortSink implements Sink<List<int>> {
  final SerialPort serialPort;
  SerialPortSink(this.serialPort);
  Queue<Function> actions = new Queue<Function>();
  Completer emptied = new Completer();
  bool actionIsRunning = false;
  Completer<Null> doneCompleter = new Completer<Null>();

  Future<Null> get done => doneCompleter.future;

  void addAction(Future action()) {
    void doNext() {
      if (actions.isEmpty) {
        actionIsRunning = false;
      } else {
        actionIsRunning = true;
        actions.removeFirst()().then((_) {
          doNext();
        });
      }
    }

    actions.add(action);
    if (!actionIsRunning) {
      doNext();
    }
  }

  @override
  void add(List<int> data) {
    addAction(() => serialPort.write(data));
  }

  @override
  void close() {
    addAction(() async => doneCompleter.complete());
  }
}

class TtyConnection extends VmConnection {
  SerialPort serialPort;
  final String address;
  final SerialPortSink output;

  Stream<List<int>> get input => serialPort.onRead;

  TtyConnection(this.address, SerialPort serialPort)
      : serialPort = serialPort,
        output = new SerialPortSink(serialPort);

  static Future<TtyConnection> connect(
      String address,
      String connectionDescription,
      void log(String message),
      {void onConnectionError(FileSystemException error),
       DiagnosticKind messageKind: DiagnosticKind.socketVmConnectError}) async {
    onConnectionError ??= (FileSystemException error) {
      String message = error.message;
      throwFatalError(
          messageKind,
          address: address,
          message: message);
    };

    SerialPort serialPort = new SerialPort(address, baudrate: 115200);
    try {
      await serialPort.open();
    } on FileSystemException catch(e) {
      onConnectionError(e);
    }
    log("Connected to device $connectionDescription $address");
    return new TtyConnection(address, serialPort);
  }

  String get description => "$address";

  Future<Null> close() async {
    print("Closing tty-connection");
    output.close();
    await output.done;
    await serialPort.close();
    doneCompleter.complete(null);
  }

  Completer doneCompleter = new Completer();

  Future<Null> get done => doneCompleter.future;
}