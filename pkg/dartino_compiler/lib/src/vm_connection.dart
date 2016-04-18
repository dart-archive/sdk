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
    Socket,
    SocketException,
    SocketOption;

import 'verbs/infrastructure.dart' show
    DiagnosticKind,
    throwFatalError;

import 'hub/client_commands.dart' show
    handleSocketErrors;


abstract class VmConnection {
  Stream<List<int>> get input;
  IOSink get output;

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
