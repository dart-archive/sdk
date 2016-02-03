// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.dartino.githubmock;

import android.app.Service;
import android.content.Intent;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.os.Looper;
import android.os.Message;
import android.util.Log;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

import dartino.DartinoApi;
import dartino.DartinoServiceApi;

/**
 * Service running a mock github http server.
 */
public class GithubMockServer extends Service {

  @Override
  public void onCreate() {
    super.onCreate();
    startThread();
    startDartino();
  }

  @Override
  public void onDestroy() {
    stopDartino();
    stopThread();
  }

  @Override
  public int onStartCommand(Intent intent, int flags, int startId) {
    Message message = handler.obtainMessage();
    message.obj = intent;
    handler.sendMessage(message);
    return START_REDELIVER_INTENT;
  }

  @Override
  public IBinder onBind(Intent intent) {
    return null;
  }

  private final class MockHandler extends Handler {
    public MockHandler(Looper looper) {
      super(looper);
    }

    @Override
    public void handleMessage(Message message) {
      if (message.obj == null) return;
      final Intent intent = (Intent)message.obj;
      final String action = intent.getAction();
      if (ACTION_ENSURE_SERVER.equals(action)) {
        handleActionEnsureServer();
      }
    }
  }

  /**
   * Ensure that the github mock server is running and broadcast its port.
   */
  private void handleActionEnsureServer() {
    // Broadcast the server port.
    Intent statusIntent = new Intent(ACTION_BROADCAST_STATUS);
    statusIntent.setPackage(GITHUB_SAMPLE_PACKAGE);
    statusIntent.putExtra(STATUS_DATA, SERVER_PORT);
    sendBroadcast(statusIntent);
  }

  private void startThread() {
    HandlerThread thread = new HandlerThread("GithubMockServer");
    thread.start();
    looper = thread.getLooper();
    handler = new MockHandler(looper);
  }

  private void stopThread() {
    looper.quit();
  }

  private void startDartino() {
    System.loadLibrary("dartino");
    DartinoApi.Setup();
    DartinoServiceApi.Setup();
    DartinoApi.AddDefaultSharedLibrary("libdartino.so");
    DartinoApi.RegisterPrintInterceptor(new PrintInterceptor());
    try (InputStream stream = getResources().openRawResource(R.raw.snapshot)) {
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
    dartino.GithubMockServer.Setup();
    dartino.GithubMockServer.start(SERVER_PORT);
  }

  private void stopDartino() {
    dartino.GithubMockServer.stop();
    dartino.GithubMockServer.TearDown();
    DartinoServiceApi.TearDown();
    DartinoApi.TearDown();
  }

  private class PrintInterceptor extends DartinoApi.PrintInterceptor {
    @Override public void Out(String message) { Log.i(TAG, message); }
    @Override public void Error(String message) { Log.e(TAG, message); }
    private static final String TAG = "Dartino";
  }

  private static final String GITHUB_SAMPLE_PACKAGE =
      "com.google.dartino.githubsample";

  private static final String INTENT_PREFIX =
      "com.google.dartino.githubmock";

  private static final String ACTION_ENSURE_SERVER =
      INTENT_PREFIX + ".action.ensureServer";

  private static final String ACTION_BROADCAST_STATUS =
      INTENT_PREFIX + ".action.broadcastStatus";

  private static final String STATUS_DATA =
      INTENT_PREFIX + ".data.status";

  // TODO(zerny): Make the server port dynamically selected.
  private static final int SERVER_PORT = 8321;

  private volatile Looper looper;
  private volatile Handler handler;
}
