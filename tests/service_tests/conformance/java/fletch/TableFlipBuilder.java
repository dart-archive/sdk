// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;
public class TableFlipBuilder extends Builder {
  public static int kSize = 8;
  public TableFlipBuilder(BuilderSegment segment, int offset) {
    super(segment, offset);
  }

  public TableFlipBuilder() {
    super();
  }

  public void setFlip(String value) {
    newString(0, value);
  }

  public Uint16ListBuilder initFlipData(int length) {
    ListBuilder builder = new ListBuilder();
    newList(builder, 0, length, 2);
    return new Uint16ListBuilder(builder);
  }
}
