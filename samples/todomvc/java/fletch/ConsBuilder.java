// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;
public class ConsBuilder extends Builder {
  public static int kSize = 16;
  public ConsBuilder(BuilderSegment segment, int offset) {
    super(segment, offset);
  }

  public ConsBuilder() {
    super();
  }

  public NodeBuilder initFst() {
    NodeBuilder result = new NodeBuilder();
    newStruct(result, 0, 24);
    return result;
  }

  public NodeBuilder initSnd() {
    NodeBuilder result = new NodeBuilder();
    newStruct(result, 8, 24);
    return result;
  }
}
