// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// The dart:fletch.ffi library is a low-level 'foreign function interface'
// library that allows Dart code to call arbitrary native platform
// code defined outside the VM.
library dart.fletch.ffi;

import 'dart:_fletch_system' as fletch;
import 'dart:fletch';

class Foreign {
  int _value;

  Foreign._(this._value);

  static const int UNKNOWN = 0;

  static const int LINUX   = 1;
  static const int MACOS   = 2;
  static const int ANDROID = 3;

  static const int IA32    = 1;
  static const int X64     = 2;
  static const int ARM     = 3;

  // TODO(kasperl): Not quite sure where this fits in.
  static final int bitsPerMachineWord = _bitsPerMachineWord();
  static final int platform = _platform();
  static final int architecture = _architecture();

  static int get errno => _errno();

  // Helper for converting the argument to a machine word.
  int _convert(argument) {
    if (argument is Foreign) return argument._value;
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
  int get address => _value;

  ForeignFunction.fromAddress(int value) : super._(value);

  // Support for calling foreign functions that return
  // integers.
  int icall$0() => _icall$0(_value);
  int icall$1(a0) => _icall$1(_value, _convert(a0));
  int icall$2(a0, a1) => _icall$2(_value, _convert(a0), _convert(a1));
  int icall$3(a0, a1, a2) {
    return _icall$3(_value, _convert(a0), _convert(a1), _convert(a2));
  }
  int icall$4(a0, a1, a2, a3) {
    return _icall$4(_value, _convert(a0), _convert(a1), _convert(a2),
                    _convert(a3));
  }
  int icall$5(a0, a1, a2, a3, a4) {
    return _icall$5(_value, _convert(a0), _convert(a1), _convert(a2),
                    _convert(a3), _convert(a4));
  }
  int icall$6(a0, a1, a2, a3, a4, a5) {
    return _icall$6(_value, _convert(a0), _convert(a1), _convert(a2),
                    _convert(a3), _convert(a4), _convert(a5));
  }

  // Support for calling foreign functions that return
  // machine words -- typically pointers -- encapulated in
  // the given foreign object arguments.
  ForeignPointer pcall$0(ForeignPointer p) {
    p._value = _pcall$0(_value);
    return p;
  }
  ForeignPointer pcall$1(ForeignPointer p, a0) {
    p._value = _pcall$1(_value, a0);
    return p;
  }
  ForeignPointer pcall$2(ForeignPointer p, a0, a1) {
    p._value = _pcall$2(_value, _convert(a0), _convert(a1));
    return p;
  }
  ForeignPointer pcall$3(ForeignPointer p, a0, a1, a2) {
    p._value = _pcall$3(_value, _convert(a0), _convert(a1), _convert(a2));
    return p;
  }
  ForeignPointer pcall$4(ForeignPointer p, a0, a1, a2, a3) {
    p._value = _pcall$4(_value, _convert(a0), _convert(a1), _convert(a2),
                        _convert(a3));
    return p;
  }
  ForeignPointer pcall$5(ForeignPointer p, a0, a1, a2, a3, a4) {
    p._value = _pcall$5(_value, _convert(a0), _convert(a1), _convert(a2),
                        _convert(a3), _convert(a4));
    return p;
  }
  ForeignPointer pcall$6(ForeignPointer p, a0, a1, a2, a3, a4, a5) {
    p._value = _pcall$6(_value, _convert(a0), _convert(a1), _convert(a2),
                        _convert(a3), _convert(a4), _convert(a5));
    return p;
  }

  // Support for calling foreign functions with no return value.
  void vcall$0() {
    _vcall$0(_value);
  }
  void vcall$1(a0) {
    _vcall$1(_value, _convert(a0));
  }
  void vcall$2(a0, a1) {
    _vcall$2(_value, _convert(a0), _convert(a1));
  }
  void vcall$3(a0, a1, a2) {
    _vcall$3(_value, _convert(a0), _convert(a1), _convert(a2));
  }
  void vcall$4(a0, a1, a2, a3) {
    _vcall$4(_value, _convert(a0), _convert(a1), _convert(a2),_convert(a3));
  }
  void vcall$5(a0, a1, a2, a3, a4) {
    _vcall$5(_value, _convert(a0), _convert(a1), _convert(a2), _convert(a3),
             _convert(a4));
  }
  void vcall$6(a0, a1, a2, a3, a4, a5) {
    _vcall$6(_value, _convert(a0), _convert(a1), _convert(a2), _convert(a3),
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
    return _Lcall$wLw(_value,
                      _convert(a0),
                      _convert(a1),
                      _convert(a2));
  }

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
  int get address => _value;
  ForeignPointer.fromAddress(int address) : super._(address);
  ForeignPointer() : super._(0);

  static final ForeignPointer NULL = new ForeignPointer();

}

class ForeignLibrary extends ForeignPointer {
  /// The ForeignLibrary main is used for looking up functions in the libraries
  /// linked in to the main Fletch binary.
  static ForeignLibrary main = new ForeignLibrary.fromName(null);

  ForeignLibrary.fromAddress(int address) : super.fromAddress(address);

  factory ForeignLibrary.fromName(String name) {
    return new ForeignLibrary.fromAddress(_lookupLibrary(name));
  }

  ForeignFunction lookup(String name) {
    return new ForeignFunction.fromAddress(_lookupFunction(_value, name));
  }

  /// Provides a platform specific location for a library relative to the
  /// location of the Fletch vm. Takes the name without lib in front and
  /// returns a platform specific path. Example, on linux, foobar_hash
  /// become PATH_TO_EXECUTABLE/lib/libfoobar_hash.so.
  @fletch.native external static String bundleLibraryName(String libraryName);

  void close() {
    _closeLibrary(_value);
  }

  @fletch.native static int _lookupLibrary(String name) {
    var error = fletch.nativeError;
    throw (error != fletch.indexOutOfBounds) ? error : new ArgumentError();
  }

  @fletch.native static int _lookupFunction(int _value, String name) {
    var error = fletch.nativeError;
    throw (error != fletch.indexOutOfBounds) ? error : new ArgumentError();
  }

  @fletch.native static int _closeLibrary(int _value) {
    var error = fletch.nativeError;
    throw (error != fletch.indexOutOfBounds) ? error : new ArgumentError();
  }
}

class ForeignMemory extends ForeignPointer {
  int _length;
  bool _markedForFinalization;

  int get length => _length;

  ForeignMemory.fromAddress(int address, this._length) :
      _markedForFinalization = false,
      super.fromAddress(address);

  ForeignMemory.fromForeignPointer(ForeignPointer pointer, this._length) :
      _markedForFinalization = false,
      super.fromAddress(pointer.address);

  ForeignMemory.allocated(this._length) {
    _value = _allocate(_length);
    _markedForFinalization = false;
  }

  ForeignMemory.allocatedFinalize(this._length) {
    _value = _allocate(_length);
    _markForFinalization();
    _markedForFinalization = true;
  }

  factory ForeignMemory.fromString(String str) {
    var memory = new ForeignMemory.allocated(str.length + 1);
    for (int i = 0; i < str.length; i++) {
      memory.setUint8(i, str.codeUnitAt(i));
    }
    return memory;
  }

  void setFinalize() {
    if (_markedForFinalization) return;
    _markForFinalization();
    _markedForFinalization = true;
  }

  int getInt8(int offset)
      => _getInt8(_computeAddress(offset, 1));
  int getInt16(int offset)
      => _getInt16(_computeAddress(offset, 2));
  int getInt32(int offset)
      => _getInt32(_computeAddress(offset, 4));
  int getInt64(int offset)
      => _getInt64(_computeAddress(offset, 8));

  int setInt8(int offset, int value)
      => _setInt8(_computeAddress(offset, 1), value);
  int setInt16(int offset, int value)
      => _setInt16(_computeAddress(offset, 2), value);
  int setInt32(int offset, int value)
      => _setInt32(_computeAddress(offset, 4), value);
  int setInt64(int offset, int value)
      => _setInt64(_computeAddress(offset, 8), value);

  int getUint8(int offset)
      => _getUint8(_computeAddress(offset, 1));
  int getUint16(int offset)
      => _getUint16(_computeAddress(offset, 2));
  int getUint32(int offset)
      => _getUint32(_computeAddress(offset, 4));
  int getUint64(int offset)
      => _getUint64(_computeAddress(offset, 8));

  int setUint8(int offset, int value)
      => _setUint8(_computeAddress(offset, 1), value);
  int setUint16(int offset, int value)
      => _setUint16(_computeAddress(offset, 2), value);
  int setUint32(int offset, int value)
      => _setUint32(_computeAddress(offset, 4), value);
  int setUint64(int offset, int value)
      => _setUint64(_computeAddress(offset, 8), value);

  double getFloat32(int offset)
      => _getFloat32(_computeAddress(offset, 4));
  double getFloat64(int offset)
      => _getFloat64(_computeAddress(offset, 8));

  double setFloat32(int offset, double value)
      => _setFloat32(_computeAddress(offset, 4), value);
  double setFloat64(int offset, double value)
      => _setFloat64(_computeAddress(offset, 8), value);

  // Helper for checking bounds and computing derived
  // addresses for memory address functionality.
  int _computeAddress(int offset, int n) {
    if (offset < 0 || offset + n > _length) throw new IndexError(offset, this);
    return _value + offset;
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

  void free() {
    if (_length > 0) _free(_value);
    _value = 0;
    _length = 0;
  }

  @fletch.native external static int _allocate(int length);
  @fletch.native external static void _free(int address);
  @fletch.native external void _markForFinalization();

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
