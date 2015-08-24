// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package immi;

import fletch.ImmiServiceLayer;
import fletch.ImmiServiceLayer.RefreshCallback;
import fletch.PatchData;

public final class ImmiRoot {

  // Public interface.

  public void refresh() {
    ImmiServiceLayer.refreshAsync(id, new RefreshCallback() {
        @Override
        public void handle(PatchData data) {
          if (data.isNode()) {
            AnyNodePatch patch = new AnyNodePatch(data.getNode(), previous, ImmiRoot.this);
            previous = patch.getCurrent();
            patch.applyTo(presenter);
          }
        }
      });
  }

  public void reset() {
    ImmiServiceLayer.resetAsync(id, null);
  }

  // Package private implementation.

  // For construction see ImmiService.registerPresenter.
  ImmiRoot(int id, AnyNodePresenter presenter) {
    assert id > 0;
    this.id = id;
    this.presenter = presenter;
  }

  // Private implementation.

  private int id;
  private AnyNodePresenter presenter;
  private AnyNode previous;
}
