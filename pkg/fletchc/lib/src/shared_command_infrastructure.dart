// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Provides common infrastructure for reading commads from a [Stream].
///
/// We have two independent command kinds that follow the same scheme:
///
///   1. ../commands.dart
///   2. driver/driver_commands.dart
///
/// Both commands are serialized in this format (using little endian):
///
///   * Byte offset 0: one byte (code) which corresponds to an enum value.
///   * Byte offset 1: four bytes payload length (unsigned int).
///   * Byte offset 5: payload length bytes of payload.
library fletchc.src.command_transformer_builder;

import 'dart:async' show
    EventSink,
    StreamTransformer;

import 'dart:io' show
    BytesBuilder;

import 'dart:typed_data' show
    ByteData,
    Endianness,
    TypedData,
    Uint32List,
    Uint8List;

const Endianness commandEndianness = Endianness.LITTLE_ENDIAN;

/// 32 bit package length + 8 bit code is 5 bytes.
const headerSize = 5;

/// [C] is the command implementation class.
abstract class CommandTransformerBuilder<C> {
  StreamTransformer<List<int>, C> build() {
    BytesBuilder builder = new BytesBuilder(copy: false);

    ByteData toByteData(TypedData data, [int offset = 0, int length]) {
      return data.buffer.asByteData(data.offsetInBytes + offset, length);
    }

    void handleData(Uint8List data, EventSink<C> sink) {
      builder.add(toUint8ListView(data));
      Uint8List list = builder.takeBytes();

      ByteData view = toByteData(list);

      while (view.lengthInBytes >= headerSize) {
        int length = view.getUint32(0, commandEndianness);
        if ((view.lengthInBytes - headerSize) < length) {
          // Not all of the payload has arrived yet.
          break;
        }
        int code = view.getUint8(4);

        ByteData payload = toByteData(view, headerSize, length);

        C command = makeCommand(code, payload);

        if (command != null) {
          sink.add(command);
        } else {
          sink.addError("Command not implemented yet: $code");
        }

        view = toByteData(payload, length);
      }

      if (view.lengthInBytes > 0) {
        builder.add(toUint8ListView(view));
      }
    }

    void handleError(error, StackTrace stackTrace, EventSink<C> sink) {
      sink.addError(error, stackTrace);
    }

    void handleDone(EventSink<C> sink) {
      List trailing = builder.takeBytes();
      if (trailing.length != 0) {
        sink.addError(
            new StateError("Stream closed with trailing bytes : $trailing"));
      }
      sink.close();
    }

    return new StreamTransformer<List<int>, C>.fromHandlers(
        handleData: handleData,
        handleError: handleError,
        handleDone: handleDone);
  }

  C makeCommand(int code, ByteData payload);
}

Uint8List toUint8ListView(TypedData list, [int offset = 0, int length]) {
  if (length == null) {
    length = list.lengthInBytes;
  }
  return new Uint8List.view(list.buffer, list.offsetInBytes + offset, length);
}

/// [E] is an enum.
class CommandBuffer<E> {
  int position = headerSize;

  Uint8List list = new Uint8List(16);

  ByteData get view => new ByteData.view(list.buffer);

  void growBytes(int size) {
    while (position + size >= list.length) {
      list = new Uint8List(list.length * 2)
          ..setRange(0, list.length, list);
    }
  }

  void addUint8(int value) {
    growBytes(1);
    view.setUint8(position++, value);
  }

  void addUint32(int value) {
    // TODO(ahe): The C++ appears to often read 32-bit values into a signed
    // integer. Figure which is signed and which is unsigned.
    growBytes(4);
    view.setUint32(position, value, commandEndianness);
    position += 4;
  }

  void addUint64(int value) {
    growBytes(8);
    view.setUint64(position, value, commandEndianness);
    position += 8;
  }

  void addDouble(double value) {
    growBytes(8);
    view.setFloat64(position, value, commandEndianness);
    position += 8;
  }

  void addUint8List(List<int> value) {
    growBytes(value.length);
    list.setRange(position, position + value.length, value);
    position += value.length;
  }

  void sendOn(Sink<List<int>> sink, E code) {
    view.setUint32(0, position - headerSize, commandEndianness);
    view.setUint8(4, (code as dynamic).index);
    sink.add(list.sublist(0, position));
    position = headerSize;
  }

  static bool readBoolFromBuffer(Uint8List buffer, int offset) {
    return buffer[offset] != 0;
  }

  static String readStringFromBuffer(Uint8List buffer, int offset, int length) {
    const bytesPerCharacter = 4;
    int numberOfCharacters = length ~/ bytesPerCharacter;
    assert(length == numberOfCharacters * bytesPerCharacter);
    if (((buffer.offsetInBytes + offset) % Uint32List.BYTES_PER_ELEMENT) != 0) {
      // Uint32List.view throws ArgumentError if offset isn't muliple of 4.
      buffer = new Uint8List.fromList(buffer);
    }
    return new String.fromCharCodes(
        new Uint32List.view(
            buffer.buffer, buffer.offsetInBytes + offset, numberOfCharacters));
  }

  static String readAsciiStringFromBuffer(
      Uint8List buffer, int offset, int length) {
    return new String.fromCharCodes(
        new Uint8List.view(
            buffer.buffer, buffer.offsetInBytes + offset, length));
  }

  static int readUint32FromBuffer(Uint8List buffer, int offset) {
    return buffer.buffer.asByteData(buffer.offsetInBytes)
        .getUint32(offset, commandEndianness);
  }

  static int readUint64FromBuffer(Uint8List buffer, int offset) {
    return buffer.buffer.asByteData(buffer.offsetInBytes)
        .getUint64(offset, commandEndianness);
  }

  static double readDoubleFromBuffer(Uint8List buffer, int offset) {
    return buffer.buffer.asByteData(buffer.offsetInBytes)
        .getFloat64(offset, commandEndianness);
  }
}
