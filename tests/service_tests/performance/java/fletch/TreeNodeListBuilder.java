// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class TreeNodeListBuilder {
  private ListBuilder builder;

  public TreeNodeListBuilder(ListBuilder builder) { this.builder = builder; }

  public TreeNodeBuilder get(int index) {
    TreeNodeBuilder result = new TreeNodeBuilder();
    builder.readListElement(result, index, 8);
    return result;
  }

  public int size() { return builder.length; }
}
