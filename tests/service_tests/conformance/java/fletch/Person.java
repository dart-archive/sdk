// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

import java.util.List;

public class Person extends Reader {
  public Person() { }

  public Person(byte[] memory, int offset) {
    super(memory, offset);
  }

  public Person(Segment segment, int offset) {
    super(segment, offset);
  }

  public Person(byte[][] segments, int offset) {
    super(segments, offset);
  }

  public static Person create(Object rawData) {
    if (rawData instanceof byte[]) {
      return new Person((byte[])rawData, 8);
    }
    return new Person((byte[][])rawData, 8);
  }

  public List<Short> getName() {
    ListReader reader = new ListReader();
    readList(reader, 0);
    return new Uint8List(reader);
  }

  public List<Person> getChildren() {
    ListReader reader = new ListReader();
    readList(reader, 8);
    return new PersonList(reader);
  }

  public int getAge() { return segment.buffer().getInt(base + 16); }
}
