// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;

public class TableFlip extends Reader {
  public TableFlip() { }

  public TableFlip(byte[] memory, int offset) {
    super(memory, offset);
  }

  public TableFlip(Segment segment, int offset) {
    super(segment, offset);
  }

  public TableFlip(byte[][] segments, int offset) {
    super(segments, offset);
  }

  public static TableFlip create(Object rawData) {
    if (rawData instanceof byte[]) {
      return new TableFlip((byte[])rawData, 8);
    }
    return new TableFlip((byte[][])rawData, 8);
  }

  public String getFlip() { return readString(0); }
  public Uint16List getFlipData() {
    ListReader reader = new ListReader();
    readList(reader, 0);
    return new Uint16List(reader);
  }
}
