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

  public void setNil() { setTag((char)1); }

  public void setNum(int value) {
    setTag((char)2);
    segment.buffer().putInt(base + 0, (int)value);
  }

  public void setBool(boolean value) {
    setTag((char)3);
    segment.buffer().put(base + 0, (byte)(value ? 1 : 0));
  }

  public StrBuilder initStr() {
    setTag((char)4);
    StrBuilder result = new StrBuilder();
    result.segment = segment;
    result.base = base + 0;
    return result;
  }

  public ConsBuilder initCons() {
    setTag((char)5);
    ConsBuilder result = new ConsBuilder();
    result.segment = segment;
    result.base = base + 0;
    return result;
  }

  public void setTag(char value) {
    segment.buffer().putChar(base + 16, (char)value);
  }
}
