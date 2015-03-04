// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package fletch;

class BuilderSegment extends Segment {
  public BuilderSegment(MessageBuilder builder, int id, int size) {
    super(new byte[size]);
    this.builder = builder;
    this.id = id;
    used = 0;
  }

  public boolean hasSpaceForBytes(int bytes) {
    return used + bytes < buffer().capacity();
  }

  public int allocate(int bytes) {
    if (!hasSpaceForBytes(bytes)) return -1;
    int result = used;
    used += bytes;
    return result;
  }

  public int id() { return id; }
  public int used() { return used; }
  public MessageBuilder builder() { return builder; }

  public boolean hasNext() { return next != null; }
  public BuilderSegment next() { return next; }
  public void setNext(BuilderSegment segment) { next = segment; }

  private MessageBuilder builder;
  private int id;
  private BuilderSegment next;
  private int used;
}
