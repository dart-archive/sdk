// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package fletch;

import java.nio.ByteBuffer;

class Builder {
  public Builder() { }

  public Builder(BuilderSegment segment, int base) {
    this.segment = segment;
    this.base = base;
  }

  public int getIntAt(int offset) {
    return segment.getIntAt(base + offset);
  }

  public short getShortAt(int offset) {
    return segment.getShortAt(base + offset);
  }

  public char getCharAt(int offset) {
    return segment.getCharAt(base + offset);
  }

  public boolean getBooleanAt(int offset) {
    return segment.getBooleanAt(base + offset);
  }

  public short getUnsignedByteAt(int offset) {
    short result = (short)segment.getByteAt(base + offset);
    return result < 0 ? (short)-result : result;
  }

  public BuilderSegment segment() { return segment; }

  public Builder newStruct(Builder builder, int offset, int size) {
    offset += base;
    BuilderSegment s = segment;
    while (true) {
      int result = s.allocate(size);
      ByteBuffer memory = s.buffer();
      if (result >= 0) {
        memory.putInt(offset + 0, (result << 2) | 1);
        memory.putInt(offset + 4, 0);
        builder.segment = s;
        builder.base = result;
        return builder;
      }

      BuilderSegment other = s.builder().findSegmentForBytes(size + 8);
      int target = other.allocate(8);
      memory.putInt(offset + 0, (target << 2) | 3);
      memory.putInt(offset + 4, other.id());

      s = other;
      offset = target;
    }
  }

  public ListBuilder newList(ListBuilder list,
                             int offset,
                             int length,
                             int size) {
    list.length = length;
    offset += base;
    size *= length;
    BuilderSegment s = segment;
    while (true) {
      int result = s.allocate(size);
      ByteBuffer memory = s.buffer();
      if (result >= 0) {
        memory.putInt(offset + 0, (result << 2) | 1);
        memory.putInt(offset + 4, length);
        list.segment = s;
        list.base = result;
        return list;
      }

      BuilderSegment other = s.builder().findSegmentForBytes(size + 8);
      int target = other.allocate(8);
      memory.putInt(offset + 0, (target << 2) | 3);
      memory.putInt(offset + 4, other.id());

      s = other;
      offset = target;
    }
  }

  protected BuilderSegment segment;
  protected int base;
}
