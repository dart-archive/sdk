// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// API for LPS25H "MEMS pressure sensor: 260-1260 hPa absolute digital output
/// barometer" chip using the I2C bus.
///
/// Currently this has only been tested with a Raspberry Pi 2 and the Sense HAT.
library lps25h;

import 'dart:typed_data';

import 'package:i2c/i2c.dart';

/// Output rates for the chip.
enum OutputRate {
  /// Only one shot.
  oneShot,
  /// Output with 1 Hz rate.
  oneHz,
  /// Output with 7 Hz rate.
  sevenHz,
  /// Output with 12.5 Hz rate.
  twelwePointFiveHz,
  /// Output with 25 Hz rate.
  twentyFiveHz,
}

class LPS25H {
  // Registers.
  static const _refPXL = 0x08;
  static const _refPL = 0x09;
  static const _refPH = 0x0a;
  static const _whoAmI = 0x0f;
  static const _ctrlReg1 = 0x20;
  static const _ctrlReg2 = 0x21;
  static const _ctrlReg3 = 0x22;
  static const _ctrlReg4 = 0x23;

  static const _pressOutXL = 0x28;
  static const _pressOutL = 0x29;
  static const _pressOutH = 0x2a;
  static const _tempOutL = 0x2b;
  static const _tempOutH = 0x2c;


  final I2CDevice _device;

  LPS25H(this._device) {
    // Read the reference preasure.
    int refP = _signed24(
        _device.readByte(_refPH), _device.readByte(_refPL),
        _device.readByte(_refPXL));
  }

  /// Power on the chip with the convertion rate of [rate].
  void powerOn({OutputRate rate: OutputRate.oneHz}) {
    const powerOn = 0x80; // Power-on bit.
    const bdu = 0x04; // Block data update bit.
    const ctrlReg1Values = const {
      OutputRate.oneShot: powerOn,
      OutputRate.oneHz: powerOn | 0x01 << 4 | bdu,
      OutputRate.sevenHz: powerOn | 0x02 << 4 | bdu,
      OutputRate.twelwePointFiveHz: powerOn | 0x03 << 4 | bdu,
      OutputRate.twentyFiveHz: powerOn | 0x04 << 4 | bdu,
    };
    _device.writeByte(_ctrlReg1, ctrlReg1Values[rate]);
  }

  /// Power off the chip.
  void powerOff() {
    _device.writeByte(_ctrlReg1, 0x00);
  }


  /// Read the current preasure value.
  double readPressure() {
    return _signed24(
        _device.readByte(_pressOutH), _device.readByte(_pressOutL),
        _device.readByte(_pressOutXL)) / 4096;
  }

  /// Read the current temperature value.
  double readTemperature() {
    return 42.5 + _signed16(
        _device.readByte(_tempOutH), _device.readByte(_tempOutL)) / 480;
  }

  int _signed16(int msb, int lsb) {
    var x = msb << 8 | lsb;
    return x < 0x7fff ? x : x - 0x10000;
  }

  int _signed24(int msb, int mb, int lsb) {
    var x = msb << 16 | mb << 8 | lsb;
    return x < 0x7fffff ? x : x - 0x1000000;
  }
}

