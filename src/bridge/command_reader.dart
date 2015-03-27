// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of session;

class Chunk {
  List _data;
  Chunk next;

  Chunk(this._data);

  int get length => _data.length;
  int operator [](int index) => _data[index];
}

class CommandReader {
  final Socket _socket;
  Chunk _first;
  Chunk _last;
  int _index;

  Chunk _currentChunk;
  int _currentIndex;

  CommandReader(this._socket) : _index = 0;

  // TODO(ager): Don't use asBroadcastStream on the stream. However, at this
  // point if we don't make the stream a broadcast stream it terminates
  // prematurely.
  StreamIterator get iterator
      => new StreamIterator(stream().asBroadcastStream());

  Stream<Command> stream() async* {
    await for (List data in _socket) {
      addData(data);
      Command command = readCommand();
      while (command != null) {
        yield command;
        command = readCommand();
      }
    }
  }

  void addData(List data) {
    if (_first == null) {
      _first = _last = new Chunk(data);
    } else {
      _last.next = new Chunk(data);
      _last = _last.next;
    }
  }

  int readByte() {
    if (_currentChunk == null) return null;
    if (_currentIndex < _currentChunk.length) {
      return _currentChunk[_currentIndex++];
    }
    _currentChunk = _currentChunk.next;
    _currentIndex = 0;
    return readByte();
  }

  int readInt() {
    var result = 0;
    for (int i = 0; i < 4; ++i) {
      var byte = readByte();
      if (byte == null) return null;
      result |= byte << (i * 8);
    }
    return result;
  }

  List readBytes(int size) {
    var result = new List(size);
    for (int i = 0; i < size; ++i) {
      int byte = readByte();
      if (byte == null) return null;
      result[i] = byte;
    }
    return result;
  }

  void advance() {
    _first = _currentChunk;
    if (_first == null) _last = _first;
    _index = _currentIndex;
  }

  void reset() {
    _currentChunk = _first;
    _currentIndex = _index;
  }

  Command readCommand() {
    reset();
    var length = readInt();
    if (length == null) return null;
    var opcode = readByte();
    if (opcode == null) return null;
    var buffer = readBytes(length);
    if (buffer == null) return null;
    advance();
    return new Command(Opcode.values[opcode], buffer);
  }
}
