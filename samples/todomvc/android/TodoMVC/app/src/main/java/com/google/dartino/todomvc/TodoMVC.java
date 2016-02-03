// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.dartino.todomvc;

import android.app.Application;

import java.io.IOException;
import java.io.InputStream;

import dartino.DartinoApi;
import dartino.DartinoServiceApi;
import dartino.TodoMVCService;

public class TodoMVC extends Application {

  static boolean attachDebugger = false;
  static int debugPortNumber = 8123;

  private void startDartServiceThread() {
    if (attachDebugger) {
      System.out.println("Waiting for debugger connection on port " + debugPortNumber);
      Thread dartThread = new Thread(new DartDebugger(debugPortNumber));
      dartThread.start();
      return;
    }
    // Load snapshot and start dart code on a separate thread.
    InputStream snapshotStream = getResources().openRawResource(R.raw.todomvc_snapshot);
    try {
      int available = snapshotStream.available();
      byte[] snapshot = new byte[available];
      snapshotStream.read(snapshot);
      Thread dartThread = new Thread(new DartRunner(snapshot));
      dartThread.start();
    } catch (IOException e) {
      System.err.println("Failed to start Dart service from snapshot.");
      System.exit(1);
    }
  }

  private void startDartinoService() {
    // Load the library containing the dartino runtime
    // as well as the jni service code.
    System.loadLibrary("dartino");

    // Setup dartino and the service API.
    DartinoApi.Setup();
    DartinoServiceApi.Setup();

    // Tell dartino which library to use for foreign function lookups.
    DartinoApi.AddDefaultSharedLibrary("libdartino.so");

    startDartServiceThread();

    // Setup the service.
    TodoMVCService.Setup();
  }

  @Override
  public void onCreate() {
    startDartinoService();
  }
}
