// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';

main() {
  print('simpleMonitorTest');
  simpleMonitorTest(DeathReason.CompileTimeError);
  simpleMonitorTest(DeathReason.Terminated);
  simpleMonitorTest(DeathReason.UncaughtException);

  print('multipleMonitorPortsTest');
  multipleMonitorPortsTest(DeathReason.CompileTimeError);
  multipleMonitorPortsTest(DeathReason.Terminated);
  multipleMonitorPortsTest(DeathReason.UncaughtException);

  print('indirectLinkTest');
  indirectLinkTest(DeathReason.CompileTimeError);
  indirectLinkTest(DeathReason.Terminated);
  indirectLinkTest(DeathReason.UncaughtException);

  print('postMonitorProcessTest');
  postMonitorProcessTest(DeathReason.CompileTimeError);
  postMonitorProcessTest(DeathReason.Terminated);
  postMonitorProcessTest(DeathReason.UncaughtException);

  print('deathOrderTest');
  deathOrderTest(DeathReason.CompileTimeError);
  deathOrderTest(DeathReason.Terminated);
  deathOrderTest(DeathReason.UncaughtException);

  print('deathOrderTest2');
  deathOrderTest2(DeathReason.CompileTimeError);
  deathOrderTest2(DeathReason.Terminated);
  deathOrderTest2(DeathReason.UncaughtException);
}

simpleMonitorTest(DeathReason reason) {
  var monitor = new Channel();
  var process = Process.spawnDetached(() => failWithDeathReason(reason),
      monitor: new Port(monitor));

  ProcessDeath death = monitor.receive();
  Expect.equals(process, death.process);
  Expect.equals(reason, death.reason);
}

multipleMonitorPortsTest(DeathReason reason) {
  var paused = new Channel();
  var pausedPort = new Port(paused);

  Process process = Process.spawnDetached(() {
    var c = new Channel();
    pausedPort.send(new Port(c));
    c.receive();

    failWithDeathReason(reason);
  });

  var resumePort = paused.receive();

  var monitor = new Channel();
  var monitor2 = new Channel();

  process.monitor(new Port(monitor));
  process.monitor(new Port(monitor2));
  process.monitor(new Port(monitor2));

  resumePort.send(null);

  Expect.equals(reason, monitor.receive().reason);
  Expect.equals(reason, monitor2.receive().reason);
  Expect.equals(reason, monitor2.receive().reason);
}

indirectLinkTest(DeathReason reason) {
  spawnProcessList(Port replyPort) {
    p2(Port reply) {
      failWithDeathReason(reason);
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
  var process = Process.spawnDetached(() => spawnProcessList(resultPort),
      monitor: new Port(monitor));
  if (reason == DeathReason.Terminated) {
    Expect.equals('everything-is-awesome', result.receive());
  }
  ProcessDeath death = monitor.receive();
  Expect.equals(process, death.process);
  Expect.equals(DeathReason.UnhandledSignal, death.reason);
}

postMonitorProcessTest(DeathReason reason) {
  var parentChannel = new Channel();
  final parentPort = new Port(parentChannel);
  Process process = Process.spawnDetached(() {
    // Wait until parent is ready.
    var c = new Channel();
    parentPort.send(new Port(c));
    DeathReason reason = c.receive();

    failWithDeathReason(reason);
  });

  // Start montitoring the child.
  var monitor = new Channel();
  Expect.isTrue(process.monitor(new Port(monitor)));

  // Signal the child it can die now.
  parentChannel.receive().send(reason);

  ProcessDeath death = monitor.receive();
  Expect.equals(process, death.process);
  Expect.equals(reason, death.reason);
}

deathOrderTest(DeathReason reason) {
  var monitor = new Channel();
  var monitorPort = new Port(monitor);

  // The processes are like this:
  // [main] ---monitors---> [p1] <--link--> [p2]
  // and [p2] dies.

  var root = Process.spawnDetached(() {
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
    failWithDeathReason(reason);
  }, monitor: monitorPort);

  ProcessDeath death1 = monitor.receive();
  Expect.equals(DeathReason.UnhandledSignal, death1.reason);

  ProcessDeath death2 = monitor.receive();
  Expect.equals(root, death2.process);
  Expect.equals(reason, death2.reason);
}

deathOrderTest2(DeathReason reason) {
  var monitor = new Channel();
  var monitorPort = new Port(monitor);

  // The processes are like this:
  // [main] ---monitors---> [p1] <--link--> [p2]
  // and [p1] dies.

  var root = Process.spawnDetached(() {
    var c = new Channel();
    final grandchildReadyPort = new Port(c);
    var child = Process.spawn(() {
      var c = new Channel();
      grandchildReadyPort.send(new Port(c));

      // Wait until parent monitored us.
      c.receive();

      // And fail.
      failWithDeathReason(reason);
    });
    child.monitor(monitorPort);

    // Tell grandchild it can fail now.
    c.receive().send(1);

    blockInfinitly();
  }, monitor: monitorPort);

  ProcessDeath death1 = monitor.receive();
  Expect.equals(reason, death1.reason);

  ProcessDeath death2 = monitor.receive();
  Expect.equals(root, death2.process);
  Expect.equals(DeathReason.UnhandledSignal, death2.reason);
}

failWithDeathReason(DeathReason reason) {
  if (reason == DeathReason.UncaughtException) throw 'failing';
  if (reason == DeathReason.CompileTimeError) failWithCompileTimeError();
  assert(reason == DeathReason.Terminated);
}

failWithCompileTimeError() {
  a b c;
}

blockInfinitly() => new Channel().receive();
