// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.ts;

import 'dart:dartino.ffi';

final _tsGetState = ForeignLibrary.main.lookup('ts_getState');
final _tsInit = ForeignLibrary.main.lookup('ts_init');

class TouchScreen {
  factory TouchScreen.init(int width, int height) {
    int result = _tsInit.icall$2(width, height);
    if (result != 0 /* TS_OK */) {
      throw new StateError("Failed to initialize touch screen: $result");
    }
    return new TouchScreen._();
  }
  TouchScreen._() {}

  /// Return the touch points detected at the current time.
  TouchState get state {
    ForeignMemory m;

    /// Copy 2 byte ints into an array and return the array.
    /// [byteOffset] is the offset of the list in the memory structure.
    /// [intCount] is the number of 2 byte ints to be copied into the list.
    List<int> getInt16List(int byteOffset, int intCount) {
      List<int> result = [];
      for (int index = 0; index < intCount; ++index) {
        result.add(m.getInt16(byteOffset));
        byteOffset += 2;
      }
      return result;
    }

    // Allocate TS_StateTypeDef struct
    // see sdk/third_party/stm/stm32cube_fw_f7/
    //       Drivers/BSP/STM32746G-Discovery/stm32746g_discovery_ts.h

    // FT5336 : maximum 5 touches detected simultaneously
    const int maxTouchCount = 5;

    // There has got to be a better way to do this.
    // I'd really like to define a c-struct in Dart space,
    // have Dartino automatically self align the fields,
    // and pass a pointer to that into _tsGetState
    // to reduce complexity and copying in user level code
    // when performing low level interop.

    // start = byte offset from beginning of struct
    // size = # of bytes in the field
    const int xStart = 2; // self-aligned 16-bit int
    const int xSize = maxTouchCount * 2;
    const int yStart = xStart + xSize;
    const int ySize = maxTouchCount * 2;
    const int weightOffset = yStart + ySize;
    const int weightSize = maxTouchCount * 1;
    const int eventIdOffset = weightOffset + weightSize;
    const int eventSize = maxTouchCount * 1;
    const int areaOffset = eventIdOffset + eventSize;
    const int areaSize = maxTouchCount * 1;
    // 32 byte int is self-aligned to address divisible by 4
    const int gestureOffset = (areaOffset + areaSize + 3) ~/ 4 * 4;
    const int gestureSize = 4;
    const int mSize = gestureOffset + gestureSize;

    m = new ForeignMemory.allocated(mSize);
    try {
      _tsGetState.icall$1(m);
      int touchCount = m.getInt8(0);
      List<int> x = getInt16List(xStart, touchCount);
      List<int> y = getInt16List(yStart, touchCount);
    } finally {
      m.free();
    }

    return new TouchState(touchCount, x, y);
  }
}

/// [TouchState] represents the current set of touch points at a given moment.
class TouchState {
  /// The number of touch points detected.
  final int count;

  /// An array of [count] touch point x coordinates
  final List<int> x;

  /// An array of [count] touch point y coordinates
  final List<int> y;

  TouchState(this.count, this.x, this.y);
}
