// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.driver_commands;

import 'dart:io' show
    Socket;

import 'dart:async' show
    StreamSubscription;

import 'dart:typed_data' show
    Uint8List;

import 'dart:convert' show
    UTF8;

import '../console_print.dart' show
    printToConsole;

enum DriverCommand {
  // Note: if you modify this enum, please modify src/tools/driver/connection.h
  // as well.

  /// Data on stdin.
  Stdin,

  /// Data on stdout.
  Stdout,

  /// Data on stderr.
  Stderr,

  /// Command-line arguments.
  Arguments,

  /// Unix process signal received.
  Signal,

  /// Set process exit code.
  ExitCode,

  /// Tell the receiver that commands will be processed immediatly.
  EventLoopStarted,

  /// Tell receiver to close the port this was sent to.
  ClosePort,

  /// A SendPort that the receiver can use to communicate with the sender.
  SendPort,

  /// The the receiver to perform a task.
  PerformTask,

  /// Error in connection.
  DriverConnectionError,

  /// Connection closed.
  DriverConnectionClosed,
}

class Command {
  final DriverCommand code;
  final data;

  Command(this.code, this.data);

  String toString() => 'Command($code, $data)';
}

abstract class CommandSender {
  void sendExitCode(int exitCode);

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

  void sendDataCommand(DriverCommand command, List<int> data);

  void sendClose();

  void sendEventLoopStarted();
}

Function makeErrorHandler(String info) {
  return (error, StackTrace stackTrace) {
    printToConsole("Error on $info: ${stringifyError(error, stackTrace)}");
  };
}

Socket handleSocketErrors(Socket socket, String name, {void log(String info)}) {
  String host = "?";
  String remotePort = "?";
  try {
    host = "${socket.remoteAddress.host}";
    remotePort = "${socket.remotePort}";
  } catch (_) {
    // Ignored, socket.remotePort may fail if the socket was closed on the
    // other side.
  }
  String info = "$name ${socket.port} -> $host:$remotePort";
  if (log != null) {
    log(info);
  }
  socket.done.catchError(makeErrorHandler(info));
  return socket;
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
