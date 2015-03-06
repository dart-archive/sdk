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

  public BuilderSegment segment() { return segment; }

  public Object[] getSegments() {
    Object[] result = new Object[2];
    int segments = segment().builder().segments();
    byte[][] segmentArray = new byte[segments][];
    int[] sizeArray = new int[segments];
    BuilderSegment current = segment;
    for (int i = 0; i < segments; i++) {
      segmentArray[i] = current.buffer().array();
      sizeArray[i] = current.used();
      current = current.next();
    }
    result[0] = segmentArray;
    result[1] = sizeArray;
    return result;
  }

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
        memory.putInt(offset + 0, (result << 2) | 2);
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
