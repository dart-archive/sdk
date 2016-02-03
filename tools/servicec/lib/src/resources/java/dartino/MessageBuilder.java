// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package dartino;

public class MessageBuilder {
  public MessageBuilder(int space) {
    segments = 1;
    first = new BuilderSegment(this, 0, space);
    last = first;
  }

  public BuilderSegment first() { return first; }

  public int segments() { return segments; }

  public Builder initRoot(Builder builder, int size) {
    // Return value and arguments use the same space. Therefore,
    // the size of any struct needs to be at least 8 bytes in order
    // to have room for the return address.
    if (size == 0) size = 8;
    int offset = first.allocate(56 + size);
    builder.segment = first;
    builder.base = offset + 56;
    return builder;
  }

  public int computeUsed() {
    int result = 0;
    BuilderSegment current = first;
    while (current != null) {
      result += current.used();
      current = current.next();
    }
    return result;
  }

  public BuilderSegment findSegmentForBytes(int bytes) {
    if (last.hasSpaceForBytes(bytes)) return last;
    int capacity = (bytes > 8192) ? bytes : 8192;
    BuilderSegment segment = new BuilderSegment(this, segments++, capacity);
    last.setNext(segment);
    last = segment;
    return segment;
  }

  private BuilderSegment first;
  private BuilderSegment last;
  private int segments;
};
