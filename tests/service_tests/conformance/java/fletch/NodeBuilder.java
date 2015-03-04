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

  public void setNum(int value) {
    setTag((char)1);
    segment.buffer().putInt(base + 0, (int)value);
  }

  public void setCond(boolean value) {
    setTag((char)2);
    segment.buffer().put(base + 0, (byte)(value ? 1 : 0));
  }

  public ConsBuilder initCons() {
    setTag((char)3);
    ConsBuilder result = new ConsBuilder();
    result.segment = segment;
    result.base = base + 0;
    return result;
  }

  public void setNil() { setTag((char)4); }

  public void setTag(char value) {
    segment.buffer().putChar(base + 16, (char)value);
  }
}
