// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class Large extends Reader {
  public Large(byte[] memory) {
    super(memory);
  }

  public Large(byte[][] segments) {
    super(segments);
  }

  public int getY() { return getIntAt(4); }
}
