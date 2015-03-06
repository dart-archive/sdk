// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.AbstractList;

class Uint8ListBuilder extends AbstractList<Short> {
  private ListBuilder builder;

  public Uint8ListBuilder(ListBuilder builder) { this.builder = builder; }

  public Short get(int index) {
    short result = builder.segment().getUnsigned(builder.base + index * 1);
    return new Short(result);
  }

  public Short set(int index, Short value) {
    builder.segment().buffer().put(builder.base + index * 1, value.byteValue());
    return value;
  }

  public int size() { return builder.length; }
}
