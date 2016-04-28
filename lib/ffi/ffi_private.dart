// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dart.dartino._ffi;

import 'dart:dartino._system' as dartino;
import 'dart:dartino.ffi';
import 'dart:dartino';

typedef _Arity0();
typedef _Arity1(x);
typedef _Arity2(x, y);
typedef _Arity3(x, y, z);

// This class is only used as static container, to provide a way to bind the
// native external methods. This is necessary, because the native-binding
// mechanism requires a class-name when it looks up native functions.
abstract class ForeignConversion {
  // Helper for converting the argument to a machine word or double.
  static dynamic convert(argument) {
    if (argument is int || argument is double) return argument;
    if (argument is Foreign) return argument.address;
    if (argument is Port) return convertPort(argument);
    throw new ArgumentError();
  }

  @dartino.native static int convertPort(Port port) {
    throw new ArgumentError();
  }
}

// This class is only used as static container, to provide a way to bind the
// native external methods. This is necessary, because the native-binding
// mechanism requires a class-name when it looks up native functions.
abstract class ForeignCallback {

  static final List<Function> _ffiCallbacks = <Function>[];

  /// Links the given [dartFunction] with a native wrapper function.
  ///
  /// Returns the address of the native function, or `-1` if all wrappers
  /// (of the given arity) have already been linked.
  static int registerDartCallback(Function dartFunction, errorReturnObject) {
    int arity;
    if (dartFunction is _Arity3) {
      arity = 3;
    } else if (dartFunction is _Arity2) {
      arity = 2;
    } else if (dartFunction is _Arity1) {
      arity = 1;
    } else if (dartFunction is _Arity0) {
      arity = 0;
    } else {
      throw new UnsupportedError("ForeignFunction with arity > 3");
    }

    int callbackId;
    // Linear search to find the first free callback id.
    for (int i = 0; i < _ffiCallbacks.length; i++) {
      if (_ffiCallbacks[i] == null) {
        callbackId = i;
        break;
      }
    }
    if (callbackId == null) {
      callbackId = _ffiCallbacks.length;
      _ffiCallbacks.length++;
    }
    int address = _allocateFunctionPointer(
        arity, callbackId, ForeignConversion.convert(errorReturnObject));
    if (address == -1) {
      throw new ResourceExhaustedException("Native-function wrapper.");
    }
    _ffiCallbacks[callbackId] = dartFunction;
    return address;
  }

  static void freeFunctionPointer(int address) {
    int callbackId = _freeFunctionPointer(address);
    if (callbackId < 0 || _ffiCallbacks[callbackId] == null) {
      throw new StateError(
          "Function not a native wrapper function or already freed.");
    }
    _ffiCallbacks[callbackId] = null;
    // TODO(floitsch): shrink the table?
  }

  /// Executes the FFI callback of the given [ffiId].
  ///
  /// Some of the given arguments may be ignored if the [arity] is less than 3.
  static int doFfiCallback(int ffiId, int arity, arg0, arg1, arg2) {
    var result;
    if (arity == 0) {
      result = _ffiCallbacks[ffiId]();
    } else if (arity == 1) {
      result = _ffiCallbacks[ffiId](arg0);
    } else if (arity == 2) {
      result = _ffiCallbacks[ffiId](arg0, arg1);
    } else if (arity == 3) {
      result = _ffiCallbacks[ffiId](arg0, arg1, arg2);
    }
    return ForeignConversion.convert(result);
  }

  @dartino.native
  static int _allocateFunctionPointer(
      int arity, int callbackId, int errorReturnValue) {
    throw new ArgumentError();
  }

  /// Returns the callbackId of the FFI function with this address.
  @dartino.native static int _freeFunctionPointer(int address) {
    throw new ArgumentError();
  }
}