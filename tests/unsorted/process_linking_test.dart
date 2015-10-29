// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';
import 'dart:fletch.ffi';

import 'package:expect/expect.dart';

main() {
  simpleMonitorTest(SignalKind.CompileTimeError);
  simpleMonitorTest(SignalKind.Terminated);
  simpleMonitorTest(SignalKind.UncaughtException);

  multipleMonitorPortsTest(SignalKind.CompileTimeError);
  multipleMonitorPortsTest(SignalKind.Terminated);
  multipleMonitorPortsTest(SignalKind.UncaughtException);

  indirectLinkTest(SignalKind.CompileTimeError);
  indirectLinkTest(SignalKind.Terminated);
  indirectLinkTest(SignalKind.UncaughtException);

  postLinkProcessTest(SignalKind.CompileTimeError);
  postLinkProcessTest(SignalKind.Terminated);
  postLinkProcessTest(SignalKind.UncaughtException);

  postMonitorProcessTest(SignalKind.CompileTimeError);
  postMonitorProcessTest(SignalKind.Terminated);
  postMonitorProcessTest(SignalKind.UncaughtException);

  // Currently the VM sets after the first issue an exit code (e.g. compile-time
  // error or uncaught exception). To make sure this test exists with 0, we exit
  // manually here.
  //
  // Of course this doesn't work if a session is attached, so this only works in
  // the '--compiler=fletchc --runtime=fletchvm' configuration ATM.
  ForeignLibrary.main.lookup('exit').icall$1(0);
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
  // This test has the following hierarchy of processes:
  // [main] ---monitors---> [processList] <--link--> [p1] <--link--> [p2]
  //
  // Then [main] will send [p2] a [SignalKind] and depending on what this does
  // it either
  //    * exists [p2->p1->processList] with CompileTimeError/UncaughtException
  //    * exists [p2->p1->processList] normally

  spawnProcessList(Port replyPort) {
    p2(Port killPort, Port reply) {
      var c = new Channel();
      killPort.send(new Port(c));
      var sig = c.receive();
      failWithSignalKind(sig);
      reply.send('success');
    }
    p1(Port killPort, Port reply) {
      var c = new Channel();
      var port = new Port(c);
      Process.spawn(() => p2(killPort, port));
      reply.send(c.receive());
    }

    var killChannel = new Channel();
    var killPort = new Port(killChannel);

    var c = new Channel();
    var port = new Port(c);
    Process.spawn(() => p1(killPort, port));

    killChannel.receive().send(kind);
    Expect.equals('success', c.receive());

    replyPort.send('everything-is-awesome');
  }

  var monitor = new Channel();
  var result = new Channel();
  var resultPort = new Port(result);
  Process.spawnDetached(() => spawnProcessList(resultPort),
      monitor: new Port(monitor));
  if (kind == SignalKind.Terminated) {
    Expect.equals('everything-is-awesome', result.receive());
  }
  Expect.equals(kind.index, monitor.receive());
}

postLinkProcessTest(SignalKind kind) {
  // This test has the following hierarchy of processes:
  // [main] ---monitors---> [p1] <--link--> [p2]

  p2(Port killPort, Port reply) {
    var c = new Channel();
    killPort.send(new Port(c));
    var sig = c.receive();
    failWithSignalKind(sig);
    reply.send('success');
  }

  p1(Port replyPort) {
    var killChannel = new Channel();
    var killPort = new Port(killChannel);

    var c = new Channel();
    var port = new Port(c);
    Process process = Process.spawnDetached(() => p2(killPort, port));

    // NOTE: We link after spawning and then signal the child process to exit
    // with a specific [kind].
    Expect.isTrue(process.link());
    killChannel.receive().send(kind);

    // Either the child died unexpectedly and we die as well or we get a success
    // message and send it further to our parent.
    Expect.equals('success', c.receive());
    replyPort.send('everything-is-awesome');
  }

  var monitor = new Channel();
  var result = new Channel();
  var resultPort = new Port(result);
  Process.spawnDetached(() => p1(resultPort), monitor: new Port(monitor));
  if (kind == SignalKind.Terminated) {
    Expect.equals('everything-is-awesome', result.receive());
  }
  Expect.equals(kind.index, monitor.receive());
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

failWithSignalKind(SignalKind kind) {
  if (kind == SignalKind.UncaughtException) throw 'failing';
  if (kind == SignalKind.CompileTimeError) failWithCompileTimeError();
  assert(kind == SignalKind.Terminated);
}

failWithCompileTimeError() {
  a b c;
}
