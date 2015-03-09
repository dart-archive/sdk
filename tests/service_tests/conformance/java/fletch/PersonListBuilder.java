// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

public class PersonListBuilder {
  private ListBuilder builder;

  public PersonListBuilder(ListBuilder builder) { this.builder = builder; }

  public PersonBuilder get(int index) {
    PersonBuilder result = new PersonBuilder();
    builder.readListElement(result, index, 24);
    return result;
  }

  public int size() { return builder.length; }
}
