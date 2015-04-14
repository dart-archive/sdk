// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;

public class Empty extends Reader {
  public Empty() { }

  public Empty(byte[] memory, int offset) {
    super(memory, offset);
  }

  public Empty(Segment segment, int offset) {
    super(segment, offset);
  }

  public Empty(byte[][] segments, int offset) {
    super(segments, offset);
  }

  public static Empty create(Object rawData) {
    if (rawData instanceof byte[]) {
      return new Empty((byte[])rawData, 8);
    }
    return new Empty((byte[][])rawData, 8);
  }
}
