package com.google.fletch.githubsample;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;

import java.util.concurrent.Executors;

public class GithubMockServer {

  public interface EnsureServerCallback {
    void handle(int port);
  }

  public void ensureServer(final Context context, final EnsureServerCallback callback) {
    IntentFilter filter = new IntentFilter(GITHUB_MOCK_BROADCAST_STATUS);
    BroadcastReceiver receiver = new BroadcastReceiver() {
      @Override
      public void onReceive(Context context, Intent intent) {
        serverStarted = true;
        context.unregisterReceiver(this);
        callback.handle(intent.getIntExtra(GITHUB_MOCK_STATUS_DATA, -1));
      }
    };
    context.registerReceiver(receiver, filter);
    Intent ensureServer = new Intent(GITHUB_MOCK_ENSURE_SERVER);
    ensureServer.setPackage(GITHUB_MOCK_PACKAGE);
    context.startService(ensureServer);
    Executors.newSingleThreadExecutor().submit(new Runnable() {
      @Override
      public void run() {
        try {
          Thread.sleep(1000);
        } catch (InterruptedException e) {
          System.err.println("Interrupt occurred while waiting for the mock server to start.");
        }
        if (!serverStarted) {
          System.err.println("Github Mock server did not appear to start.");
          System.err.println("Please check that the GithubMock applicaton is installed.");
        }
      }
    });
  }

  private static final String GITHUB_MOCK_PACKAGE =
      "com.google.fletch.githubmock";

  private static final String GITHUB_MOCK_ENSURE_SERVER =
      GITHUB_MOCK_PACKAGE + ".action.ensureServer";

  private static final String GITHUB_MOCK_BROADCAST_STATUS =
      GITHUB_MOCK_PACKAGE + ".action.broadcastStatus";

  private static final String GITHUB_MOCK_STATUS_DATA =
      GITHUB_MOCK_PACKAGE + ".data.status";

  private boolean serverStarted = false;
}
