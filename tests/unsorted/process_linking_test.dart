// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';

main() {
  print('simpleMonitorTest');
  simpleMonitorTest(SignalKind.CompileTimeError);
  simpleMonitorTest(SignalKind.Terminated);
  simpleMonitorTest(SignalKind.UncaughtException);

  print('multipleMonitorPortsTest');
  multipleMonitorPortsTest(SignalKind.CompileTimeError);
  multipleMonitorPortsTest(SignalKind.Terminated);
  multipleMonitorPortsTest(SignalKind.UncaughtException);

  print('indirectLinkTest');
  indirectLinkTest(SignalKind.CompileTimeError);
  indirectLinkTest(SignalKind.Terminated);
  indirectLinkTest(SignalKind.UncaughtException);

  print('postMonitorProcessTest');
  postMonitorProcessTest(SignalKind.CompileTimeError);
  postMonitorProcessTest(SignalKind.Terminated);
  postMonitorProcessTest(SignalKind.UncaughtException);

  print('deathOrderTest');
  deathOrderTest(SignalKind.CompileTimeError);
  deathOrderTest(SignalKind.Terminated);
  deathOrderTest(SignalKind.UncaughtException);

  print('deathOrderTest2');
  deathOrderTest2(SignalKind.CompileTimeError);
  deathOrderTest2(SignalKind.Terminated);
  deathOrderTest2(SignalKind.UncaughtException);
}

simpleMonitorTest(SignalKind kind) {
  var monitor = new Channel();
  Process.spawnDetached(() => failWithSignalKind(kind),
      monitor: new Port(monitor));

  Expect.equals(kind.index, monitor.receive());
}

multipleMonitorPortsTest(SignalKind kind) {
  var paused = new Channel();
  var pausedPort = new Port(paused);

  Process process = Process.spawnDetached(() {
    var c = new Channel();
    pausedPort.send(new Port(c));
    c.receive();

    failWithSignalKind(kind);
  });

  var resumePort = paused.receive();

  var monitor = new Channel();
  var monitor2 = new Channel();

  process.monitor(new Port(monitor));
  process.monitor(new Port(monitor2));
  process.monitor(new Port(monitor2));

  resumePort.send(null);

  Expect.equals(kind.index, monitor.receive());
  Expect.equals(kind.index, monitor2.receive());
  Expect.equals(kind.index, monitor2.receive());
}

indirectLinkTest(SignalKind kind) {
  spawnProcessList(Port replyPort) {
    p2(Port reply) {
      failWithSignalKind(kind);
      reply.send('everything-is-awesome');
    }
    p1(Port reply) {
      Process.spawn(() => p2(reply));
      blockInfinitly();
    }

    Process.spawn(() => p1(replyPort));
    blockInfinitly();
  }

  var monitor = new Channel();
  var result = new Channel();
  var resultPort = new Port(result);
  Process.spawnDetached(() => spawnProcessList(resultPort),
      monitor: new Port(monitor));
  if (kind == SignalKind.Terminated) {
    Expect.equals('everything-is-awesome', result.receive());
  }
  Expect.equals(SignalKind.UnhandledSignal.index, monitor.receive());
}

postMonitorProcessTest(SignalKind kind) {
  var parentChannel = new Channel();
  final parentPort = new Port(parentChannel);
  Process process = Process.spawnDetached(() {
    // Wait until parent is ready.
    var c = new Channel();
    parentPort.send(new Port(c));
    SignalKind kind = c.receive();

    failWithSignalKind(kind);
  });

  // Start montitoring the child.
  var monitor = new Channel();
  Expect.isTrue(process.monitor(new Port(monitor)));

  // Signal the child it can die now.
  parentChannel.receive().send(kind);

  Expect.equals(kind.index, monitor.receive());
}

deathOrderTest(SignalKind kind) {
  var monitor = new Channel();
  var monitorPort = new Port(monitor);

  // The processes are like this:
  // [main] ---monitors---> [p1] <--link--> [p2]
  // and [p2] dies.

  Process.spawnDetached(() {
    var c = new Channel();
    final grandchildReadyPort = new Port(c);
    var child = Process.spawn(() {
      grandchildReadyPort.send(1);
      blockInfinitly();
    });
    child.monitor(monitorPort);

    // Wait for grandchild to be ready.
    c.receive();

    // And fail.
    failWithSignalKind(kind);
  }, monitor: monitorPort);

  Expect.equals(SignalKind.UnhandledSignal.index, monitor.receive());
  Expect.equals(kind.index, monitor.receive());
}

deathOrderTest2(SignalKind kind) {
  var monitor = new Channel();
  var monitorPort = new Port(monitor);

  // The processes are like this:
  // [main] ---monitors---> [p1] <--link--> [p2]
  // and [p1] dies.

  Process.spawnDetached(() {
    var c = new Channel();
    final grandchildReadyPort = new Port(c);
    var child = Process.spawn(() {
      var c = new Channel();
      grandchildReadyPort.send(new Port(c));

      // Wait until parent monitored us.
      c.receive();

      // And fail.
      failWithSignalKind(kind);
    });
    child.monitor(monitorPort);

    // Tell grandchild it can fail now.
    c.receive().send(1);

    blockInfinitly();
  }, monitor: monitorPort);

  Expect.equals(kind.index, monitor.receive());
  Expect.equals(SignalKind.UnhandledSignal.index, monitor.receive());
}

failWithSignalKind(SignalKind kind) {
  if (kind == SignalKind.UncaughtException) throw 'failing';
  if (kind == SignalKind.CompileTimeError) failWithCompileTimeError();
  assert(kind == SignalKind.Terminated);
}

failWithCompileTimeError() {
  a b c;
}

blockInfinitly() => new Channel().receive();
