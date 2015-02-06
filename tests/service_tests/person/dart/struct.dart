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

int getResultMessage(Builder builder) {
  BuilderSegment segment = builder._segment;
  if (segment._next == null) {
    // Mark result as being non-segmented.
    segment.setInt32(0, 0);
    return segment._memory.value;
  }

  // The result is a segmented message. Build a memory block that
  // contains the addresses and sizes of all of them.
  int segments = segment._builder._segments;
  int size = 8 + (segments * 16);
  Foreign buffer = new Foreign.allocated(size);
  // Mark the result as being segmented.
  buffer.setInt32(0, 1);
  buffer.setInt32(4, segments);
  int offset = 8;
  do {
    buffer.setInt64(offset, segment._memory.value);
    buffer.setInt32(offset + 8, segment._used);
    segment = segment._next;
    offset += 16;
  } while (segment != null);
  return buffer.value;
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

  readStruct(Reader reader, int offset) {
    Segment segment = _segment;
    offset += _offset;
    while (true) {
      Foreign memory = segment.memory;
      int lo = memory.getInt32(offset + 0);
      int hi = memory.getInt32(offset + 4);
      int tag = lo & 3;
      if (tag == 0) {
        throw new UnimplementedError("Cannot read uninitialized structs");
      } else if (tag == 1) {
        reader._segment = segment;
        reader._offset = lo >> 2;
        return reader;
      } else {
        segment = segment.reader.getSegment(hi);
        offset = lo >> 2;
      }
    }
  }

  readList(ListReader reader, int offset) {
    Segment segment = _segment;
    offset += _offset;
    while (true) {
      Foreign memory = segment.memory;
      int lo = memory.getInt32(offset + 0);
      int hi = memory.getInt32(offset + 4);
      int tag = lo & 3;
      if (tag == 0) {
        // If the list hasn't been initialized, then
        // we return an empty list.
        reader._length = 0;
        return reader;
      } else if (tag == 2) {
        reader._segment = segment;
        reader._offset = lo >> 2;
        reader._length = hi;
        return reader;
      } else {
        segment = segment.reader.getSegment(hi);
        offset = lo >> 2;
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
  final MessageBuilder _builder;
  final Foreign _memory;
  int _id;
  int _used = 0;
  BuilderSegment _next;

  BuilderSegment(this._builder, this._id, int space)
      : _memory = new Foreign.allocated(space);

  bool HasSpaceForBytes(int bytes) => _used + bytes <= _memory.length;

  int Allocate(int bytes) {
    if (!HasSpaceForBytes(bytes)) return -1;
    var result = _used;
    _used += bytes;
    return result;
  }

  void setInt16(int offset, inv value) {
    _memory.setInt16(offset, value);
  }

  void setInt32(int offset, int value) {
    _memory.setInt32(offset, value);
  }

  void setInt64(int offset, int value) {
    _memory.setInt64(offset, value);
  }
}

class MessageBuilder {
  BuilderSegment _first;
  BuilderSegment _last;
  int _segments = 1;

  MessageBuilder(int space) {
    _first = new BuilderSegment(this, 0, space);
    _last = _first;
  }

  Builder NewRoot(Builder builder, int size) {
    int offset = _first.Allocate(8 + size);
    builder._segment = _first;
    builder._offset = offset + 8;
    return builder;
  }

  BuilderSegment FindSegmentForBytes(int bytes) {
    if (_last.HasSpaceForBytes(bytes)) return _last;
    int capacity = (bytes > 8192) ? bytes : 8192;
    BuilderSegment segment = new BuilderSegment(this, _segments++, capacity);
    _last._next = segment;
    _last = segment;
    return segment;
  }
}

class Builder {
  BuilderSegment _segment;
  int _offset;

  void setInt16(int offset, int value) {
    _segment.setInt16(offset + _offset, value);
  }

  void setInt32(int offset, int value) {
    _segment.setInt32(offset + _offset, value);
  }

  Builder NewStruct(Builder builder, int offset, int size) {
    offset += _offset;
    BuilderSegment segment = _segment;
    while (true) {
      int result = segment.Allocate(size);
      if (result >= 0) {
        segment.setInt32(offset + 0, (result << 2) | 1);
        segment.setInt32(offset + 4, 0);
        builder._segment = segment;
        builder._offset = result;
        return builder;
      }

      BuilderSegment other = segment._builder.FindSegmentForBytes(size + 8);
      int target = other.Allocate(8);
      segment.setInt32(offset + 0, (target << 2) | 3);
      segment.setInt32(offset + 4, other._id);

      segment = other;
      offset = target;
    }
  }

  ListBuilder NewList(ListBuilder list,
                      int offset,
                      int length,
                      int size) {
    list._length = length;
    offset += _offset;
    size *= length;
    BuilderSegment segment = _segment;
    while (true) {
      int result = segment.Allocate(size);
      if (result >= 0) {
        segment.setInt32(offset + 0, (result << 2) | 1);
        segment.setInt32(offset + 4, length);
        list._segment = segment;
        list._offset = result;
        return list;
      }

      BuilderSegment other = segment._builder.FindSegmentForBytes(size + 8);
      int target = other.Allocate(8);
      segment.setInt32(offset + 0, (target << 2) | 3);
      segment.setInt32(offset + 4, other._id);

      segment = other;
      offset = target;
    }
  }
}

class ListBuilder extends Builder {
  int _length;
  int get length => _length;

  readListElement(Builder builder, int index, int size) {
    builder._segment = _segment;
    builder._offset = _offset + index * size;
    return builder;
  }
}
