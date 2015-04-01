// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library struct;

import "dart:ffi";

Reader getRoot(Reader reader, Foreign request) {
  int segments = request.getInt32(40);
  if (segments == 0) {
    MessageReader messageReader = new MessageReader();
    Segment segment = new Segment(messageReader, request);
    messageReader.segments.add(segment);
    reader._segment = segment;
    reader._offset = 48;
    return reader;
  } else {
    return getSegmentedRoot(reader, request, segments);
  }
}

Reader getSegmentedRoot(Reader reader, Foreign request, int segments) {
  MessageReader messageReader = new MessageReader();
  int offset = 56;
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
  reader._offset = 48;
  return reader;
}

int getResultMessage(Builder builder) {
  BuilderSegment segment = builder._segment;
  if (segment._next == null) {
    // Mark result as being non-segmented.
    Foreign memory = segment.memory;
    memory.setInt32(0, 0);
    memory.setInt32(4, memory.length);
    return memory.value;
  }

  // The result is a segmented message. Build a memory block that
  // contains the addresses and sizes of all of them.
  int segments = segment._builder._segments;
  int size = 8 + (segments * 16);
  Foreign buffer = new Foreign.allocated(size);
  // Mark the result as being segmented.
  buffer.setInt32(0, segments);
  int offset = 8;
  do {
    buffer.setInt64(offset, segment.memory.value);
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

  String readString(ListReader reader, int offset) {
    List<int> charCodes = readList(reader, offset);
    return new String.fromCharCodes(charCodes);
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

  // TODO(zerny): Move this to a mixin base.
  Iterator get iterator { throw new UnsupportedError("ListBuilder::iterator"); }
  Iterable map(Function f) { throw new UnsupportedError("ListBuilder::map"); }
  Iterable where(Function test) { throw new UnsupportedError("ListBuilder::where"); }
  Iterable expand(Function f) { throw new UnsupportedError("ListBuilder::expand"); }
  bool contains(Object element) { throw new UnsupportedError("ListBuilder::contains"); }
  void forEach(Function f) { throw new UnsupportedError("ListBuilder::forEach"); }
  reduce(Function combine) { throw new UnsupportedError("ListBuilder::reduce"); }
  dynamic fold(init, Function combine) { throw new UnsupportedError("ListBuilder::fold"); }
  bool every(Function test) { throw new UnsupportedError("ListBuilder::every"); }
  String join([String separator = ""]) { throw new UnsupportedError("ListBuilder::join"); }
  bool any(Function test) { throw new UnsupportedError("ListBuilder::any"); }
  List toList({ bool growable: true }) { throw new UnsupportedError("ListBuilder::toList"); }
  Set toSet() { throw new UnsupportedError("ListBuilder::toSet"); }
  bool get isEmpty { throw new UnsupportedError("ListBuilder::isEmpty"); }
  bool get isNotEmpty { throw new UnsupportedError("ListBuilder::isNotEmpty"); }
  Iterable take(int count) { throw new UnsupportedError("ListBuilder::take"); }
  Iterable takeWhile(Function test) { throw new UnsupportedError("ListBuilder::takeWhile"); }
  Iterable skip(int count) { throw new UnsupportedError("ListBuilder::skip"); }
  Iterable skipWhile(Function test) { throw new UnsupportedError("ListBuilder::skipWhile"); }
  get first { throw new UnsupportedError("ListBuilder::first"); }
  get last { throw new UnsupportedError("ListBuilder::last"); }
  get single { throw new UnsupportedError("ListBuilder::single"); }
  firstWhere(Function test, { orElse() }) { throw new UnsupportedError("ListBuilder::firstWhere"); }
  lastWhere(Function test, { orElse() }) { throw new UnsupportedError("ListBuilder::lastWhere"); }
  singleWhere(Function test) { throw new UnsupportedError("ListBuilder::singleWhere"); }
  elementAt(int index) { throw new UnsupportedError("ListBuilder::elementAt"); }
  void operator []=(int index, value) { throw new UnsupportedError("ListBuilder::operator []="); }
  void set length(int newLength) { throw new UnsupportedError("ListBuilder::set"); }
  void add(value) { throw new UnsupportedError("ListBuilder::add"); }
  void addAll(Iterable iterable) { throw new UnsupportedError("ListBuilder::addAll"); }
  Iterable get reversed { throw new UnsupportedError("ListBuilder::reversed"); }
  void sort([int compare(a, b)]) { throw new UnsupportedError("ListBuilder::sort"); }
  void shuffle([random]) { throw new UnsupportedError("ListBuilder::shuffle"); }
  int indexOf(element, [int start = 0]) { throw new UnsupportedError("ListBuilder::indexOf"); }
  int lastIndexOf(element, [int start]) { throw new UnsupportedError("ListBuilder::lastIndexOf"); }
  void clear() { throw new UnsupportedError("ListBuilder::clear"); }
  void insert(int index, element) { throw new UnsupportedError("ListBuilder::insert"); }
  void insertAll(int index, Iterable iterable) { throw new UnsupportedError("ListBuilder::insertAll"); }
  void setAll(int index, Iterable iterable) { throw new UnsupportedError("ListBuilder::setAll"); }
  bool remove(Object value) { throw new UnsupportedError("ListBuilder::remove"); }
  removeAt(int index) { throw new UnsupportedError("ListBuilder::removeAt"); }
  removeLast() { throw new UnsupportedError("ListBuilder::removeLast"); }
  void removeWhere(Function test) { throw new UnsupportedError("ListBuilder::removeWhere"); }
  void retainWhere(Function test) { throw new UnsupportedError("ListBuilder::retainWhere"); }
  List sublist(int start, [int end]) { throw new UnsupportedError("ListBuilder::sublist"); }
  Iterable getRange(int start, int end) { throw new UnsupportedError("ListBuilder::getRange"); }
  void setRange(int start, int end, Iterable iterable, [int skipCount = 0]) { throw new UnsupportedError("ListBuilder::setRange"); }
  void removeRange(int start, int end) { throw new UnsupportedError("ListBuilder::removeRange"); }
  void fillRange(int start, int end, [fillValue]) { throw new UnsupportedError("ListBuilder::fillRange"); }
  void replaceRange(int start, int end, Iterable replacement) { throw new UnsupportedError("ListBuilder::replaceRange"); }
  Map asMap() { throw new UnsupportedError("ListBuilder::asMap"); }
}

class BuilderSegment {
  final MessageBuilder _builder;
  final Foreign memory;
  int _id;
  int _used = 0;
  BuilderSegment _next;

  BuilderSegment(this._builder, this._id, int space)
      : memory = new Foreign.allocated(space);

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
  int _segments = 1;

  MessageBuilder(int space) {
    _first = new BuilderSegment(this, 0, space);
    _last = _first;
  }

  Builder initRoot(Builder builder, int size) {
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

  Builder NewStruct(Builder builder, int offset, int size) {
    offset += _offset;
    BuilderSegment segment = _segment;
    while (true) {
      int result = segment.Allocate(size);
      Foreign memory = segment.memory;
      if (result >= 0) {
        memory.setInt32(offset + 0, (result << 2) | 1);
        memory.setInt32(offset + 4, 0);
        builder._segment = segment;
        builder._offset = result;
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
    list._length = length;
    offset += _offset;
    size *= length;
    BuilderSegment segment = _segment;
    while (true) {
      int result = segment.Allocate(size);
      Foreign memory = segment.memory;
      if (result >= 0) {
        memory.setInt32(offset + 0, (result << 2) | 1);
        memory.setInt32(offset + 4, length);
        list._segment = segment;
        list._offset = result;
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

class ListBuilder extends Builder {
  int _length;
  int get length => _length;

  readListElement(Builder builder, int index, int size) {
    builder._segment = _segment;
    builder._offset = _offset + index * size;
    return builder;
  }

  // TODO(zerny): Move this to a mixin base.
  Iterator get iterator { throw new UnsupportedError("ListBuilder::iterator"); }
  Iterable map(Function f) { throw new UnsupportedError("ListBuilder::map"); }
  Iterable where(Function test) { throw new UnsupportedError("ListBuilder::where"); }
  Iterable expand(Function f) { throw new UnsupportedError("ListBuilder::expand"); }
  bool contains(Object element) { throw new UnsupportedError("ListBuilder::contains"); }
  void forEach(Function f) { throw new UnsupportedError("ListBuilder::forEach"); }
  reduce(Function combine) { throw new UnsupportedError("ListBuilder::reduce"); }
  dynamic fold(init, Function combine) { throw new UnsupportedError("ListBuilder::fold"); }
  bool every(Function test) { throw new UnsupportedError("ListBuilder::every"); }
  String join([String separator = ""]) { throw new UnsupportedError("ListBuilder::join"); }
  bool any(Function test) { throw new UnsupportedError("ListBuilder::any"); }
  List toList({ bool growable: true }) { throw new UnsupportedError("ListBuilder::toList"); }
  Set toSet() { throw new UnsupportedError("ListBuilder::toSet"); }
  bool get isEmpty { throw new UnsupportedError("ListBuilder::isEmpty"); }
  bool get isNotEmpty { throw new UnsupportedError("ListBuilder::isNotEmpty"); }
  Iterable take(int count) { throw new UnsupportedError("ListBuilder::take"); }
  Iterable takeWhile(Function test) { throw new UnsupportedError("ListBuilder::takeWhile"); }
  Iterable skip(int count) { throw new UnsupportedError("ListBuilder::skip"); }
  Iterable skipWhile(Function test) { throw new UnsupportedError("ListBuilder::skipWhile"); }
  get first { throw new UnsupportedError("ListBuilder::first"); }
  get last { throw new UnsupportedError("ListBuilder::last"); }
  get single { throw new UnsupportedError("ListBuilder::single"); }
  firstWhere(Function test, { orElse() }) { throw new UnsupportedError("ListBuilder::firstWhere"); }
  lastWhere(Function test, { orElse() }) { throw new UnsupportedError("ListBuilder::lastWhere"); }
  singleWhere(Function test) { throw new UnsupportedError("ListBuilder::singleWhere"); }
  elementAt(int index) { throw new UnsupportedError("ListBuilder::elementAt"); }
  void operator []=(int index, value) { throw new UnsupportedError("ListBuilder::operator []="); }
  void set length(int newLength) { throw new UnsupportedError("ListBuilder::set"); }
  void add(value) { throw new UnsupportedError("ListBuilder::add"); }
  void addAll(Iterable iterable) { throw new UnsupportedError("ListBuilder::addAll"); }
  Iterable get reversed { throw new UnsupportedError("ListBuilder::reversed"); }
  void sort([int compare(a, b)]) { throw new UnsupportedError("ListBuilder::sort"); }
  void shuffle([random]) { throw new UnsupportedError("ListBuilder::shuffle"); }
  int indexOf(element, [int start = 0]) { throw new UnsupportedError("ListBuilder::indexOf"); }
  int lastIndexOf(element, [int start]) { throw new UnsupportedError("ListBuilder::lastIndexOf"); }
  void clear() { throw new UnsupportedError("ListBuilder::clear"); }
  void insert(int index, element) { throw new UnsupportedError("ListBuilder::insert"); }
  void insertAll(int index, Iterable iterable) { throw new UnsupportedError("ListBuilder::insertAll"); }
  void setAll(int index, Iterable iterable) { throw new UnsupportedError("ListBuilder::setAll"); }
  bool remove(Object value) { throw new UnsupportedError("ListBuilder::remove"); }
  removeAt(int index) { throw new UnsupportedError("ListBuilder::removeAt"); }
  removeLast() { throw new UnsupportedError("ListBuilder::removeLast"); }
  void removeWhere(Function test) { throw new UnsupportedError("ListBuilder::removeWhere"); }
  void retainWhere(Function test) { throw new UnsupportedError("ListBuilder::retainWhere"); }
  List sublist(int start, [int end]) { throw new UnsupportedError("ListBuilder::sublist"); }
  Iterable getRange(int start, int end) { throw new UnsupportedError("ListBuilder::getRange"); }
  void setRange(int start, int end, Iterable iterable, [int skipCount = 0]) { throw new UnsupportedError("ListBuilder::setRange"); }
  void removeRange(int start, int end) { throw new UnsupportedError("ListBuilder::removeRange"); }
  void fillRange(int start, int end, [fillValue]) { throw new UnsupportedError("ListBuilder::fillRange"); }
  void replaceRange(int start, int end, Iterable replacement) { throw new UnsupportedError("ListBuilder::replaceRange"); }
  Map asMap() { throw new UnsupportedError("ListBuilder::asMap"); }
}
