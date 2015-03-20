// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;

public class Node extends Reader {
  public Node() { }

  public Node(byte[] memory, int offset) {
    super(memory, offset);
  }

  public Node(Segment segment, int offset) {
    super(segment, offset);
  }

  public Node(byte[][] segments, int offset) {
    super(segments, offset);
  }

  public static Node create(Object rawData) {
    if (rawData instanceof byte[]) {
      return new Node((byte[])rawData, 8);
    }
    return new Node((byte[][])rawData, 8);
  }

  public boolean isNil() { return 1 == getTag(); }

  public boolean isNum() { return 2 == getTag(); }
  public int getNum() { return segment.buffer().getInt(base + 0); }

  public boolean isBool() { return 3 == getTag(); }
  public boolean getBool() { return segment.getBoolean(base + 0); }

  public boolean isStr() { return 4 == getTag(); }
  public String getStr() { return readString(0); }
  public Uint16List getStrData() {
    ListReader reader = new ListReader();
    readList(reader, 0);
    return new Uint16List(reader);
  }

  public boolean isCons() { return 5 == getTag(); }
  public Cons getCons() { return new Cons(segment, base + 0); }

  public int getTag() {
    short shortTag = segment.getUnsigned(base + 22);
    int tag = (int)shortTag;
    return tag < 0 ? -tag : tag;
  }
}
