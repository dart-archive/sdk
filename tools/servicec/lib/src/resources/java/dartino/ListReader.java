// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package dartino;

class ListReader extends Reader {
  public ListReader() { }

  public int length;

  Reader readListElement(Reader reader, int index, int size) {
    reader.segment = segment;
    reader.base = base + index * size;
    return reader;
  }
}
