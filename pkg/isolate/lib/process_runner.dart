// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library isolate.process_runner;

import 'dart:fletch';

class ProcessRunner {
  Channel _monitor;
  Port _monitorPort;
  int _spawnedProcesses = 0;
  bool _joining = false;

  ProcessRunner() {
    _monitor = new Channel();
    _monitorPort = new Port(_monitor);
  }

  Process run(fun()) {
    if (_joining) {
      throw new ArgumentError('Cannot spawn new processes after joining.');
    }

    _spawnedProcesses++;
    return Process.spawnDetached(fun, monitor: _monitorPort);
  }

  void join() {
    _joining = true;

    int failed = 0;

    int count = _spawnedProcesses;
    while (count > 0) {
      ProcessDeath death = _monitor.receive();
      if (death.reason != DeathReason.Terminated) {
        failed++;
      }
      count--;
    }

    if (failed > 0) {
      throw new Exception(
          '$failed out of $_spawnedProcesses processes did not terminate '
          'normally.');
    }
  }
}

withProcessRunner(fn(ProcessRunner runner)) {
  var runner = new ProcessRunner();
  try {
    return fn(runner);
  } finally {
    runner.join();
  }
}

