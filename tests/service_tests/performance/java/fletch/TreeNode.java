// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;

public class TreeNode extends Reader {
  public TreeNode() { }

  public TreeNode(byte[] memory, int offset) {
    super(memory, offset);
  }

  public TreeNode(Segment segment, int offset) {
    super(segment, offset);
  }

  public TreeNode(byte[][] segments, int offset) {
    super(segments, offset);
  }

  public List<TreeNode> getChildren() {
    ListReader reader = new ListReader();
    readList(reader, 0);
    return new TreeNodeList(reader);
  }
}
