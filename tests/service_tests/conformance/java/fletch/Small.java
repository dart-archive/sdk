// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;

public class Small extends Reader {
  public Small() { }

  public Small(byte[] memory, int offset) {
    super(memory, offset);
  }

  public Small(Segment segment, int offset) {
    super(segment, offset);
  }

  public Small(byte[][] segments, int offset) {
    super(segments, offset);
  }

  public static Small create(Object rawData) {
    if (rawData instanceof byte[]) {
      return new Small((byte[])rawData, 8);
    }
    return new Small((byte[][])rawData, 8);
  }

  public int getX() { return getIntAt(0); }
}
