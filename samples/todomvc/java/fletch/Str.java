// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;

public class Str extends Reader {
  public Str() { }

  public Str(byte[] memory, int offset) {
    super(memory, offset);
  }

  public Str(Segment segment, int offset) {
    super(segment, offset);
  }

  public Str(byte[][] segments, int offset) {
    super(segments, offset);
  }

  public static Str create(Object rawData) {
    if (rawData instanceof byte[]) {
      return new Str((byte[])rawData, 8);
    }
    return new Str((byte[][])rawData, 8);
  }

  public Uint8List getChars() {
    ListReader reader = new ListReader();
    readList(reader, 0);
    return new Uint8List(reader);
  }
}
