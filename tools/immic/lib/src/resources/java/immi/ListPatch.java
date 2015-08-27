// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package immi;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import fletch.ListPatchData;

public final class ListPatch implements Patch {

  // Public interface.

  @Override
  public boolean hasChanged() { return false; }

  public List getCurrent() { return current; }
  public List getPrevious() { return previous; }

  // Package private implementation.

  ListPatch(ListPatchData data, List previous, ImmiRoot root) {
    // TODO(zerny): Implement list patches.
    this.previous = previous;
    current = Collections.unmodifiableList(new ArrayList());
  }

  private List previous;
  private List current;
}
