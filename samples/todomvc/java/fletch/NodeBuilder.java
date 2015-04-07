// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;
public class NodeBuilder extends Builder {
  public static int kSize = 24;
  public NodeBuilder(BuilderSegment segment, int offset) {
    super(segment, offset);
  }

  public NodeBuilder() {
    super();
  }

  public void setNil() { setTag(1); }

  public void setNum(int value) {
    setTag(2);
    segment.buffer().putInt(base + 0, (int)value);
  }

  public void setTruth(boolean value) {
    setTag(3);
    segment.buffer().put(base + 0, (byte)(value ? 1 : 0));
  }

  public void setStr(String value) {
    setTag(4);
    newString(0, value);
  }

  public Uint16ListBuilder initStrData(int length) {
    setTag(4);
    ListBuilder builder = new ListBuilder();
    newList(builder, 0, length, 2);
    return new Uint16ListBuilder(builder);
  }

  public ConsBuilder initCons() {
    setTag(5);
    ConsBuilder result = new ConsBuilder();
    result.segment = segment;
    result.base = base + 0;
    return result;
  }

  public void setTag(int value) {
    segment.buffer().putChar(base + 22, (char)value);
  }
}
