// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.app.Application;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

import fletch.FletchApi;
import fletch.FletchServiceApi;
import fletch.ImmiServiceLayer;

public class MainApplication extends Application {

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
    try (InputStream stream = getResources().openRawResource(R.raw.github_snapshot)) {
      final int bufferSize = 256;
      byte[] buffer = new byte[bufferSize];
      final ByteArrayOutputStream bytes = new ByteArrayOutputStream(stream.available());
      int bytesRead;
      while ((bytesRead = stream.read(buffer, 0, bufferSize)) >= 0) {
        bytes.write(buffer, 0, bytesRead);
      }
      Thread dartThread = new Thread(new DartRunner(bytes.toByteArray()));
      dartThread.start();
    } catch (IOException e) {
      System.err.println("Failed to start Dart service from snapshot.");
      System.exit(1);
    }
  }

  private void startFletchService() {
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
