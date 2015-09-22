// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// The dart:fletch.ffi library is a low-level 'foreign function interface'
// library that allows Dart code to call arbitrary native platform
// code defined outside the VM.
library dart.fletch.ffi;

import 'dart:convert' show UTF8;
import 'dart:_fletch_system' as fletch;
import 'dart:fletch';

abstract class Foreign {
  int get address;

  const Foreign();

  static const int UNKNOWN = 0;

  static const int LINUX = 1;
  static const int MACOS = 2;
  static const int ANDROID = 3;

  static const int IA32 = 1;
  static const int X64 = 2;
  static const int ARM = 3;

  // TODO(kasperl): Not quite sure where this fits in.
  static final int bitsPerMachineWord = _bitsPerMachineWord();
  static final int machineWordSize = bitsPerMachineWord ~/ 8;
  static final int platform = _platform();
  static final int architecture = _architecture();

  static int get errno => _errno();

  // Helper for converting the argument to a machine word.
  int _convert(argument) {
    if (argument is Foreign) return argument.address;
    if (argument is Port) return _convertPort(argument);
    if (argument is int) return argument;
    throw new ArgumentError();
  }

  @fletch.native external static int _bitsPerMachineWord();
  @fletch.native external static int _errno();
  @fletch.native external static int _platform();
  @fletch.native external static int _architecture();
  @fletch.native external static int _convertPort(Port port);
}

class ForeignFunction extends Foreign {
  final int address;
  const ForeignFunction.fromAddress(this.address);

  /// Helper function for retrying functions that follow the POSIX-convention
  /// of returning `-1` and setting `errno` to `EINTR`.
  ///
  /// The function [f] will be retried as long as it is returning returning
  /// `-1` and `errno` is `EINTR`. When that is not the case the return value
  /// will be the return value of `f`.
  static int retry(Function f) {
    const EINTR = 4;
    int value;
    while ((value = f()) == -1) {
      if (Foreign.errno != EINTR) break;
    }
    return value;
  }

  // Support for calling foreign functions that return
  // integers.
  int icall$0() => _icall$0(address);
  int icall$1(a0) => _icall$1(address, _convert(a0));
  int icall$2(a0, a1) => _icall$2(address, _convert(a0), _convert(a1));
  int icall$3(a0, a1, a2) {
    return _icall$3(address, _convert(a0), _convert(a1), _convert(a2));
  }

  int icall$4(a0, a1, a2, a3) {
    return _icall$4(
        address, _convert(a0), _convert(a1), _convert(a2), _convert(a3));
  }

  int icall$5(a0, a1, a2, a3, a4) {
    return _icall$5(address, _convert(a0), _convert(a1), _convert(a2),
        _convert(a3), _convert(a4));
  }

  int icall$6(a0, a1, a2, a3, a4, a5) {
    return _icall$6(address, _convert(a0), _convert(a1), _convert(a2),
        _convert(a3), _convert(a4), _convert(a5));
  }

  // Support for calling foreign functions that return
  // integers. The functions with the suffix `Retry` can be used for calling
  // functions that follow functions that follow the POSIX-convention
  // of returning `-1` and setting `errno` to `EINTR` when they where
  // interrupted and should be retried.
  int icall$0Retry() => retry(() => icall$0());
  int icall$1Retry(a0) => retry(() => icall$1(a0));
  int icall$2Retry(a0, a1) => retry(() => icall$2(a0, a1));
  int icall$3Retry(a0, a1, a2) => retry(() => icall$3(a0, a1, a2));
  int icall$4Retry(a0, a1, a2, a3) => retry(() => icall$4(a0, a1, a2, a3));
  int icall$5Retry(a0, a1, a2, a3, a4) {
    return retry(() => icall$5(a0, a1, a2, a3, a4));
  }
  int icall$6Retry(a0, a1, a2, a3, a4, a5) {
    return retry(() => icall$6(a0, a1, a2, a3, a4, a5));
  }
  // Support for calling foreign functions that return
  // machine words -- typically pointers -- encapulated in
  // the given foreign object arguments.
  ForeignPointer pcall$0() =>
      new ForeignPointer(_pcall$0(address));

  ForeignPointer pcall$1(a0) =>
      new ForeignPointer(_pcall$1(address, _convert(a0)));

  ForeignPointer pcall$2(a0, a1) =>
      new ForeignPointer(_pcall$2(address, _convert(a0), _convert(a1)));

  ForeignPointer pcall$3(a0, a1, a2) =>
      new ForeignPointer(_pcall$3(address, _convert(a0), _convert(a1),
                                  _convert(a2)));

  ForeignPointer pcall$4(a0, a1, a2, a3) =>
      new ForeignPointer(_pcall$4(address, _convert(a0), _convert(a1),
                                  _convert(a2), _convert(a3)));

  ForeignPointer pcall$5(a0, a1, a2, a3, a4) =>
      new ForeignPointer(_pcall$5(address, _convert(a0), _convert(a1),
                                  _convert(a2), _convert(a3), _convert(a4)));

  ForeignPointer pcall$6(a0, a1, a2, a3, a4, a5) =>
      new ForeignPointer(_pcall$6(address, _convert(a0), _convert(a1),
                                  _convert(a2), _convert(a3), _convert(a4),
                                  _convert(a5)));

  // Support for calling foreign functions with no return value.
  void vcall$0() {
    _vcall$0(address);
  }

  void vcall$1(a0) {
    _vcall$1(address, _convert(a0));
  }

  void vcall$2(a0, a1) {
    _vcall$2(address, _convert(a0), _convert(a1));
  }

  void vcall$3(a0, a1, a2) {
    _vcall$3(address, _convert(a0), _convert(a1), _convert(a2));
  }

  void vcall$4(a0, a1, a2, a3) {
    _vcall$4(address, _convert(a0), _convert(a1), _convert(a2), _convert(a3));
  }

  void vcall$5(a0, a1, a2, a3, a4) {
    _vcall$5(address, _convert(a0), _convert(a1), _convert(a2), _convert(a3),
        _convert(a4));
  }

  void vcall$6(a0, a1, a2, a3, a4, a5) {
    _vcall$6(address, _convert(a0), _convert(a1), _convert(a2), _convert(a3),
        _convert(a4), _convert(a5));
  }

  // TODO(ricow): this is insanely specific and only used for rseek.
  // Support for calling foreign functions that
  //  - Returns a 64 bit integer value.
  //  - Takes:
  //    * a word,
  //    * a 64 bit int
  //    * a word
  int Lcall$wLw(a0, a1, a2) {
    return _Lcall$wLw(address, _convert(a0), _convert(a1), _convert(a2));
  }

  int Lcall$wLwRetry(a0, a1, a2) => retry(() => Lcall$wLw(a0, a1, a2));

  @fletch.native external static int _icall$0(int address);
  @fletch.native external static int _icall$1(int address, a0);
  @fletch.native external static int _icall$2(int address, a0, a1);
  @fletch.native external static int _icall$3(int address, a0, a1, a2);
  @fletch.native external static int _icall$4(int address, a0, a1, a2, a3);
  @fletch.native external static int _icall$5(int address, a0, a1, a2, a3, a4);
  @fletch.native external static int _icall$6(
      int address, a0, a1, a2, a3, a4, a5);

  @fletch.native external static int _pcall$0(int address);
  @fletch.native external static int _pcall$1(int address, a0);
  @fletch.native external static int _pcall$2(int address, a0, a1);
  @fletch.native external static int _pcall$3(int address, a0, a1, a2);
  @fletch.native external static int _pcall$4(int address, a0, a1, a2, a3);
  @fletch.native external static int _pcall$5(int address, a0, a1, a2, a3, a4);
  @fletch.native external static int _pcall$6(
      int address, a0, a1, a2, a3, a4, a5);

  @fletch.native external static int _vcall$0(int address);
  @fletch.native external static int _vcall$1(int address, a0);
  @fletch.native external static int _vcall$2(int address, a0, a1);
  @fletch.native external static int _vcall$3(int address, a0, a1, a2);
  @fletch.native external static int _vcall$4(int address, a0, a1, a2, a3);
  @fletch.native external static int _vcall$5(int address, a0, a1, a2, a3, a4);
  @fletch.native external static int _vcall$6(
      int address, a0, a1, a2, a3, a4, a5);

  @fletch.native external static int _Lcall$wLw(int address, a0, a1, a2);
}

class ForeignPointer extends Foreign {
  final int address;
  const ForeignPointer(this.address);

  static const ForeignPointer NULL = const ForeignPointer(0);
}

class ForeignLibrary extends ForeignPointer {
  /// The ForeignLibrary main is used for looking up functions in the libraries
  /// linked in to the main Fletch binary.
  static ForeignLibrary main = new ForeignLibrary.fromName(null);

  const ForeignLibrary.fromAddress(int address) : super(address);

  factory ForeignLibrary.fromName(String name) {
    return new ForeignLibrary.fromAddress(_lookupLibrary(name));
  }

  ForeignFunction lookup(String name) {
    return new ForeignFunction.fromAddress(_lookupFunction(address, name));
  }

  /// Provides a platform specific location for a library relative to the
  /// location of the Fletch vm. Takes the name without lib in front and
  /// returns a platform specific path. Example, on linux, foobar_hash
  /// become PATH_TO_EXECUTABLE/lib/libfoobar_hash.so.
  @fletch.native external static String bundleLibraryName(String libraryName);

  void close() {
    _closeLibrary(address);
  }

  @fletch.native static int _lookupLibrary(String name) {
    var error = fletch.nativeError;
    throw (error != fletch.indexOutOfBounds) ? error : new ArgumentError();
  }

  @fletch.native static int _lookupFunction(int address, String name) {
    var error = fletch.nativeError;
    throw (error != fletch.indexOutOfBounds) ? error : new ArgumentError();
  }

  @fletch.native static int _closeLibrary(int address) {
    var error = fletch.nativeError;
    throw (error != fletch.indexOutOfBounds) ? error : new ArgumentError();
  }
}

abstract class UnsafeMemory extends Foreign {
  int get length;
  const UnsafeMemory();

  int getInt8(int offset) => _getInt8(_computeAddress(offset, 1));
  int getInt16(int offset) => _getInt16(_computeAddress(offset, 2));
  int getInt32(int offset) => _getInt32(_computeAddress(offset, 4));
  int getInt64(int offset) => _getInt64(_computeAddress(offset, 8));

  int setInt8(int offset, int value) =>
      _setInt8(_computeAddress(offset, 1), value);
  int setInt16(int offset, int value) =>
      _setInt16(_computeAddress(offset, 2), value);
  int setInt32(int offset, int value) =>
      _setInt32(_computeAddress(offset, 4), value);
  int setInt64(int offset, int value) =>
      _setInt64(_computeAddress(offset, 8), value);

  int getUint8(int offset) => _getUint8(_computeAddress(offset, 1));
  int getUint16(int offset) => _getUint16(_computeAddress(offset, 2));
  int getUint32(int offset) => _getUint32(_computeAddress(offset, 4));
  int getUint64(int offset) => _getUint64(_computeAddress(offset, 8));

  int setUint8(int offset, int value) =>
      _setUint8(_computeAddress(offset, 1), value);
  int setUint16(int offset, int value) =>
      _setUint16(_computeAddress(offset, 2), value);
  int setUint32(int offset, int value) =>
      _setUint32(_computeAddress(offset, 4), value);
  int setUint64(int offset, int value) =>
      _setUint64(_computeAddress(offset, 8), value);

  double getFloat32(int offset) => _getFloat32(_computeAddress(offset, 4));
  double getFloat64(int offset) => _getFloat64(_computeAddress(offset, 8));

  double setFloat32(int offset, double value) =>
      _setFloat32(_computeAddress(offset, 4), value);
  double setFloat64(int offset, double value) =>
      _setFloat64(_computeAddress(offset, 8), value);

  // Helper for checking bounds and computing derived
  // addresses for memory address functionality.
  int _computeAddress(int offset, int n) {
    if (offset < 0 || offset + n > length) throw new IndexError(offset, this);
    return address + offset;
  }

  void copyBytesToList(List<int> list, int from, int to, int listOffset) {
    int length = to - from;
    for (int i = 0; i < length; i++) {
      list[listOffset + i] = getUint8(from + i);
    }
  }

  void copyBytesFromList(List<int> list, int from, int to, int listOffset) {
    int length = to - from;
    for (int i = 0; i < length; i++) {
      setUint8(from + i, list[listOffset + i]);
    }
  }

  @fletch.native external static int _allocate(int length);
  @fletch.native external void _markForFinalization(int length);

  @fletch.native external static int _getInt8(int address);
  @fletch.native external static int _getInt16(int address);
  @fletch.native external static int _getInt32(int address);
  @fletch.native external static int _getInt64(int address);

  @fletch.native static int _setInt8(int address, int value) {
    throw new ArgumentError();
  }

  @fletch.native static int _setInt16(int address, int value) {
    throw new ArgumentError();
  }

  @fletch.native static int _setInt32(int address, int value) {
    throw new ArgumentError();
  }

  @fletch.native static int _setInt64(int address, int value) {
    throw new ArgumentError();
  }

  @fletch.native external static int _getUint8(int address);
  @fletch.native external static int _getUint16(int address);
  @fletch.native external static int _getUint32(int address);
  @fletch.native external static int _getUint64(int address);

  @fletch.native static int _setUint8(int address, int value) {
    throw new ArgumentError();
  }

  @fletch.native static int _setUint16(int address, int value) {
    throw new ArgumentError();
  }

  @fletch.native static int _setUint32(int address, int value) {
    throw new ArgumentError();
  }

  @fletch.native static int _setUint64(int address, int value) {
    throw new ArgumentError();
  }

  @fletch.native external static double _getFloat32(int address);
  @fletch.native external static double _getFloat64(int address);

  @fletch.native static double _setFloat32(int address, double value) {
    throw new ArgumentError();
  }

  @fletch.native static double _setFloat64(int address, double value) {
    throw new ArgumentError();
  }
}

class ImmutableForeignMemory extends UnsafeMemory {
  final int address;
  final int length;

  const ImmutableForeignMemory.fromAddress(this.address, this.length);

  factory ImmutableForeignMemory.fromAddressFinalized(int address, int length) {
    var memory = new ImmutableForeignMemory.fromAddress(address, length);
    memory._markForFinalization(length);
    return memory;
  }

  factory ImmutableForeignMemory.allocatedFinalized(int length) {
    var memory = new ImmutableForeignMemory.fromAddress(
        UnsafeMemory._allocate(length), length);
    memory._markForFinalization(length);
    return memory;
  }

  const ImmutableForeignMemory.allocated(int length)
      : address = UnsafeMemory._allocate(length),
        length = length;

  // We utf8 encode the string first to support non-ascii characters.
  // NOTE: This is not the correct string encoding for Windows.
  factory ImmutableForeignMemory.fromStringAsUTF8(String str) {
    List<int> encodedString = UTF8.encode(str);
    var memory = new ImmutableForeignMemory.allocated(encodedString.length + 1);
    for (int i = 0; i < encodedString.length; i++) {
      memory.setUint8(i, encodedString[i]);
    }
    memory.setUint8(encodedString.length, 0); // '\0' terminate string
    return memory;
  }
}

class ForeignMemory extends UnsafeMemory {
  int address;
  int length;
  bool _markedForFinalization = false;

  ForeignMemory.fromAddress(this.address, this.length);

  ForeignMemory.fromAddressFinalized(this.address, this.length) {
    _markForFinalization(length);
    _markedForFinalization = true;
  }

  ForeignMemory.allocated(int length)
      : address = UnsafeMemory._allocate(length),
        length = length;

  ForeignMemory.allocatedFinalized(int length)
      : address = UnsafeMemory._allocate(length),
        length = length {
    _markForFinalization(length);
    _markedForFinalization = true;
  }

  // We utf8 encode the string first to support non-ascii characters.
  // NOTE: This is not the correct string encoding for Windows.
  factory ForeignMemory.fromStringAsUTF8(String str) {
    List<int> encodedString = UTF8.encode(str);
    var memory = new ForeignMemory.allocated(encodedString.length + 1);
    for (int i = 0; i < encodedString.length; i++) {
      memory.setUint8(i, encodedString[i]);
    }
    memory.setUint8(encodedString.length, 0); // '\0' terminate string
    return memory;
  }

  void free() {
    if (length > 0) {
      if (_markedForFinalization) {
        _decreaseMemoryUsage(length);
      }
      _free(address);
    }
    address = 0;
    length = 0;
  }

  @fletch.native external void _decreaseMemoryUsage(int length);
  @fletch.native external static void _free(int address);
}

// NOTE We could make this a view on a memory object instead.
class Struct extends ForeignMemory {
  final wordSize;
  int get numFields => length ~/ wordSize;

  Struct(int fields)
      : this.wordSize = Foreign.machineWordSize,
        super.allocated(fields * Foreign.machineWordSize);

  Struct.finalized(int fields)
      : this.wordSize = Foreign.machineWordSize,
        super.allocatedFinalized(fields * Foreign.machineWordSize);

  Struct.fromAddress(int address, int fields)
      : this.wordSize = Foreign.machineWordSize,
        super.fromAddress(address, fields * Foreign.machineWordSize);

  Struct.withWordSize(int fields, wordSize)
      : this.wordSize = wordSize,
        super.allocated(fields * wordSize);

  Struct.withWordSizeFinalized(int fields, wordSize)
      : this.wordSize = wordSize,
        super.allocatedFinalized(fields * wordSize);

  Struct.fromAddressWithWordSize(int address, int fields, wordSize)
      : this.wordSize = wordSize,
        super.fromAddress(address, fields * wordSize);

  int getWord(int byteOffset) {
    switch (wordSize) {
      case 4:
        return getInt32(byteOffset);
      case 8:
        return getInt64(byteOffset);
      default:
        throw "Unsupported machine word size.";
    }
  }

  int setWord(int byteOffset, int value) {
    switch (wordSize) {
      case 4:
        return setInt32(byteOffset, value);
      case 8:
        return setInt64(byteOffset, value);
      default:
        throw "Unsupported machine word size.";
    }
  }

  int getField(int fieldOffset) => getWord(fieldOffset * wordSize);

  void setField(int fieldOffset, int value) {
    setWord(fieldOffset * wordSize, value);
  }
}

class Struct32 extends Struct {
  Struct32(int fields) : super.withWordSize(fields, 4);
  Struct32.finalized(int fields) : super.withWordSizeFinalized(fields, 4);
  Struct32.fromAddress(int address, int fields)
      : super.fromAddressWithWordSize(address, fields, 4);
}

class Struct64 extends Struct {
  Struct64(int fields) : super.withWordSize(fields, 8);
  Struct64.finalized(int fields) : super.withWordSizeFinalized(fields, 8);
  Struct64.fromAddress(int address, int fields)
      : super.fromAddressWithWordSize(address, fields, 8);
}

class ForeignCString extends ForeignMemory {
  static final ForeignFunction _strlen = ForeignLibrary.main.lookup('strlen');

  factory ForeignCString.fromForeignPointer(ForeignPointer ptr) {
    int length = _strlen.icall$1(ptr);
    return new ForeignCString._(ptr, length + 1);
  }

  ForeignCString._(Foreign ptr, int length)
      : super.fromAddress(ptr.address, length);

  String toString() {
    // Don't include the '\0' character in the encoded string.
    var encodedString = new List(length - 1);
    for (int i = 0; i < length - 1; ++i) {
      encodedString[i] = getUint8(i);
    }
    return UTF8.decode(encodedString);
 }
}
