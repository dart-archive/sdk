// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.AbstractList;

class Uint8List extends AbstractList<Short> {
  private ListReader reader;

  public Uint8List(ListReader reader) { this.reader = reader; }

  public Short get(int index) {
    short result = reader.segment.getUnsigned(reader.base + index * 1);
    return new Short(result);
  }

  public int size() { return reader.length; }
}
