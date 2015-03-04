// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import fletch.*;

import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;

class ConformanceTest {
  public static void main(String args[]) {
    // Expecting a snapshot of the dart service code on the command line.
    if (args.length != 1) {
      System.out.println("Usage: java ConformanceTest <snapshot>");
      System.exit(1);
    }

    // Load libfletch.so.
    System.loadLibrary("fletch");

    // Setup Fletch.
    FletchApi.Setup();
    FletchServiceApi.Setup();
    FletchApi.AddDefaultSharedLibrary("libfletch.so");

    try {
      // Load snapshot and start Dart code on a separate thread.
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

    // Run conformance tests.
    ConformanceService.Setup();
    runPersonTests();
    runNodeTests();
    ConformanceService.TearDown();
  }

  private static void runPersonTests() {
    ConformanceService.foo();
    ConformanceService.fooAsync(new ConformanceService.FooCallback() {
        public void handle() { }
    });

    assert 42 == ConformanceService.ping();
    ConformanceService.pingAsync(new ConformanceService.PingCallback() {
        public void handle(int result) { assert 42 == result; }
    });

    AgeStats stats = ConformanceService.createAgeStats(42, 42);
    assert 42 == stats.getAverageAge();
    assert 42 == stats.getSum();
  }

  private static int depth(Node node) {
    if (node.isNum()) return 1;
    int left = depth(node.getCons().getFst());
    int right = depth(node.getCons().getSnd());
    return 1 + ((left > right) ? left : right);
  }

  private static void runNodeTests() {
    Node node = ConformanceService.createNode(10);
    assert 24680 == node.computeUsed();
    assert 10 == depth(node);
  }
}
