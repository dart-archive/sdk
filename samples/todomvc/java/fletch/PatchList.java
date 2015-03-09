// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class PatchList {
  private ListReader reader;

  public PatchList(ListReader reader) { this.reader = reader; }

  public Patch get(int index) {
    Patch result = new Patch();
    reader.readListElement(result, index, 32);
    return result;
  }

  public int size() { return reader.length; }
}
