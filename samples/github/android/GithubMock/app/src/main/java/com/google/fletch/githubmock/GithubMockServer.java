// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubmock;

import android.app.Service;
import android.content.Intent;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.IBinder;
import android.os.Looper;
import android.os.Message;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

import fletch.FletchApi;
import fletch.FletchServiceApi;

/**
 * Service running a mock github http server.
 */
public class GithubMockServer extends Service {

  @Override
  public void onCreate() {
    super.onCreate();
    startThread();
    startFletch();
  }

  @Override
  public void onDestroy() {
    stopFletch();
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

  private void startFletch() {
    System.loadLibrary("fletch");
    FletchApi.Setup();
    FletchServiceApi.Setup();
    FletchApi.AddDefaultSharedLibrary("libfletch.so");
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
    fletch.GithubMockServer.Setup();
    fletch.GithubMockServer.start(SERVER_PORT);
  }

  private void stopFletch() {
    fletch.GithubMockServer.stop();
    fletch.GithubMockServer.TearDown();
    FletchServiceApi.TearDown();
    FletchApi.TearDown();
  }

  private static final String GITHUB_SAMPLE_PACKAGE =
      "com.google.fletch.githubsample";

  private static final String INTENT_PREFIX =
      "com.google.fletch.githubmock";

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
