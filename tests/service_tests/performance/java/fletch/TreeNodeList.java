// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class TreeNodeList {
  private ListReader reader;

  public TreeNodeList(ListReader reader) { this.reader = reader; }

  public TreeNode get(int index) {
    TreeNode result = new TreeNode();
    reader.readListElement(result, index, 8);
    return result;
  }

  public int size() { return reader.length; }
}
