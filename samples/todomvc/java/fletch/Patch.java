// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;

public class Patch extends Reader {
  public Patch() { }

  public Patch(byte[] memory, int offset) {
    super(memory, offset);
  }

  public Patch(Segment segment, int offset) {
    super(segment, offset);
  }

  public Patch(byte[][] segments, int offset) {
    super(segments, offset);
  }

  public static Patch create(Object rawData) {
    if (rawData instanceof byte[]) {
      return new Patch((byte[])rawData, 8);
    }
    return new Patch((byte[][])rawData, 8);
  }

  public Node getContent() { return new Node(segment, base + 0); }

  public List<Short> getPath() {
    ListReader reader = new ListReader();
    readList(reader, 24);
    return new Uint8List(reader);
  }
}
