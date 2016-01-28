// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Used for testing compiler/debugger session when VM socket is closed
/// unexpectedly.
library fletchc.test.client.test_vm_connection;

import 'dart:async' show
    Future;

import 'dart:io' show
    InternetAddress;

import 'dart:isolate' show
    SendPort;

import 'package:expect/expect.dart' show
    Expect;

import 'package:fletchc/src/hub/session_manager.dart' show
    SessionState;

import 'package:fletchc/src/worker/developer.dart' show
    attachToVm;

import 'package:fletchc/vm_commands.dart' show
    VmCommandCode;

import '../run.dart' show
    FletchRunner;

import 'mock_vm.dart' show
    MockVm;

class MockVmRunner extends FletchRunner {
  final bool closeImmediately;
  final VmCommandCode closeAfterFirst;

  MockVm vm;

  MockVmRunner({this.closeImmediately: false, this.closeAfterFirst});

  Future<Null> attach(SessionState state) async {
    vm = await MockVm.spawn(
        closeImmediately: closeImmediately, closeAfterFirst: closeAfterFirst);
    await attachToVm(InternetAddress.LOOPBACK_IP_V4.address, vm.port, state);
  }

  Future<int> run(List<String> arguments, {int expectedExitCode: 0}) async {
    await super.run(arguments);
    int exitCode = await vm.exitCode;
    print("Mock VM exit code: $exitCode");
    return exitCode;
  }
}

main(List<String> arguments) async {
  await new MockVmRunner().run(arguments);
}

Future<Null> test() => main(<String>['tests/language/application_test.dart']);

Future<Null> testCloseImmediately() async {
  int result = await new MockVmRunner(closeImmediately: true)
      .run(<String>['tests/language/application_test.dart']);
  // TODO(ahe): The actual exit code is TBD.
  Expect.equals(1, result);
}

Future<Null> testCloseAfterCommitChanges() async {
  int result =
      await new MockVmRunner(closeAfterFirst: VmCommandCode.CommitChanges)
      .run(<String>['tests/language/application_test.dart']);
  // TODO(ahe): The actual exit code is TBD.
  Expect.equals(1, result);
}

Future<Null> testCloseAfterProcessRun() async {
  int result = await new MockVmRunner(closeAfterFirst: VmCommandCode.ProcessRun)
      .run(<String>['tests/language/application_test.dart']);
  // TODO(ahe): The actual exit code is TBD.
  Expect.equals(1, result);
}
