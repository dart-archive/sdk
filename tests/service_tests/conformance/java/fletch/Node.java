// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class Node extends Reader {
  public Node(byte[] memory) {
    super(memory);
  }

  public Node(byte[][] segments) {
    super(segments);
  }

  boolean isNum() { return 1 == getTag(); }
  public int getNum() { return getIntAt(0); }
  boolean isCond() { return 2 == getTag(); }
  public boolean getCond() { return getBooleanAt(0); }
  boolean isCons() { return 3 == getTag(); }
  boolean isNil() { return 4 == getTag(); }
  public int getTag() { return getIntAt(16); }
}
