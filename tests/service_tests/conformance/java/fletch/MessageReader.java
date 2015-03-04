// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package fletch;

class MessageReader {
  public MessageReader(byte[][] rawSegments) {
    int length = rawSegments.length;
    segments = new Segment[length];
    for (int i = 0; i < length; i++) {
      segments[i] = new Segment(this, rawSegments[i]);
    }
  }

  public int segmentCount() { return segments.length; }
  public Segment getSegment(int id) { return segments[id]; }

  private Segment[] segments;
}
