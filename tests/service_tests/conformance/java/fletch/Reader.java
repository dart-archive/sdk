// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package fletch;

import java.nio.ByteBuffer;

class Reader {
  public Reader() { }

  public Reader(byte[] memory, int offset) {
    segment = new Segment(memory);
    base = offset;
  }

  public Reader(Segment segment, int offset) {
    this.segment = segment;
    base = offset;
  }

  public Reader(byte[][] segments, int offset) {
    MessageReader reader = new MessageReader(segments);
    segment = reader.getSegment(0);
    base = offset;
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
    return (short)Math.abs(result);
  }

  public Reader readStruct(Reader reader, int offset) {
    Segment s = segment;
    offset += base;
    while (true) {
      ByteBuffer buffer = s.buffer();
      int lo = buffer.getInt(offset + 0);
      int hi = buffer.getInt(offset + 4);
      int tag = lo & 3;
      if (tag == 0) {
        // Cannot read uninitialized structs.
        System.exit(1);
      } else if (tag == 1) {
        reader.segment = s;
        reader.base = lo >> 2;
        return reader;
      } else {
        s = s.reader().getSegment(hi);
        offset = lo >> 2;
      }
    }
  }

  public ListReader readList(ListReader reader, int offset) {
    Segment s = segment;
    offset += base;
    while (true) {
      ByteBuffer buffer = s.buffer();
      int lo = buffer.getInt(offset + 0);
      int hi = buffer.getInt(offset + 4);
      int tag = lo & 3;
      if (tag == 0) {
        // If the list hasn't been initialized we return an empty
        // list.
        reader.length = 0;
        return reader;
      } else if (tag == 1) {
        reader.segment = s;
        reader.base = lo >> 2;
        reader.length = hi;
        return reader;
      } else {
        s = s.reader().getSegment(hi);
        offset = lo >> 2;
      }
    }
  }

  public int computeUsed() {
    MessageReader reader = segment.reader();
    int used = 0;
    for (int i = 0; i < reader.segmentCount(); i++) {
      used += reader.getSegment(i).buffer().capacity();
    }
    return used;
  }

  protected Segment segment;
  protected int base;
}
