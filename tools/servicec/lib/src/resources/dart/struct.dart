// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library service.struct;

import "dart:dartino.ffi";
import "dart:collection";

const int HEADER_SIZE = 56;

Reader getRoot(Reader reader, ForeignMemory request) {
  int segments = request.getInt32(HEADER_SIZE - 8);
  if (segments == 0) {
    MessageReader messageReader = new MessageReader();
    Segment segment = new Segment(messageReader, request);
    messageReader.segments.add(segment);
    reader.$segment = segment;
    reader.$offset = HEADER_SIZE;
    return reader;
  } else {
    return getSegmentedRoot(reader, request, segments);
  }
}

Reader getSegmentedRoot(Reader reader, ForeignMemory request, int segments) {
  MessageReader messageReader = new MessageReader();
  int offset = HEADER_SIZE + 8;
  for (int i = 0; i < segments; i++) {
    int address = (Foreign.bitsPerMachineWord == 32)
        ? request.getUint32(offset)
        : request.getUint64(offset);
    int size = request.getInt32(offset + 8);
    ForeignMemory memory = new ForeignMemory.fromAddress(address, size);
    Segment segment = new Segment(messageReader, memory);
    messageReader.segments.add(segment);
    offset += 16;
  }
  reader.$segment = messageReader.segments.first;
  reader.$offset = HEADER_SIZE;
  return reader;
}

int getResultMessage(Builder builder) {
  BuilderSegment segment = builder.$segment;
  if (segment._next == null) {
    // Mark result as being non-segmented.
    ForeignMemory memory = segment.memory;
    memory.setInt32(0, 0);
    memory.setInt32(4, memory.length);
    return memory.address;
  }

  // The result is a segmented message. Build a memory block that
  // contains the addresses and sizes of all of them.
  int segments = segment._builder.$segments;
  int size = 8 + (segments * 16);
  ForeignMemory buffer = new ForeignMemory.allocated(size);
  // Mark the result as being segmented.
  buffer.setInt32(0, segments);
  int offset = 8;
  do {
    buffer.setInt64(offset, segment.memory.address);
    buffer.setInt32(offset + 8, segment._used);
    segment = segment._next;
    offset += 16;
  } while (segment != null);
  return buffer.address;
}

class MessageReader {
  final List<Segment> segments = [];
  MessageReader();

  Segment getSegment(int id) => segments[id];
}

class Segment {
  final MessageReader reader;
  final ForeignMemory memory;
  Segment(this.reader, this.memory);
}

class Reader {
  Segment $segment;
  int $offset;

  readStruct(Reader reader, int offset) {
    Segment segment = $segment;
    offset += $offset;
    while (true) {
      ForeignMemory memory = segment.memory;
      int lo = memory.getInt32($offset + 0);
      int hi = memory.getInt32($offset + 4);
      int tag = lo & 3;
      if (tag == 0) {
        throw new UnimplementedError("Cannot read uninitialized structs");
      } else if (tag == 1) {
        reader.$segment = segment;
        reader.$offset = lo >> 2;
        return reader;
      } else {
        segment = segment.reader.getSegment(hi);
        $offset = lo >> 2;
      }
    }
  }

  readList(ListReader reader, int offset) {
    Segment segment = $segment;
    offset += $offset;
    while (true) {
      ForeignMemory memory = segment.memory;
      int lo = memory.getInt32(offset + 0);
      int hi = memory.getInt32(offset + 4);
      int tag = lo & 3;
      if (tag == 0) {
        // If the list hasn't been initialized, then
        // we return an empty list.
        reader.$length = 0;
        return reader;
      } else if (tag == 2) {
        reader.$segment = segment;
        reader.$offset = lo >> 2;
        reader.$length = hi;
        return reader;
      } else {
        segment = segment.reader.getSegment(hi);
        offset = lo >> 2;
      }
    }
  }

  String readString(ListReader reader, int offset) {
    List<int> charCodes = readList(reader, offset);
    return new String.fromCharCodes(charCodes);
  }
}

abstract class ListReader<T> extends Reader with ListMixin<T> {
  int $length;
  int get length => $length;  // Required by List<T>.

  readListElement(Reader reader, int index, int size) {
    reader.$segment = $segment;
    reader.$offset = $offset + index * size;
    return reader;
  }

  void operator []=(int index, value) {
    throw new UnsupportedError("ListReader::operator []=");
  }

  void set length(int newLength) {
    throw new UnsupportedError("ListReader::set length");
  }
}

class BuilderSegment {
  final MessageBuilder _builder;
  final ForeignMemory memory;
  int _id;
  int _used = 0;
  BuilderSegment _next;

  BuilderSegment(this._builder, this._id, int space)
      : memory = new ForeignMemory.allocated(space);

  bool HasSpaceForBytes(int bytes) => _used + bytes <= memory.length;

  int Allocate(int bytes) {
    if (!HasSpaceForBytes(bytes)) return -1;
    var result = _used;
    _used += bytes;
    return result;
  }
}

class MessageBuilder {
  BuilderSegment _first;
  BuilderSegment _last;
  int $segments = 1;

  MessageBuilder(int space) {
    _first = new BuilderSegment(this, 0, space);
    _last = _first;
  }

  Builder initRoot(Builder builder, int size) {
    int offset = _first.Allocate(8 + size);
    builder.$segment = _first;
    builder.$offset = offset + 8;
    return builder;
  }

  BuilderSegment FindSegmentForBytes(int bytes) {
    if (_last.HasSpaceForBytes(bytes)) return _last;
    int capacity = (bytes > 8192) ? bytes : 8192;
    BuilderSegment segment = new BuilderSegment(this, $segments++, capacity);
    _last._next = segment;
    _last = segment;
    return segment;
  }
}

class Builder {
  BuilderSegment $segment;
  int $offset;

  Builder NewStruct(Builder builder, int offset, int size) {
    offset += $offset;
    BuilderSegment segment = $segment;
    while (true) {
      int result = segment.Allocate(size);
      ForeignMemory memory = segment.memory;
      if (result >= 0) {
        memory.setInt32(offset + 0, (result << 2) | 1);
        memory.setInt32(offset + 4, 0);
        builder.$segment = segment;
        builder.$offset = result;
        return builder;
      }

      BuilderSegment other = segment._builder.FindSegmentForBytes(size + 8);
      int target = other.Allocate(8);
      memory.setInt32(offset + 0, (target << 2) | 3);
      memory.setInt32(offset + 4, other._id);

      segment = other;
      offset = target;
    }
  }

  ListBuilder NewList(ListBuilder list,
                      int offset,
                      int length,
                      int size) {
    list.$length = length;
    offset += $offset;
    size *= length;
    BuilderSegment segment = $segment;
    while (true) {
      int result = segment.Allocate(size);
      ForeignMemory memory = segment.memory;
      if (result >= 0) {
        memory.setInt32(offset + 0, (result << 2) | 1);
        memory.setInt32(offset + 4, length);
        list.$segment = segment;
        list.$offset = result;
        return list;
      }

      BuilderSegment other = segment._builder.FindSegmentForBytes(size + 8);
      int target = other.Allocate(8);
      memory.setInt32(offset + 0, (target << 2) | 3);
      memory.setInt32(offset + 4, other._id);

      segment = other;
      offset = target;
    }
  }

  void NewString(ListBuilder list, int offset, String value) {
    NewList(list, offset, value.length, 2);
    for (int i = 0; i < value.length; i++) {
      list[i] = value.codeUnitAt(i);
    }
  }
}

abstract class ListBuilder<T> extends Builder with ListMixin<T> {
  int $length;
  int get length => $length;

  readListElement(Builder builder, int index, int size) {
    builder.$segment = $segment;
    builder.$offset = $offset + index * size;
    return builder;
  }

  void operator []=(int index, value) {
    throw new UnsupportedError("ListBuilder::operator []=");
  }

  void set length(int newLength) {
    throw new UnsupportedError("ListBuilder::set length");
  }
}
