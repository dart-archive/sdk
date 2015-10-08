// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Used for testing compiler/debugger session when VM socket is closed
/// unexpectedly.
library fletchc.test.driver.test_vm_connection;

import 'dart:async' show
    Future;

import 'dart:io' show
    InternetAddress;

import 'dart:isolate' show
    SendPort;

import 'package:expect/expect.dart' show
    Expect;

import 'package:fletchc/src/driver/session_manager.dart' show
    SessionState;

import 'package:fletchc/src/driver/developer.dart' show
    attachToVm;

import 'package:fletchc/commands.dart' show
    CommandCode;

import 'package:fletchc/src/driver/exit_codes.dart' show
    COMPILER_EXITCODE_CONNECTION_ERROR;

import '../run.dart' show
    FletchRunner;

import 'mock_vm.dart' show
    MockVm;

class MockVmRunner extends FletchRunner {
  final bool closeImmediately;
  final CommandCode closeAfterFirst;

  MockVm vm;

  MockVmRunner({this.closeImmediately: false, this.closeAfterFirst});

  Future<Null> attach(SessionState state) async {
    vm = await MockVm.spawn(
        closeImmediately: closeImmediately, closeAfterFirst: closeAfterFirst);
    await attachToVm(InternetAddress.LOOPBACK_IP_V4.address, vm.port, state);
  }

  Future run(List<String> arguments) async {
    int runExit = await super.run(arguments);
    int exitCode = await vm.exitCode;
    // Mock VM always exits with 0.
    Expect.equals(0, exitCode);
    print("Mock VM exited");
    return runExit;
  }
}

main(List<String> arguments) async {
  Expect.equals(0, await new MockVmRunner().run(arguments));
}

Future<Null> test() => main(<String>['tests/language/application_test.dart']);

Future<Null> testCloseImmediately() async {
  int result = await new MockVmRunner(closeImmediately: true)
      .run(<String>['tests/language/application_test.dart']);
  Expect.equals(COMPILER_EXITCODE_CONNECTION_ERROR, result);
}

Future<Null> testCloseAfterCommitChanges() async {
  int result =
      await new MockVmRunner(closeAfterFirst: CommandCode.CommitChanges)
      .run(<String>['tests/language/application_test.dart']);
  Expect.equals(COMPILER_EXITCODE_CONNECTION_ERROR, result);
}

Future<Null> testCloseAfterProcessRun() async {
  int result = await new MockVmRunner(closeAfterFirst: CommandCode.ProcessRun)
      .run(<String>['tests/language/application_test.dart']);
  Expect.equals(COMPILER_EXITCODE_CONNECTION_ERROR, result);
}
