// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;

public class Large extends Reader {
  public Large() { }

  public Large(byte[] memory, int offset) {
    super(memory, offset);
  }

  public Large(Segment segment, int offset) {
    super(segment, offset);
  }

  public Large(byte[][] segments, int offset) {
    super(segments, offset);
  }

  public static Large create(Object rawData) {
    if (rawData instanceof byte[]) {
      return new Large((byte[])rawData, 8);
    }
    return new Large((byte[][])rawData, 8);
  }

  public Small getS() {
    return new Small(segment, base + 0);
  }

  public int getY() { return getIntAt(4); }
}
