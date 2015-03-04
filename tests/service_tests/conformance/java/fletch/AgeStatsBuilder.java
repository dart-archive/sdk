// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;
public class AgeStatsBuilder extends Builder {
  public static int kSize = 8;
  public AgeStatsBuilder(BuilderSegment segment, int offset) {
    super(segment, offset);
  }

  public AgeStatsBuilder() {
    super();
  }

  public void setAverageAge(int value) {
    segment.buffer().putInt(base + 0, (int)value);
  }

  public void setSum(int value) {
    segment.buffer().putInt(base + 4, (int)value);
  }
}
