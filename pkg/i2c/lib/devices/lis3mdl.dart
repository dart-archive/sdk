// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// API for LIS3MDL "Digital output magnetic sensor: ultra-low-power,
/// high-performance 3-axis magnetometer" chip using the I2C bus.
///
/// The following sample code shows how to access the LIS3MDL on a
/// STM32F746G Discovery board with "MEMS and environmental sensor
/// expansion board for STM32 Nucleo" (X-NUCLEO-IKS01A1) attached.
///
/// ```
/// import 'package:i2c/i2c.dart';
/// import 'package:i2c/devices/lis3mdl.dart';
/// import 'package:stm32/stm32f746g_disco.dart';
///
/// main() {
///   STM32F746GDiscovery board = new STM32F746GDiscovery();
///   var i2c1 = board.i2c1;
///
///   // The LIS3MDL sensor has address 0x1e in the X-NUCLEO-IKS01A1.
///   var lis3mdl = new LIS3MDL(new I2CDevice(0x1e, i2c1));
///   lis3mdl.powerOn();
///   while (true) {
///     print('${lis3mdl.readMagnet()}');
///     sleep(10);
///   }
/// }
/// ```
///
/// For the datasheet for the LIS3MDL see:
/// http://www.st.com/web/en/resource/technical/document/datasheet/DM00075867.pdf
library lis3mdl;

import 'dart:math' as Math;

import 'package:i2c/i2c.dart';

/// Rate of output from the magnetometer.
enum MagnetOutputRate {
  // Order is important as enum index is used as bit pattern.
  at_0_625Hz,
  at_1_25Hz,
  at_2_5Hz,
  at_5Hz,
  at_10Hz,
  at_20Hz,
  at_80Hz
}

/// Scale for the magnetometer.
enum MagnetScale {
  // Order is important as enum index is used as bit pattern.
  at_4G,
  at_8G,
  at_12G,
  at_16G
}

/// Mode for the magnetometer.
enum MagnetMode {
  // Order is important as enum index is used as bit pattern.
  lowPower,
  mediumPerformance,
  highPerformance,
  ultraHighPerformance,
}

class Measurement {
  final double x;
  final double y;
  final double z;
  Measurement(this.x, this.y, this.z);
  toString() => 'Measurement x: $x, y: $y, z: $z';
}

/// Magnetometer measurement.
///
/// Values are in G (gauss).
class MagnetMeasurement extends Measurement {
  MagnetMeasurement(double x, double y, double z) : super(x, y, z);
  toString() => 'Magnet x: $x G, y: $y G, z: $z G';
}

/// Magnetometer.
class LIS3MDL {
  // Magnetometer Registers.
  static const _offsetXRegLM = 0x05; // OFFSET_X_REG_L_M
  static const _offsetXRegHM = 0x06; // OFFSET_X_REG_H_M
  static const _offsetYRegLM = 0x07; // OFFSET_Y_REG_L_M
  static const _offsetYRegHM = 0x08; // OFFSET_Y_REG_H_M
  static const _offsetZRegLM = 0x09; // OFFSET_Z_REG_L_M
  static const _offsetZRegHM = 0x0A; // OFFSET_Z_REG_H_M
  static const _whoAmIM = 0x0F; // WHO_AM_I_M
  static const _ctrlReg1M = 0x20; // CTRL_REG1_M
  static const _ctrlReg2M = 0x21; // CTRL_REG2_M
  static const _ctrlReg3M = 0x22; // CTRL_REG3_M
  static const _ctrlReg4M = 0x23; // CTRL_REG4_M
  static const _ctrlReg5M = 0x24; // CTRL_REG5_M
  static const _statusRegM = 0x27; // STATUS_REG_M
  static const _outXLM = 0x28; // OUT_X_L_M
  static const _outXHM = 0x29; // OUT_X_H_M
  static const _outYLM = 0x2A; // OUT_Y_L_M
  static const _outYHM = 0x2B; // OUT_Y_H_M
  static const _outZLM = 0x2C; // OUT_Z_L_M
  static const _outZHM = 0x2D; // OUT_Z_H_M
  static const _intCfgM = 0x30; // INT_CFG_M
  static const _intSrcM = 0x31; // INT_SRC_M
  static const _intThsLM = 0x32; // INT_THS_L_M
  static const _intThsHM = 0x33; // INT_THS_H_M

  final I2CDevice _device;  // I2C device for magnetometer.

  var _magnetRate = MagnetOutputRate.at_10Hz;
  var _magnetScale = MagnetScale.at_4G;
  var _magnetMode = MagnetMode.highPerformance;

  static const _magnetRes = const {
    MagnetScale.at_4G: 4.0/32768.0,
    MagnetScale.at_8G: 8.0/32768.0,
    MagnetScale.at_12G: 12.0/32768.0,
    MagnetScale.at_16G: 16.0/32768.0,
  };

  /// The argument is the I2C device for the magnetometer.
  LIS3MDL(this._device);

  void _configureMagnet() {
    var temperatureCompensation = 0x80;
    // Set X- and Y-axis mode and rate, and enable temperature compensation.
    _device.writeByte(
        _ctrlReg1M,
        temperatureCompensation |
        _magnetMode.index << 5 | _magnetRate.index << 2);

    // Set the scale.
    _device.writeByte(_ctrlReg2M, _magnetScale.index << 5);

    // Select continuous conversion mode
    _device.writeByte(_ctrlReg3M, 0x00);

    // Set Z-axis mode and little endian.
    _device.writeByte(_ctrlReg4M, _magnetMode.index << 2);
  }

  void powerOn() {
    _configureMagnet();
    // Enable block data update.
    _device.writeByte(_ctrlReg5M, 0x40);
  }

  /// Returns `true` if new a magnetometer measurement is ready.
  ///
  /// This will query the status register in the chip.
  bool hasMagnetMeasurement() {
    var status = _device.readByte(_statusRegM);
    // Magnetometer provide a separate bit for new data on each axis.
    return (status & 0x07) != 0x00;
  }

  /// Read the current magnetometer measurement.
  MagnetMeasurement readMagnet() {
    var x = _readSigned16(_outXHM, _outXLM);
    var y = _readSigned16(_outYHM, _outYLM);
    var z = _readSigned16(_outZHM, _outZLM);
    var res = _magnetRes[_magnetScale];
    return new MagnetMeasurement(x * res, y * res, z * res);
  }

  int _readSigned16(int msbRegister, int lsbRegister) {
    // Always read LSB before MSB.
    var lsb = _device.readByte(lsbRegister);
    var msb = _device.readByte(msbRegister);
    var x = msb << 8 | lsb;
    return x < 0x7fff ? x : x - 0x10000;
  }
}
