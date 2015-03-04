// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.AbstractList;

class PersonList extends AbstractList<Person> {
  private ListReader reader;

  public PersonList(ListReader reader) { this.reader = reader; }

  public Person get(int index) {
    Person result = new Person();
    reader.readListElement(result, index, 24);
    return result;
  }

  public int size() { return reader.length; }
}
