// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package immi;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import dartino.ImmiServiceLayer;
import dartino.ImmiServiceLayer.RefreshCallback;
import dartino.PatchData;

public final class ImmiRoot {

  // Public interface.

  public void refresh() {
    refreshThread.submit(requestRefresh);
  }

  public void reset() {
    refreshThread.submit(requestReset);
  }

  // Package private implementation.

  // For construction see ImmiService.registerPresenter.
  ImmiRoot(int id, AnyNodePresenter presenter) {
    assert id > 0;
    this.id = id;
    this.presenter = presenter;
  }

  void dispatch(Runnable event) {
    event.run();
    // TODO(zerny): Consider other strategies than eagerly requesting a refresh
    // on each dispatch.
    refresh();
  }

  // Private implementation.

  // No assumptions are made on which thread patch application is performed on.
  // Initiating a refresh is controlled by requestRefresh and finishRefresh below.
  // Single thread executor guaranties mutual exclusion of requestRefresh and finishRefresh.
  private RefreshCallback applyPatch = new RefreshCallback() {
    @Override
    public void handle(PatchData data) {
      if (data.isNode()) {
        AnyNodePatch patch = new AnyNodePatch(data.getNode(), previous, ImmiRoot.this);
        previous = patch.getCurrent();
        patch.applyTo(presenter);
      }
      refreshThread.submit(finishRefresh);
    }
  };

  private Runnable requestRefresh = new Runnable() {
    @Override
    public void run() {
      if (refreshPending) {
        // Request a refresh once the pending refresh finishes.
        refreshRequired = true;
      } else {
        // Initiate a new refresh.
        refreshPending = true;
        ImmiServiceLayer.refreshAsync(id, applyPatch);
      }
    }
  };

  private Runnable finishRefresh = new Runnable() {
    @Override
    public void run() {
      assert refreshPending;
      if (refreshRequired) {
        // A refresh request is outstanding so immediately initiate a new refresh.
        refreshRequired = false;
        ImmiServiceLayer.refreshAsync(id, applyPatch);
      } else {
        refreshPending = false;
      }
    }
  };

  // To guarantee order of refresh and reset we schedule reset on the same executor.
  private Runnable requestReset = new Runnable() {
    @Override
    public void run() {
      ImmiServiceLayer.resetAsync(id, null);
    }
  };

  private int id;
  private AnyNodePresenter presenter;
  private AnyNode previous;
  private boolean refreshPending = false;
  private boolean refreshRequired = false;
  private final static ExecutorService refreshThread = Executors.newSingleThreadExecutor();
}
