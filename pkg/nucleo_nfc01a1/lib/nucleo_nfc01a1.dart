// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Support library for accessing the sensors on a X-NUCLEO-NFC01A1
/// expansion board.
///
/// The library also contains the default I2C addresses of the sensors
/// on the expansion board.
library nucleo_nfc01a1;

import 'package:gpio/gpio.dart';
import 'package:i2c/i2c.dart';
import 'package:i2c/devices/m24sr.dart';

export 'package:i2c/devices/m24sr.dart' show M24SR;

class NucleoNFC01A1 {
  /// I2C address of the M24SR chip.
  static const int m24srAddress = 0x56;

  final I2CBus i2c;
  final GpioOutputPin led1;
  final GpioOutputPin led2;
  final GpioOutputPin led3;
  M24SR _m24sr;

  /// Create an instance for communicating with the X-NUCLEO-NFC01A1
  /// board connected to I2C bus passed as argument.
  NucleoNFC01A1(this.i2c, this.led1, this.led2, this.led3);

  /// Access the M24SR "Dynamic NFC/RFID Tag" on the expansion board.
  M24SR get m24sr {
    return _m24sr ??= new M24SR(new I2CDevice(m24srAddress, i2c));
  }
}
