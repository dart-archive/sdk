// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;
public class PatchBuilder extends Builder {
  public static int kSize = 32;
  public PatchBuilder(BuilderSegment segment, int offset) {
    super(segment, offset);
  }

  public PatchBuilder() {
    super();
  }

  public NodeBuilder initContent() {
    NodeBuilder result = new NodeBuilder();
    result.segment = segment;
    result.base = base + 0;
    return result;
  }

  public Uint8ListBuilder initPath(int length) {
    ListBuilder builder = new ListBuilder();
    newList(builder, 24, length, 1);
    return new Uint8ListBuilder(builder);
  }
}
