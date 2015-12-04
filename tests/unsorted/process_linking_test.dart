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

  print('monitorDuplicatePorts');
  monitorDuplicatePorts(DeathReason.CompileTimeError);
  monitorDuplicatePorts(DeathReason.Terminated);
  monitorDuplicatePorts(DeathReason.UncaughtException);

  print('indirectLinkTest');
  indirectLinkTest(DeathReason.CompileTimeError);
  indirectLinkTest(DeathReason.Terminated);
  indirectLinkTest(DeathReason.UncaughtException);

  print('unlinkTest');
  unlinkTest(DeathReason.CompileTimeError);
  unlinkTest(DeathReason.Terminated);
  unlinkTest(DeathReason.UncaughtException);

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

  print('failureOnParentUnlink');
  failureOnParentUnlinkTest();
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

monitorDuplicatePorts(DeathReason reason) {
  var grandChildChannel = new Channel();
  var grandChildPort = new Port(grandChildChannel);

  Process process = Process.spawnDetached(() {
    Process grandChild = Process.spawn(() {
      var c = new Channel();
      grandChildPort.send(Process.current);
      grandChildPort.send(new Port(c));

      c.receive();
      failWithDeathReason(reason);
    });
    blockInfinitly();
  });

  Process grandChild = grandChildChannel.receive();

  // Monitor the grand child 4 times
  var monitor = new Channel();
  var monitorPort = new Port(monitor);
  for (int i = 0; i < 4; i++) {
    grandChild.monitor(monitorPort);
  }

  // Unmonitor the grand child 2 times
  grandChild.unmonitor(monitorPort);
  grandChild.unmonitor(monitorPort);

  // Use the same port for monitoring the parent (which will die with a uncaught
  // signal error).
  process.monitor(monitorPort);

  // Trigger child failure.
  grandChildChannel.receive().send(null);

  // Ensure we get death 2 times from grand child
  for (int i = 0; i < 2; i++) {
    ProcessDeath death = monitor.receive();
    Expect.equals(grandChild, death.process);
    Expect.equals(reason, death.reason);
  }

  // To ensure we don't get more than 2 [ProcessDeath] messages from the grand
  // child we ensure the next death is the direct child.
  ProcessDeath death = monitor.receive();
  Expect.equals(process, death.process);
  Expect.equals(DeathReason.UnhandledSignal, death.reason);
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

unlinkTest(DeathReason reason) {
  var channel = new Channel();
  var monitorPort = new Port(channel);

  // We are linked after this call.
  Process process = Process.spawn(() {
    var c = new Channel();
    monitorPort.send(new Port(c));

    c.receive();
    failWithDeathReason(reason);
  });

  // Link 1 more time and unlink 2 times (=> we are no longer linked to it).
  process.link();
  process.unlink();
  process.unlink();

  // Monitor child
  process.monitor(monitorPort);

  // Let child die.
  channel.receive().send(null);

  // To ensure we don't get more than 2 [ProcessDeath] messages from the grand
  // child we ensure the next death is the direct child.
  ProcessDeath death = channel.receive();
  Expect.equals(process, death.process);
  Expect.equals(reason, death.reason);
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

failureOnParentUnlinkTest() {
  var monitor = new Channel();
  var port = new Port(monitor);

  var parent = Process.current;

  var process = Process.spawnDetached(() {
    Expect.throws(() => parent.unlink());
    port.send('success');
  }, monitor: port);

  Expect.equals('success', monitor.receive());

  ProcessDeath death = monitor.receive();
  Expect.equals(process, death.process);
  Expect.equals(DeathReason.Terminated, death.reason);
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
