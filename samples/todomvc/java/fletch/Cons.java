// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;

public class Cons extends Reader {
  public Cons() { }

  public Cons(byte[] memory, int offset) {
    super(memory, offset);
  }

  public Cons(Segment segment, int offset) {
    super(segment, offset);
  }

  public Cons(byte[][] segments, int offset) {
    super(segments, offset);
  }

  public static Cons create(Object rawData) {
    if (rawData instanceof byte[]) {
      return new Cons((byte[])rawData, 8);
    }
    return new Cons((byte[][])rawData, 8);
  }

  public Node getFst() {
    Node reader = new Node();
    return (Node)readStruct(reader, 0);
  }

  public Node getSnd() {
    Node reader = new Node();
    return (Node)readStruct(reader, 8);
  }

  public int getDeleteEvent() { return segment.getUnsignedChar(base + 16); }

  public int getCompleteEvent() { return segment.getUnsignedChar(base + 18); }

  public int getUncompleteEvent() { return segment.getUnsignedChar(base + 20); }
}
