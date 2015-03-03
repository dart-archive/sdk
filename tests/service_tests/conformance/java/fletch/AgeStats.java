// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class AgeStats extends Reader {
  public AgeStats(byte[] memory) {
    super(memory);
  }

  public AgeStats(byte[][] segments) {
    super(segments);
  }

  public int getAverageAge() { return getIntAt(0); }
  public int getSum() { return getIntAt(4); }
}
