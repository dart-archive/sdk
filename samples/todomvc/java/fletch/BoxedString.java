// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;

public class BoxedString extends Reader {
  public BoxedString() { }

  public BoxedString(byte[] memory, int offset) {
    super(memory, offset);
  }

  public BoxedString(Segment segment, int offset) {
    super(segment, offset);
  }

  public BoxedString(byte[][] segments, int offset) {
    super(segments, offset);
  }

  public static BoxedString create(Object rawData) {
    if (rawData instanceof byte[]) {
      return new BoxedString((byte[])rawData, 8);
    }
    return new BoxedString((byte[][])rawData, 8);
  }

  public String getStr() { return readString(0); }
  public Uint16List getStrData() {
    ListReader reader = new ListReader();
    readList(reader, 0);
    return new Uint16List(reader);
  }
}
