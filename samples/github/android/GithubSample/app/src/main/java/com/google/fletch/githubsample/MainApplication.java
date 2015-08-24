// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.app.Application;

import java.io.IOException;
import java.io.InputStream;

import fletch.FletchApi;
import fletch.FletchServiceApi;
import fletch.ImmiServiceLayer;

public class MainApplication extends Application {

  static boolean attachNativeDebugger = false;
  static boolean attachDartDebugger = false;
  static int debugPortNumber = 8123;

  private void startDartServiceThread() {
    // Start a thread waiting for the Fletch debugger to attach.
    if (attachDartDebugger) {
      System.out.println("Waiting for debugger connection on port " + debugPortNumber);
      Thread dartThread = new Thread(new DartDebugger(debugPortNumber));
      dartThread.start();
      return;
    }
    // Load snapshot and start dart code on a separate thread.
    InputStream snapshotStream = getResources().openRawResource(R.raw.github_snapshot);
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
    if (attachNativeDebugger) {
      try {
        System.out.println("sleeping for native debugger attatch");
        Thread.sleep(20000);
        System.out.println("resumed execution");
      } catch (InterruptedException e) {
        e.printStackTrace();
      }
    }
    System.loadLibrary("fletch");
    FletchApi.Setup();
    FletchServiceApi.Setup();
    FletchApi.AddDefaultSharedLibrary("libfletch.so");
    startDartServiceThread();
    ImmiServiceLayer.Setup();
  }

  @Override
  public void onCreate() {
    super.onCreate();
    startFletchService();
  }
}
