// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Mock VM implementation used for testing VM connections.
library fletchc.test.client.mock_vm;

import 'dart:async' show
    Future,
    StreamIterator;

import 'dart:io' show
    InternetAddress,
    ServerSocket,
    Socket;

import 'dart:isolate' show
    ReceivePort,
    SendPort;

import 'dart:typed_data' show
    ByteData;

import 'package:fletchc/src/shared_command_infrastructure.dart' show
    CommandTransformerBuilder,
    toUint8ListView;

import 'package:fletchc/vm_commands.dart' show
    VmCommand,
    VmCommandCode,
    CommitChangesResult,
    HandShakeResult,
    ProcessTerminated;

import 'package:dart_isolate/ports.dart' show
    singleResponseFuture;

import 'package:dart_isolate/isolate_runner.dart' show
    IsolateRunner;

import 'package:fletchc/src/zone_helper.dart' show
    runGuarded;

/// Represents state associated with a mocked VM.
class MockVm {
  /// Port number the mock VM is listening on. Host is always 127.0.0.1.
  final int port;

  /// Future completes with VM's exit code.
  final Future<int> exitCode;

  // Internal.
  final IsolateRunner isolate;

  MockVm(this.port, this.isolate, this.exitCode);

  /// Create a new MockVm.
  /// If [closeImmediately] is true, the mock VM will close its socket
  /// immediately after accepting an incoming connection.
  /// If [closeAfterFirst] is non-null, the mock VM will close its socket
  /// immediately after receiving a command with that code.
  /// [closeImmediately] and [closeAfterFirst] can't be used together.
  static Future<MockVm> spawn(
      {bool closeImmediately: false,
       VmCommandCode closeAfterFirst}) async {
    if (closeImmediately && closeAfterFirst != null) {
      throw new ArgumentError(
          "[closeImmediately] and [closeAfterFirst] can't be used together");
    }
    IsolateRunner isolate = await IsolateRunner.spawn();
    Future exitCode;
    ReceivePort stdout = new ReceivePort();
    stdout.listen(print);
    int port = await singleResponseFuture((SendPort port) {
      int index = closeAfterFirst == null ? -1 : closeAfterFirst.index;
      var arguments = new MockVmArguments(
          port, closeImmediately, index, stdout.sendPort);
      exitCode = isolate.run(mockVm, arguments)
          .whenComplete(stdout.close)
          .whenComplete(isolate.close);
    });
    return new MockVm(port, isolate, exitCode);
  }
}

/// Encodes arguments to [mockVm].
class MockVmArguments {
  // Keep this class simple. See notice in `SharedTask` in
  // `package:fletchc/src/verbs/infrastructure.dart`.

  final SendPort port;
  final bool closeImmediately;
  final int closeAfterFirstIndex;
  final SendPort stdout;

  const MockVmArguments(
      this.port,
      this.closeImmediately,
      this.closeAfterFirstIndex,
      this.stdout);

  VmCommandCode get closeAfterFirst {
    return closeAfterFirstIndex == -1
        ? null : VmCommandCode.values[closeAfterFirstIndex];
  }
}

/// See [MockVm.spawn].
Future<int> mockVm(MockVmArguments arguments) async {
  int exitCode = 0;
  await runGuarded(() async {
    Socket socket = await compilerConnection(arguments.port);
    if (arguments.closeImmediately) {
      socket.listen(null).cancel();
      await socket.close();
      return;
    }
    var transformer = new MockCommandTransformerBuilder().build();
    await for (var command in socket.transform(transformer)) {
      VmCommandCode code = command[0];
      if (arguments.closeAfterFirst == code) break;
      VmCommand reply = mockReply(code);
      if (reply == null) {
        print(command);
      } else {
        reply.addTo(socket);
        await socket.flush();
      }
    }
    await socket.close();
  }, printLineOnStdout: arguments.stdout.send);
  return exitCode;
}

/// Transform List<int> (socket datagrams) to a two-element list of
/// `[VmCommandCode, payload]`.
class MockCommandTransformerBuilder extends CommandTransformerBuilder<List> {
  List makeCommand(int code, ByteData payload) {
    return [VmCommandCode.values[code], toUint8ListView(payload)];
  }
}

/// Listens for a single connection from a compiler/debugger/etc. When the
/// server is started, its port number is returned on [port] letting a listener
/// know that the server is ready and listening for a connection.
Future<Socket> compilerConnection(SendPort port) async {
  ServerSocket server =
      await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);
  port.send(server.port);
  var connectionIterator = new StreamIterator(server);
  if (!await connectionIterator.moveNext()) {
    throw "ServerSocket didn't get a connection";
  }
  Socket socket = connectionIterator.current;
  await server.close();
  while (await connectionIterator.moveNext()) {
    throw "unexpected connection: ${connectionIterator.current}";
  }
  return socket;
}

/// Mock a reply if [code] requires a response for the compiler/debugger to
/// make progress.
VmCommand mockReply(VmCommandCode code) {
  // Please add more cases as needed.
  switch (code) {
    case VmCommandCode.HandShake:
      return new HandShakeResult(true, "");

    case VmCommandCode.CommitChanges:
      return new CommitChangesResult(
          true, "Successfully applied program update.");

    case VmCommandCode.ProcessRun:
      return const ProcessTerminated();

    default:
      return null;
  }
}
