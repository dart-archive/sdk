// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package immi;

public final class ActionPatch<A extends Action> implements Patch {

  // Public interface.

  public boolean hasChanged() { return changed; }

  public A getCurrent() { return action; }

  // We do not implement getPrevious on actions because it has been removed from
  // the graph and is a stale resource.

  // Package private implementation.

  ActionPatch(A previous) {
    this.changed = false;
    this.action = previous;
  }

  ActionPatch(A current, A previous, ImmiRoot root) {
    this.changed = true;
    this.action = current;
  }

  private boolean changed;
  private A action;
}
