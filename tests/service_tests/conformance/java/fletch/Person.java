// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

package fletch;

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

  public int getAge() { return getIntAt(16); }
}
