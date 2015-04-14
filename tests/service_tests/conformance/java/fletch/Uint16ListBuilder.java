// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class Uint16ListBuilder {
  private ListBuilder builder;

  public Uint16ListBuilder(ListBuilder builder) { this.builder = builder; }

  public int get(int index) {
    return builder.segment.getUnsignedChar(builder.base + index * 2);
  }

  public int set(int index, int value) {
    builder.segment.buffer().putChar(builder.base + index * 2, (char)value);    return value;
  }

  public int size() { return builder.length; }
}
