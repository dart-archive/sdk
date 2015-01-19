// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of session;

int readInt32FromBuffer(List<int> buffer, int offset) {
  return _readIntFromBuffer(buffer, offset, 4);
}

int readInt64FromBuffer(List<int> buffer, int offset) {
  return _readIntFromBuffer(buffer, offset, 8);
}

void writeInt32ToBuffer(List<int> buffer, int offset, int value) {
  _writeIntToBuffer(buffer, offset, value, 4);
}

void writeInt64ToBuffer(List<int> buffer, int offset, int value) {
  _writeIntToBuffer(buffer, offset, value, 8);
}

int _readIntFromBuffer(List<int> buffer, int offset, int sizeInBytes) {
  assert(buffer.length >= offset + sizeInBytes);
  int result = 0;
  for (int i = 0; i < sizeInBytes; ++i) {
    result |= buffer[i + offset] << (i * 8);
  }
  return result;
}

void _writeIntToBuffer(List<int> buffer,
                       int offset,
                       int value,
                       int sizeInBytes) {
  assert(buffer.length >= offset + sizeInBytes);
  for (int i = 0; i < sizeInBytes; ++i) {
    buffer[i + offset] = (value >> (i * 8)) & 0xFF;
  }
}
