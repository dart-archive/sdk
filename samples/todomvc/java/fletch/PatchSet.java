// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;

public class PatchSet extends Reader {
  public PatchSet() { }

  public PatchSet(byte[] memory, int offset) {
    super(memory, offset);
  }

  public PatchSet(Segment segment, int offset) {
    super(segment, offset);
  }

  public PatchSet(byte[][] segments, int offset) {
    super(segments, offset);
  }

  public static PatchSet create(Object rawData) {
    if (rawData instanceof byte[]) {
      return new PatchSet((byte[])rawData, 8);
    }
    return new PatchSet((byte[][])rawData, 8);
  }

  public PatchList getPatches() {
    ListReader reader = new ListReader();
    readList(reader, 0);
    return new PatchList(reader);
  }
}
