// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class PatchListBuilder {
  private ListBuilder builder;

  public PatchListBuilder(ListBuilder builder) { this.builder = builder; }

  public PatchBuilder get(int index) {
    PatchBuilder result = new PatchBuilder();
    builder.readListElement(result, index, 32);
    return result;
  }

  public int size() { return builder.length; }
}
