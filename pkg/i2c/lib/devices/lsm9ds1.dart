// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// API for LSM9DS1 "iNEMO inertial module: 3D accelerometer, 3D gyroscope,
/// 3D magnetometer" chip using the I2C bus.
///
/// Currently this has only been tested with a Raspberry Pi 2 and the Sense HAT.
///
/// The following sample code shows how to access the LSM9DS1 on a
/// Raspberry Pi 2 Sense HAT.
///
/// ```
/// import 'package:i2c/i2c.dart';
/// import 'package:i2c/devices/lsm9ds1.dart';
///
/// main() {
///   const i2CBusNumber = 1;  // Raspberry Pi 2 use I2C bus number 1.
///   var busAddress = new I2CBusAddress(i2CBusNumber);
///   var b = busAddress.open();
///   // The LSM9DS1 sensor has addresses 0x6a and 0x1c on the Sense HAT.
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
import 'package:i2c/devices/lsm6ds0.dart';
import 'package:i2c/devices/lis3mdl.dart';

export 'package:i2c/devices/lsm6ds0.dart' show
    GyroOutputRate, GyroScale, GyroBandwidth, AccelOutputRate, AccelScale,
    AccelBandwidth, AccelMeasurement, GyroMeasurement;
export 'package:i2c/devices/lis3mdl.dart' show
    MagnetOutputRate, MagnetScale, MagnetMode, Measurement, MagnetMeasurement;

/// Accelerometer, gyroscope and magnetometer.
class LSM9DS1 {
  // The LSM9DS1 consist of a accelerometer and gyroscope which is
  // register compatible with LSM6DS0 and a magnetometer which is
  // register compatible with LIS3MDL.
  LSM6DS0 _lsm6ds0;
  LIS3MDL _lis3mdl;

  /// The two arguments are the I2C device for the accelerometer and
  /// gyroscope and the I2C device for the magnetometer. If either of
  /// these are `null` that part of the chip will not be initialized.
  LSM9DS1({I2CDevice accelGyroDevice, I2CDevice magnetDevice}) {
    if (accelGyroDevice != null) {
      _lsm6ds0 = new LSM6DS0(accelGyroDevice);
    }
    if (magnetDevice != null) {
      _lis3mdl = new LIS3MDL(magnetDevice);
    }
  }

  void powerOn() {
    if (_lsm6ds0 != null) {
      _lsm6ds0.powerOn();
    }

    if (_lis3mdl != null) {
      _lis3mdl.powerOn();
    }
  }

  /// Returns `true` if new a gyroscope measurement is ready.
  ///
  /// This will query the status register in the chip.
  bool hasGyroMeasurement() => _lsm6ds0.hasGyroMeasurement();

  /// Returns `true` if new a accelerometer measurement is ready.
  ///
  /// This will query the status register in the chip.
  bool hasAccelMeasurement() => _lsm6ds0.hasAccelMeasurement();

  /// Returns `true` if new a magnetometer measurement is ready.
  ///
  /// This will query the status register in the chip.
  bool hasMagnetMeasurement() => _lis3mdl.hasMagnetMeasurement();

  /// Read the current gyroscope measurement.
  GyroMeasurement readGyro() => _lsm6ds0.readGyro();

  /// Read the current accelerometer measurement.
  AccelMeasurement readAccel() => _lsm6ds0.readAccel();

  /// Read the current magnetometer measurement.
  MagnetMeasurement readMagnet() => _lis3mdl.readMagnet();
}
