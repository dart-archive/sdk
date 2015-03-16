// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class Uint16List {
  private ListReader reader;

  public Uint16List(ListReader reader) { this.reader = reader; }

  public int get(int index) {
    return reader.segment.getUnsignedChar(reader.base + index * 2);
  }

  public int size() { return reader.length; }
}
