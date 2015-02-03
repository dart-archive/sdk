// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library struct;

import "dart:ffi";

Reader getRoot(Reader reader, Foreign request) {
  if (request.getInt32(32) == 1) {
    return getSegmentedRoot(reader, request);
  } else {
    MessageReader messageReader = new MessageReader();
    Segment segment = new Segment(messageReader, request);
    messageReader.segments.add(segment);
    reader._segment = segment;
    reader._offset = 40;
    return reader;
  }
}

Reader getSegmentedRoot(Reader reader, Foreign request) {
  MessageReader messageReader = new MessageReader();
  int segments = request.getInt32(40);
  int offset = 40 + 8;
  for (int i = 0; i < segments; i++) {
    int address = (Foreign.bitsPerMachineWord == 32)
        ? request.getUint32(offset)
        : request.getUint64(offset);
    int size = request.getInt32(offset + 8);
    Foreign memory = new Foreign.fromAddress(address, size);
    Segment segment = new Segment(messageReader, memory);
    messageReader.segments.add(segment);
    offset += 16;
  }
  reader._segment = messageReader.segments.first;
  reader._offset = 40;
  return reader;
}

class MessageReader {
  final List<Segment> segments = [];
  MessageReader();

  Segment getSegment(int id) => segments[id];
}

class Segment {
  final MessageReader reader;
  final Foreign memory;
  Segment(this.reader, this.memory);
}

class Reader {
  Segment _segment;
  int _offset;

  readList(ListReader reader, int offset) {
    Segment segment = _segment;
    offset += _offset;
    while (true) {
      Foreign memory = segment.memory;
      int lo = memory.getInt32(offset + 0);
      int hi = memory.getInt32(offset + 4);
      if ((lo & 1) == 0) {
        reader._segment = segment;
        reader._offset = lo >> 1;
        reader._length = hi;
        return reader;
      } else {
        segment = segment.reader.getSegment(hi);
        offset = lo >> 1;
      }
    }
  }
}

class ListReader extends Reader {
  int _length;
  int get length => _length;

  readListElement(Reader reader, int index, int size) {
    reader._segment = _segment;
    reader._offset = _offset + index * size;
    return reader;
  }
}

class BuilderSegment {
  final Foreign _memory;
  int _id;
  int _used = 0;

  BuilderSegment(this._id, int space) : _memory = new Foreign.allocated(space);

  bool HasSpaceForBytes(int bytes) => _used + bytes <= _memory.length;

  int Allocate(int bytes) {
    if (!HasSpaceForBytes(bytes)) return -1;
    var result = _used;
    _used += bytes;
    return result;
  }

  void setInt32(int offset, int value) {
    _memory.setInt32(offset, value);
  }
}

class MessageBuilder {
  final BuilderSegment _first;
  int _segments = 1;

  MessageBuilder(int space) : _first = new BuilderSegment(0, space);

  Builder NewRoot(Builder builder, int size) {
    int offset = _first.Allocate(size);
    builder._segment = _first;
    builder._offset = offset;
    return builder;
  }
}

class Builder {
  BuilderSegment _segment;
  int _offset;

  void setInt32(int offset, int value) {
    _segment.setInt32(offset + _offset, value);
  }
}