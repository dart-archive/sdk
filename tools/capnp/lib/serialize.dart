// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library capnp.serialize;

import 'dart:typed_data';
import 'dart:math' show max;
import 'dart:io' show BytesBuilder;

import 'message.dart';
import 'internals.dart';

class BufferedMessageReader extends MessageReader {
  final List<Segment> _segments;

  factory BufferedMessageReader(ByteData bytes) {
    int segments = bytes.getUint32(0, Endianness.LITTLE_ENDIAN) + 1;
    return new BufferedMessageReader._internal(segments, bytes);
  }

  BufferedMessageReader._internal(int segments, ByteData bytes)
      : _segments = new List<Segment>(segments) {

    // Compute the starting offset taking care of any padding.
    int offset = 4 * (segments + 1);
    if (offset % 8 != 0) offset += 4;

    // TODO(kasperl): Stop create segment objects if possible.
    ByteBuffer buffer = bytes.buffer;
    for (int i = 0; i < segments; i++) {
      int size = bytes.getUint32(4 * (i + 1), Endianness.LITTLE_ENDIAN) * 8;
      ByteData segmentBytes = new ByteData.view(buffer, offset, size);
      _segments[i] = new ReaderSegment(segmentBytes, this);
      offset += size;
    }
  }

  Struct getRoot(Struct out) {
    return readStructRoot(out, _segments.first);
  }

  Segment getSegment(int id) {
    return (id >= 0 && id < _segments.length) ? _segments[id] : null;
  }
}

class BufferedMessageBuilder extends MessageBuilder {
  final List<BuilderSegment> _segments = <BuilderSegment>[];

  StructBuilder initRoot(StructBuilder out) {
    // Create the initial segment.
    BuilderSegment segment = _newSegment(1024);
    return writeStructRoot(out, segment);
  }

  Segment findSegmentForBytes(int bytes) {
    BuilderSegment last = _segments.last;
    if (last.hasCapacityForBytes(bytes)) return last;
    return _newSegment(max(bytes ~/ 8, 1024));
  }

  ByteData toFlatList() {
    BytesBuilder builder = new BytesBuilder(copy: false);
    int entries = 1 + _segments.length;
    if ((entries & 1) != 0) entries++;

    Uint8List header = new Uint8List(entries * 4);
    ByteData headerData = header.buffer.asByteData();

    headerData.setUint32(0, _segments.length - 1, Endianness.LITTLE_ENDIAN);
    for (int i = 0; i < _segments.length; i++) {
      int size = _segments[i].length ~/ 8;
      headerData.setUint32(4 * (i + 1), size, Endianness.LITTLE_ENDIAN);
    }
    builder.add(header);

    for (int i = 0; i < _segments.length; i++) {
      ByteData segmentData = _segments[i].bytes;
      builder.add(segmentData.buffer.asUint8List(0, _segments[i].length));
    }

    Uint8List list = builder.takeBytes();
    return list.buffer.asByteData();
  }

  BuilderSegment _newSegment(int words) {
    ByteBuffer buffer = new Uint64List(words).buffer;
    int size = words * 8;
    ByteData bytes = new ByteData.view(buffer, 0, size);
    int id = _segments.length;
    BuilderSegment segment = new BuilderSegment(bytes, this, id);
    _segments.add(segment);
    return segment;
  }
}