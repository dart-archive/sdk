// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;
public class LargeBuilder extends Builder {
  public static int kSize = 8;
  public LargeBuilder(BuilderSegment segment, int offset) {
    super(segment, offset);
  }

  public LargeBuilder() {
    super();
  }

  public SmallBuilder initS() {
    SmallBuilder result = new SmallBuilder();
    result.segment = segment;
    result.base = base + 0;
    return result;
  }

  public void setY(int value) {
    segment.buffer().putInt(base + 4, (int)value);
  }
}
