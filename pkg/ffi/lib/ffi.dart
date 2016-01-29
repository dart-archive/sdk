// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Higher level access to the FFI library.
///
/// This package is a set of functions and classes that builds on the lower
/// level FFI library (dart:fletch.ffi).
library ffi;

import 'dart:fletch.ffi';
import 'dart:typed_data';

part 'utf.dart';

final ForeignFunction _strlen = ForeignLibrary.main.lookup('strlen');

/// Converts a C string to a String in the Fletch heap.
/// This call expects a null terminated string. The string will be decoded
/// using a UTF8 decoder.
String cStringToString(ForeignPointer ptr) {
  int length = _strlen.icall$1(ptr);
  return memoryToString(ptr, length);
}

/// Converts a C memory region to a String in the Fletch heap. The string
/// will be decoded using a UTF8 decoder.
String memoryToString(ForeignPointer ptr, int length) {
  var memory = new ForeignMemory.fromAddress(ptr.address, length);
  var encodedString = new List(length);
  for (int i = 0; i < length; ++i) {
    encodedString[i] = memory.getUint8(i);
  }
  return _decodeUtf8(encodedString);
}

/**
 * A circular buffer used from both dart and c. The buffer has the start index
 * and the end index as the first two 4 byte integers in the underlying foreign
 * memory, and the size as the next 4.
 * This is _not_ thread safe, only access this from either c or dart at any
 * point in time.
 */
class CircularByteBuffer {
  static const int HEAD_INDEX = 0;
  static const int TAIL_INDEX = 4;
  static const int SIZE_INDEX = 8;
  static const int DATA_START = 12;
  static const int HEADER_SIZE = 12;

  final ForeignMemory _buffer;

  int get _head => _buffer.getInt32(HEAD_INDEX);
  int set _head(value) => _buffer.setInt32(HEAD_INDEX, value);
  int get _tail => _buffer.getInt32(TAIL_INDEX);
  int set _tail(value) => _buffer.setInt32(TAIL_INDEX, value);
  int get _size => _buffer.getInt32(SIZE_INDEX);
  int set _size(value) => _buffer.setInt32(SIZE_INDEX, value);
  ForeignMemory get foreign => _buffer;

  /**
   * Creates a new buffer capable of holding size bytes. The underlying memory
   * has 8 additional bytes for holding the head, tail and size, and one more
   * byte to distinguish empty from full.
   */
  CircularByteBuffer(int size) :
      // + DATA_START for the indexes, +1 to distinguesh between full and empty
      _buffer = new ForeignMemory.allocatedFinalized(size + HEADER_SIZE + 1) {
    this._head = 0;
    this._tail = 0;
    this._size = size + 1;
  }

  bool get isFull => ((_head + 1) % _size) == _tail;

  bool get isEmpty => _head == _tail;

  /**
   * Return the number of available bytes that can be read.
   */
  int get available {
    if (isEmpty) return 0;
    if (_head > _tail) return _head - _tail;
    return _size - _tail + _head;
  }

  /**
   * Return the number of bytes we can write to the buffer.
   */
  int get freeSpace => _size - available - 1;

  /**
   * Read at most lenght bytes into buffer, starting at index index. Returns the
   * number of bytes read into the buffer. If length is not provided use the
   * length in bytes of the buffer, minus the start index.
   */
  int read(ByteBuffer buffer, [int index = 0, int length]) {
    if (isEmpty) return 0;
    Uint8List bytelist = buffer.asUint8List(index, length);
    if (length == null) length  = buffer.lengthInBytes - index;
    int bytes = length > available ? available : length;
    // Avoid doing the mem read every time, we will write it back when we are
    // done reading.
    int tail = _tail;
    // TODO(ricow): Consider if we should do a memcpy here (two if wrapping)
    for (int i = 0; i < bytes; i++) {
      bytelist[i] = _buffer.getUint8(DATA_START + tail);
      tail = (tail + 1) % _size;
    }
    _tail = tail;
    return bytes;
  }

  /**
   * Write at most lenght bytes from buffer, starting to read bytes at index
   * index. Returns the number of bytes written into the buffer. If length is
   * not provided use the length in bytes of the buffer, minus the start index.
   */
  int write(ByteBuffer buffer, [int index = 0, int length]) {
    if (isFull) return 0;
    Uint8List bytelist = buffer.asUint8List(index, length);
    if (length == null) length = buffer.lengthInBytes - index;
    int bytes = length > freeSpace ? freeSpace : length;
    // Avoid doing the mem read every time, we will write it back when we are
    // done writing.
    int head = _head;
    // TODO(ricow): Consider if we should do a memcpy here (two if wrapping)
    for (int i = 0; i < bytes; i++) {
      _buffer.setUint8(DATA_START + head, bytelist[i]);
      head = (head + 1) % _size;
    }
    _head = head;
    return bytes;
  }
}
