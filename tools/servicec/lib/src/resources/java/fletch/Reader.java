// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package fletch;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

class Reader {
  public Reader(byte[] memory) {
    this.memory = ByteBuffer.wrap(memory);
    base = 8;
    this.memory.order(ByteOrder.LITTLE_ENDIAN);
  }

  public Reader(byte[][] segments) {
    // TODO(ager): Implement.
  }

  public int getIntAt(int offset) {
    return memory.getInt(base + offset);
  }

  public boolean getBooleanAt(int offset) {
    return memory.get(base + offset) != 0;
  }

  private ByteBuffer memory;
  private int base;
}
