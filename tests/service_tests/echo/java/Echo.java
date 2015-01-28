// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import fletch.FletchApi;
import fletch.FletchServiceApi;
import fletch.EchoService;

import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;

class Echo {
  public static void main(String args[]) {
    // Expecting a snapshot of the dart service code on the command line.
    if (args.length != 1) {
      System.out.println("Usage: java Echo <snapshot>");
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

    // Setup the echo service.
    EchoService.Setup();

    // Interact with the service.
    int result = EchoService.Echo(1);
    System.out.println("Java: result " + result);
    result = EchoService.Echo(2);
    System.out.println("Java: result " + result);
    EchoService.EchoAsync(3, new EchoService.EchoCallback() {
      public void handle(int result) {
        System.out.println("Java: async echo result " + result);
      }
    });
    System.out.println("Java: async echo call with argument " + 3);
    EchoService.SumAsync(3, 4, new EchoService.SumCallback() {
      public void handle(int result) {
        System.out.println("Java: async sum result " + result);
      }
    });
    System.out.println("Java: async sum call with arguments " + 3 + " " + 4);
    result = EchoService.Sum(3, 4);
    System.out.println("Java: result of sum(3, 4) is " + result);

    EchoService.TearDown();
  }

}
