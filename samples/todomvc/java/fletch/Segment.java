// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package fletch;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

class Segment {
  public Segment(byte[] memory) {
    buffer = ByteBuffer.wrap(memory);
    buffer.order(ByteOrder.LITTLE_ENDIAN);
  }

  public Segment(MessageReader reader, byte[] memory) {
    buffer = ByteBuffer.wrap(memory);
    buffer.order(ByteOrder.LITTLE_ENDIAN);
    this.reader = reader;
  }

  public ByteBuffer buffer() { return buffer; }
  public MessageReader reader() { return reader; }

  public boolean getBoolean(int offset) {
    return buffer.get(offset) != 0;
  }

  public short getUnsigned(int offset) {
    short result = (short)buffer.get(offset);
    return (short)Math.abs(result);
  }

  public int getUnsignedChar(int offset) {
    int result = (int)buffer.getChar(offset);
    return (int)Math.abs(result);
  }

  public long getUnsignedInt(int offset) {
    long result = (long)buffer.getInt(offset);
    return (long)Math.abs(result);
  }

  private ByteBuffer buffer;
  private MessageReader reader;
}
