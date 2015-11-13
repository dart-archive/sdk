// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import fletch.*;

import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;

import java.util.List;

class PerformanceTest {
  static final int CALL_COUNT = 10000;
  static final int TREE_DEPTH = 7;

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
    try {
      runEcho();
      runAsyncEcho();
      runTreeTests();
    } finally {
      PerformanceService.TearDown();
    }
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

  private static int countTreeNodes(TreeNode node) {
    int sum = 1;
    TreeNodeList children = node.getChildren();
    for (int i = 0; i < children.size(); i++) {
      sum += countTreeNodes(children.get(i));
    }
    return sum;
  }

  private static void buildTree(int n, TreeNodeBuilder node) {
    if (n > 1) {
      TreeNodeListBuilder children = node.initChildren(2);
      buildTree(n - 1, children.get(0));
      buildTree(n - 1, children.get(1));
    }
  }

  private static void runTreeTests() {

    long start = System.currentTimeMillis();
    TreeNodeBuilder built = null;
    for (int i = 0; i < CALL_COUNT; i++) {
      MessageBuilder builder = new MessageBuilder(8192);
      built = new TreeNodeBuilder();
      builder.initRoot(built, TreeNodeBuilder.kSize);
      buildTree(TREE_DEPTH, built);
    }
    long end = System.currentTimeMillis();
    double us = (end - start) * 1000.0 / CALL_COUNT;
    System.out.println("Building (Java) took " + us + " us.");

    start = System.currentTimeMillis();
    for (int i = 0; i < CALL_COUNT; i++) {
      PerformanceService.countTreeNodes(built);
    }
    end = System.currentTimeMillis();
    us = (end - start) * 1000.0 / CALL_COUNT;
    System.out.println("Counting (Dart) took " + us + " us.");

    start = System.currentTimeMillis();
    for (int i = 0; i < CALL_COUNT; i++) {
      TreeNode generated = PerformanceService.buildTree(TREE_DEPTH);
    }
    end = System.currentTimeMillis();
    us = (end - start) * 1000.0 / CALL_COUNT;
    System.out.println("Building (Dart) took " + us + " us.");

    TreeNode generated = PerformanceService.buildTree(TREE_DEPTH);

    start = System.currentTimeMillis();
    for (int i = 0; i < CALL_COUNT; i++) {
      countTreeNodes(generated);
    }
    end = System.currentTimeMillis();
    us = (end - start) * 1000.0 / CALL_COUNT;
    System.out.println("Counting (Java) took " + us + " us.");
  }
}
