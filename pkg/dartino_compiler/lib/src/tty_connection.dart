// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import "dart:async" show Completer, Future, Stream;
import "dart:collection" show Queue;

import "dart:io" show FileSystemException;

import "vm_connection.dart" show VmConnection;

import 'verbs/infrastructure.dart' show DiagnosticKind, throwFatalError;

import "package:serial_port/serial_port.dart";

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
  final serialPort;
  final String address;
  final SerialPortSink output;

  Stream<List<int>> get input => serialPort.onRead;

  TtyConnection(this.address, var serialPort)
      : serialPort = serialPort,
        output = new SerialPortSink(serialPort);

  static Future<TtyConnection> connect(
      String address, String connectionDescription, void log(String message),
      {void onConnectionError(FileSystemException error),
      DiagnosticKind messageKind: DiagnosticKind.socketVmConnectError}) async {
    onConnectionError ??= (FileSystemException error) {
      String message = error.message;
      throwFatalError(messageKind, address: address, message: message);
    };

    SerialPort serialPort = new SerialPort(address, baudrate: 115200);
    try {
      await serialPort.open();
    } on FileSystemException catch (e) {
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
