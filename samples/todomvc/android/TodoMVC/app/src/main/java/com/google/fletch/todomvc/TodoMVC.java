// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.todomvc;

import android.app.Application;

import java.io.IOException;
import java.io.InputStream;

import fletch.FletchApi;
import fletch.FletchServiceApi;
import fletch.PatchSet;
import fletch.TodoMVCService;

public class TodoMVC extends Application {
  private void startDartServiceThread() {
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

  private void startFletchService() {
    // Load the library containing the fletch runtime
    // as well as the jni service code.
    System.loadLibrary("fletch");

    // Setup fletch and the service API.
    FletchApi.Setup();
    FletchServiceApi.Setup();

    // Tell fletch which library to use for foreign function lookups.
    FletchApi.AddDefaultSharedLibrary("libfletch.so");

    startDartServiceThread();

    // Setup the service.
    TodoMVCService.Setup();

    // Use the service.
    PatchSet patch = TodoMVCService.sync();
    System.out.println("First patch set of size: " + patch.getPatches().size());
  }

  @Override
  public void onCreate() {
    startFletchService();
  }
}
