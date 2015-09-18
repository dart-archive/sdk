// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// API for LSM9DS1 "iNEMO inertial module: 3D accelerometer, 3D gyroscope,
/// 3D magnetometer" chip using the I2C bus.
///
/// Currently this has only been tested with a Raspberry Pi 2 and the Sense HAT.
///
/// The following sample code show how to access the LSM9DS1 on a Raspberry Pi 2
/// Sense HAT.
///
/// ```
/// import 'package:i2c/i2c.dart';
/// import 'package:i2c/devices/lsm9ds1.dart';
///
/// main() {
///   const i2CBusNumber = 1;  // Raspberry Pi 2 use I2C bus number 1.
///   var busAddress = new I2CBusAddress(i2CBusNumber);
///   var b = busAddress.open();
///   var lsm9ds1 = new LSM9DS1(new I2CDevice(0x6a, b), new I2CDevice(0x1c, b));
///   lsm9ds1.powerOn();
///   while (true) {
///     if (lsm9ds1.hasAccelMeasurement()) {
///       var accel = lsm9ds1.readAccel();
///       print('pitch: ${accel.pitch}, roll: ${accel.roll}');
///     }
///     if (lsm9ds1.hasGyroMeasurement()) {
///       var gyro = lsm9ds1.readGyro();
///       print(gyro);
///     }
///     if (lsm9ds1.hasMagnetMeasurement()) {
///       var magnet = lsm9ds1.readMagnet();
///       print(magnet);
///     }
///   }
/// }
/// ```
///
/// For the datasheet for the LSM9DS1 see:
/// http://www.st.com/web/en/resource/technical/document/datasheet/DM00103319.pdf
library lsm9ds1;

import 'dart:math' as Math;

import 'package:i2c/i2c.dart';

/// Rates of output from the gyroscope.
enum GyroOutputRate {
  // Order is important as enum index is used as bit pattern.
  powerDown,
  at_14_9Hz,
  at_59_5Hz,
  at_119Hz,
  at_238Hz,
  at_476Hz,
  at_952Hz
}

/// Scales for the gyroscope.
enum GyroScale {
  // Order is important as enum index is used as bit pattern.
  at_245DPS,
  at_500DPS,
  _NoOp, // This bit-pattern is not used.
  at_2000DPS
}

/// Bandwidth for the gyroscope.
enum GyroBandwidth {
  // Order is important as enum index is used as bit pattern.
  low,
  medium,
  high,
  highest
}

/// Rate of output from the accelerometer.
enum AccelOutputRate {
  // Order is important as enum index is used as bit pattern.
  at_PowerDown,
  at_10Hz,
  at_50Hz,
  at_119Hz,
  at_238Hz,
  at_476Hz,
  at_952Hz,
}

/// Scale for the accelerometer.
enum AccelScale {
  // Order is important as enum index is used as bit pattern.
  at_2G,
  at_16G,
  at_4G,
  at_8G,
}

/// Bandwidth for the accelerometer.
enum AccelBandwidth {
  // Order is important as enum index is used as bit pattern.
   at_408Hz,
   at_211Hz,
   at_105Hz,
   at_50Hz,
}

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

/// Accelerometer measurement.
///
/// Values are in g (earth gravitational force, g = 9.80665 m/s2).
class AccelMeasurement extends Measurement {
  AccelMeasurement(double x, double y, double z) : super(x, y, z);

  // See http://cache.freescale.com/files/sensors/doc/app_note/AN3461.pdf for
  // calculating pitch and roll. Here we are using the equations 28 and 29.

  /// The current pitch in degrees.
  double get pitch => _toDegrees(Math.atan(y / Math.sqrt(x * x + z * z)));

  /// The current roll in degrees.
  double get roll => _toDegrees(Math.atan(-x / z));

  _toDegrees(double value) => (value * 180) / Math.PI;

  toString() => 'Acceleration x: $x g, y: $y g, z: $z g';
}

/// Gyroscope measurement.
///
/// Values are in degrees/s (degrees per second).
class GyroMeasurement extends Measurement {
  GyroMeasurement(double x, double y, double z) : super(x, y, z);
  toString() => 'Gyro x: $x g, y: $y g, z: $z g';
}

/// Magnetometer measurement.
///
/// Values are in G (gauss).
class MagnetMeasurement extends Measurement {
  MagnetMeasurement(double x, double y, double z) : super(x, y, z);
  toString() => 'Magnet x: $x G, y: $y G, z: $z G';
}

/// Accelerometer, gyroscope and magnetometer.
class LSM9DS1 {
  // Accelerometer and gyroscope registers.
  static const _actThs = 0x04; // ACT_THS
  static const _actDur = 0x05; // ACT_DUR
  static const _intGenCfgXL = 0x06; // INT_GEN_CFG_XL;
  static const _intGEN_THS_X_XL = 0x07; // INT_GEN_THS_X_XL
  static const _intGEN_THS_Y_XL = 0x08; // INT_GEN_THS_Y_XL
  static const _intGEN_THS_Z_XL = 0x09; // INT_GEN_THS_Z_XL
  static const _intGEN_DUR_XL = 0x0A; // INT_GEN_DUR_XL
  static const _referenceG = 0x0B; // REFERENCE_G
  static const _int1Ctrl = 0x0C; // INT1_CTRL
  static const _int2Ctrl = 0x0D; // INT2_CTRL
  static const _whoAmI = 0x0F; // WHO_AM_I
  static const _ctrlReg1G = 0x10; // CTRL_REG1_G
  static const _ctrlReg2G = 0x11; // CTRL_REG2_G
  static const _ctrlReg3G = 0x12; // CTRL_REG3_G
  static const _orientCfgG = 0x13; // ORIENT_CFG_G
  static const _intGenSrcG = 0x14; // INT_GEN_SRC_G
  static const _outTempL = 0x15; // OUT_TEMP_L
  static const _outTempH = 0x16; // OUT_TEMP_H
  static const _statusReg = 0x17; // STATUS_REG
  static const _outXLG = 0x18; // OUT_X_L_G
  static const _outXHG = 0x19; // OUT_X_H_G
  static const _outYLG = 0x1A; // OUT_Y_L_G
  static const _outYHG = 0x1B; // OUT_Y_H_G
  static const _outZLG = 0x1C; // OUT_Z_L_G
  static const _outZHG = 0x1D; // OUT_Z_H_G
  static const _ctrlReg4 = 0x1E; // CTRL_REG4
  static const _ctrlReg5XL = 0x1F; // CTRL_REG5_XL
  static const _ctrlReg6XL = 0x20; // CTRL_REG6_XL
  static const _ctrlReg7XL = 0x21; // CTRL_REG7_XL
  static const _ctrlReg8 = 0x22; // CTRL_REG8
  static const _ctrlReg9 = 0x23; // CTRL_REG9
  static const _ctrlReg10 = 0x24; // CTRL_REG10
  static const _intGenSrcXL = 0x26; // INT_GEN_SRC_XL
  static const _statusReg2 = 0x27; // STATUS_REG
  static const _outXLXL = 0x28; // OUT_X_L_XL
  static const _outXHXL = 0x29; // OUT_X_H_XL
  static const _outYLXL = 0x2A; // OUT_Y_L_XL
  static const _outYHXL = 0x2B; // OUT_Y_H_XL
  static const _outZLXL = 0x2C; // OUT_Z_L_XL
  static const _outZHXL = 0x2D; // OUT_Z_H_XL
  static const _fifoCtrl = 0x2E; // FIFO_CTRL
  static const _fifoSrc = 0x2F; // FIFO_SRC
  static const _intGenCfgG = 0x30; // INT_GEN_CFG_G
  static const _intGenThsXHG = 0x31; // INT_GEN_THS_XH_G
  static const _intGenThsXLG = 0x32; // INT_GEN_THS_XL_G
  static const _intGenThsYHG = 0x33; // INT_GEN_THS_YH_G
  static const _intGenThsYLG = 0x34; // INT_GEN_THS_YL_G
  static const _intGenThsZHG = 0x35; // INT_GEN_THS_ZH_G
  static const _intGenThsZLG = 0x36; // INT_GEN_THS_ZL_G
  static const _intGenDurG = 0x37; // INT_GEN_DUR_G

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

  final I2CDevice _deviceAG;  // I2C device for Accelerometer and gyroscope.
  final I2CDevice _deviceM;  // I2C device for magnetometer.

  var _gyroRate = GyroOutputRate.at_238Hz;
  var _gyroScale = GyroScale.at_245DPS;
  var _gyroBandwidth = GyroBandwidth.medium;

  var _accelRate = AccelOutputRate.at_238Hz;
  var _accelScale = AccelScale.at_2G;
  var _accelBandwidth = AccelBandwidth.at_50Hz;

  var _magnetRate = MagnetOutputRate.at_10Hz;
  var _magnetScale = MagnetScale.at_4G;
  var _magnetMode = MagnetMode.highPerformance;

  static const _gyroRes = const {
    GyroScale.at_245DPS: 245.0/32768.0,
    GyroScale.at_500DPS: 500.0/32768.0,
    GyroScale.at_2000DPS: 2000.0/32768.0,
  };

  static const _accelRes = const {
    AccelScale.at_2G: 2.0/32768.0,
    AccelScale.at_16G: 16.0/32768.0,
    AccelScale.at_4G: 4.0/32768.0,
    AccelScale.at_8G: 8.0/32768.0,
  };

  static const _magnetRes = const {
    MagnetScale.at_4G: 4.0/32768.0,
    MagnetScale.at_8G: 8.0/32768.0,
    MagnetScale.at_12G: 12.0/32768.0,
    MagnetScale.at_16G: 16.0/32768.0,
  };

  /// The two arguments are the I2C device for the accelerometer and
  /// gyroscope and the I2C device for the magnetometer. If either of
  /// these are `null` that part of the chip will not be initialized.
  LSM9DS1({I2CDevice accelGyroDevice, I2CDevice magnetDevice})
      : _deviceAG = accelGyroDevice, _deviceM = magnetDevice;

  void _configureGyro() {
    // Enable all three axis of the gyroscope.
    _deviceAG.writeByte(_ctrlReg4, 0x07 << 3);

    // Rate, scale and bandwidth.
    _deviceAG.writeByte(
        _ctrlReg1G,
        _gyroRate.index << 5 | _gyroScale.index << 3 | _gyroBandwidth.index);

    // High pass filter
    _deviceAG.writeByte(_ctrlReg3G, 0x00);  // Disable HPF.
  }

  void _configureAccel() {
    // Enable all three axis of the accelerometer.
    _deviceAG.writeByte(_ctrlReg5XL, 0x07 << 3);

    // Rate, scale and bandwidth.
    var bwScalOrd = 1;  // 1 means use _accelBandwidth.
    _deviceAG.writeByte(
        _ctrlReg6XL,
        _accelRate.index << 5 | _accelScale.index << 3 |
        bwScalOrd << 2 | _accelBandwidth.index);

    // No high-resolution mode, no filter.
    _deviceAG.writeByte(_ctrlReg7XL, 0);
  }

  void _configureMagnet() {
    var temperatureCompensation = 0x80;
    // Set X- and Y-axis mode and rate, and enable temperature compensation.
    _deviceM.writeByte(
        _ctrlReg1M,
        temperatureCompensation |
        _magnetMode.index << 5 | _magnetRate.index << 2);

    // Set the scale.
    _deviceM.writeByte(_ctrlReg2M, _magnetScale.index << 5);

    // Select continuous conversion mode
    _deviceM.writeByte(_ctrlReg3M, 0x00);

    // Set Z-axis mode and little endian.
    _deviceM.writeByte(_ctrlReg4M, _magnetMode.index << 2);
  }

  void powerOn() {
    if (_deviceAG != null) {
      _configureGyro();
      _configureAccel();
      // Enable block data update.
      _deviceAG.writeByte(_ctrlReg8, 0x44);
    }

    if (_deviceM != null) {
      _configureMagnet();
      // Enable block data update.
      _deviceAG.writeByte(_ctrlReg5M, 0x40);
    }
  }

  /// Returns `true` if new a gyroscope measurement is ready.
  ///
  /// This will query the status register in the chip.
  bool hasGyroMeasurement() {
    var status = _deviceAG.readByte(_statusReg);
    return (status & 0x02) != 0;
  }

  /// Returns `true` if new a accelerometer measurement is ready.
  ///
  /// This will query the status register in the chip.
  bool hasAccelMeasurement() {
    var status = _deviceAG.readByte(_statusReg);
    return (status & 0x01) != 0;
  }

  /// Returns `true` if new a magnetometer measurement is ready.
  ///
  /// This will query the status register in the chip.
  bool hasMagnetMeasurement() {
    var status = _deviceM.readByte(_statusRegM);
    // Magnetometer provide a separate bit for new data on each axis.
    return (status & 0x07) != 0x00;
  }

  /// Read the current gyroscope measurement.
  GyroMeasurement readGyro() {
    var x = _signed16(_deviceAG.readByte(_outXHG), _deviceAG.readByte(_outXLG));
    var y = _signed16(_deviceAG.readByte(_outYHG), _deviceAG.readByte(_outYLG));
    var z = _signed16(_deviceAG.readByte(_outZHG), _deviceAG.readByte(_outZLG));
    var res = _gyroRes[_gyroScale];
    return new GyroMeasurement(x * res, y * res, z * res);
  }

  /// Read the current accelerometer measurement.
  AccelMeasurement readAccel() {
    var x = _signed16(_deviceAG.readByte(_outXHXL),
                      _deviceAG.readByte(_outXLXL));
    var y = _signed16(_deviceAG.readByte(_outYHXL),
                      _deviceAG.readByte(_outYLXL));
    var z = _signed16(_deviceAG.readByte(_outZHXL),
                      _deviceAG.readByte(_outZLXL));
    var res = _accelRes[_accelScale];
    return new AccelMeasurement(x * res, y * res, z * res);
  }

  /// Read the current magnetometer measurement.
  MagnetMeasurement readMagnet() {
    var x = _signed16(_deviceM.readByte(_outXHM), _deviceM.readByte(_outXLM));
    var y = _signed16(_deviceM.readByte(_outYHM), _deviceM.readByte(_outYLM));
    var z = _signed16(_deviceM.readByte(_outZHM), _deviceM.readByte(_outZLM));
    var res = _magnetRes[_magnetScale];
    return new MagnetMeasurement(x * res, y * res, z * res);
  }
}

int _signed16(int msb, int lsb) {
  var x = msb << 8 | lsb;
  return x < 0x7fff ? x : x - 0x10000;
}
