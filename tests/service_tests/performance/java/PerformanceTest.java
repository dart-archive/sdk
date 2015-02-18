// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import fletch.FletchApi;
import fletch.FletchServiceApi;
import fletch.PerformanceService;

import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;

class PerformanceTest {
  static final int CALL_COUNT = 10000;

  public static void main(String args[]) {
    // Expecting a snapshot of the dart service code on the command line.
    if (args.length != 1) {
      System.out.println("Usage: java PerformanceTest <snapshot>");
      System.exit(1);
    }

    // Load libfletch.so.
    System.loadLibrary("fletch");

    // Setup Fletch.
    FletchApi.Setup();
    FletchServiceApi.Setup();
    FletchApi.AddDefaultSharedLibrary("libfletch.so");

    try {
      // Load snapshot and start dart code on a separate thread.
      FileInputStream snapshotStream = new FileInputStream(args[0]);
      int available = snapshotStream.available();
      byte[] snapshot = new byte[available];
      snapshotStream.read(snapshot);
      Thread dartThread = new Thread(new SnapshotRunner(snapshot));
      dartThread.start();
    } catch (FileNotFoundException e) {
      System.err.println("Failed loading snapshot");
      System.exit(1);
    } catch (IOException e) {
      System.err.println("Failed loading snapshot");
      System.exit(1);
    }

    // Run performance tests.
    PerformanceService.Setup();
    runEcho();
    runAsyncEcho();
    PerformanceService.TearDown();
  }

  private static void runEcho() {
    long start = System.currentTimeMillis();
    for (int i = 0; i < CALL_COUNT; i++) {
      int result = PerformanceService.echo(i);
      if (i != result) throw new RuntimeException("Wrong result");
    }
    long end = System.currentTimeMillis();
    double us = (end - start) * 1000.0 / CALL_COUNT;
    System.out.println("Sync call took " + us + " us.");
  }

  private static void runAsyncEcho() {
    final Object monitor = new Object();
    final PerformanceService.EchoCallback[] callback =
      new PerformanceService.EchoCallback[1];

    final long start = System.currentTimeMillis();
    callback[0] = new PerformanceService.EchoCallback() {
      public void handle(int i) {
        if (i < CALL_COUNT) {
          PerformanceService.echoAsync(i + 1, callback[0]);
        } else {
          synchronized (monitor) {
            monitor.notify();
          }
        }
      }
    };

    synchronized (monitor) {
      boolean done = false;
      PerformanceService.echoAsync(0, callback[0]);
      while (!done) {
        try {
          monitor.wait();
          done = true;
        } catch (InterruptedException e) {
          // Ignored.
        }
      }
    }

    long end = System.currentTimeMillis();
    double us = (end - start) * 1000.0 / CALL_COUNT;
    System.out.println("Async call took " + us + " us.");
  }
}
