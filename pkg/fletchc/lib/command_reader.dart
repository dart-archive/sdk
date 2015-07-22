// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of fletch.session;

class Chunk {
  List data;
  Chunk next;

  Chunk(this.data);

  int get length => data.length;
  int operator [](int index) => data[index];
}

class CommandReader {
  final Socket socket;

  StreamIterator<Command> iterator;

  Chunk first;
  Chunk last;
  int index;

  Chunk currentChunk;
  int currentIndex;

  CommandReader(this.socket,
                EventSink<List<int>> stdoutSink,
                EventSink<List<int>> stderrSink) : index = 0 {
    iterator = new StreamIterator<Command>(
        filterCommandStream(stdoutSink, stderrSink));
  }

  Stream<Command> filterCommandStream(EventSink<List<int>> stdoutSink,
                                      EventSink<List<int>> stderrSink) async* {
    await for (List data in socket) {
      addData(data);
      Command command = readCommand();
      while (command != null) {
        if (command is StdoutData) {
          if (stdoutSink != null) {
            StdoutData data = command;
            stdoutSink.add(command.value);
          }
        } else if (command is StderrData) {
          if (stderrSink != null) {
            StderrData data = command;
            stderrSink.add(command.value);
          }
        } else {
          yield command;
        }
        command = readCommand();
      }
    }
  }

  void addData(List data) {
    if (first == null) {
      first = last = new Chunk(data);
    } else {
      last.next = new Chunk(data);
      last = last.next;
    }
  }

  int readByte() {
    if (currentChunk == null) return null;
    if (currentIndex < currentChunk.length) {
      return currentChunk[currentIndex++];
    }
    currentChunk = currentChunk.next;
    currentIndex = 0;
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

  Uint8List readBytes(int size) {
    var result = new Uint8List(size);
    for (int i = 0; i < size; ++i) {
      int byte = readByte();
      if (byte == null) return null;
      result[i] = byte;
    }
    return result;
  }

  void advance() {
    first = currentChunk;
    if (first == null) last = first;
    index = currentIndex;
  }

  void reset() {
    currentChunk = first;
    currentIndex = index;
  }

  Command readCommand() {
    reset();
    var length = readInt();
    if (length == null) return null;
    var code = readByte();
    if (code == null) return null;
    var buffer = readBytes(length);
    if (buffer == null) return null;
    advance();
    return new Command.fromBuffer(CommandCode.values[code], buffer);
  }
}
