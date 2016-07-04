// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Support library for accessing the sensors on a X-NUCLEO-IKS01A1
/// expansion board.
///
/// Pass an instance of a `I2CBus` the board is connected to. The
/// following example uses a STM32F764G Discovery board where the I2C
/// bus on Arduino connector is I2C bus `1`, available as `i2c1`.
///
/// Usage with STM32F746G Discovery board
/// -------------------------------------
/// ```dart
/// import 'package:stm32/stm32f746g_disco.dart';
/// import 'package:nucleo_iks01a1/nucleo_iks01a1.dart';
///
/// main() {
///   print('Reading sensors on a X-NUCLEO-IKS01A1 expansion board');
///   STM32F746GDiscovery disco = new STM32F746GDiscovery();
///   NucleoIKS01A1 sensors = new NucleoIKS01A1(disco.i2c1);
///
///   var hts221 = sensors.hts221;
///   hts221.powerOn();
///   print('Temperature: ${hts221.readTemperature()}');
/// }
/// ```
///
/// The library also contains the default I2C addresses of the sensors
/// on the expansion board.
library nucleo_iks01a1;

import 'package:i2c/i2c.dart';
import 'package:i2c/devices/hts221.dart';
import 'package:i2c/devices/lps25h.dart';
import 'package:i2c/devices/lsm6ds0.dart';
import 'package:i2c/devices/lis3mdl.dart';

export 'package:i2c/devices/hts221.dart' show HTS221;
export 'package:i2c/devices/lps25h.dart' show LPS25H;
export 'package:i2c/devices/lsm6ds0.dart' show
    LSM6DS0, AccelMeasurement, GyroMeasurement;
export 'package:i2c/devices/lis3mdl.dart' show
    LIS3MDL, Measurement, MagnetMeasurement;

class NucleoIKS01A1 {
  /// I2C address of the HTS221 sensor.
  static const int hts221Address = 0x5f;
  /// I2C address of the LPS25H sensor.
  static const int lps25hAddress = 0x5d;
  /// I2C address of the  sensor.
  static const int lsm6ds0Address = 0x6b;
  /// I2C address of the  sensor.
  static const int lis3mdlAddress = 0x1e;

  final I2CBus i2c;
  HTS221 _hts221;
  LPS25H _lps25h;
  LSM6DS0 _lsm6ds0;
  LIS3MDL _lis3mdl;

  /// Create an instance for communicating with the X-NUCLEO-IKS01A1
  /// board connected to I2C bus passed as argument.
  NucleoIKS01A1(this.i2c);

  /// Access the HTS221 "capacitive digital sensor for relative humidity and
  /// temperature" on the expansion board.
  HTS221 get hts221 {
    if (_hts221 == null) {
      _hts221 = new HTS221(new I2CDevice(hts221Address, i2c));
    }
    return _hts221;
  }

  /// Access the LPS25HB "MEMS pressure sensor: 260-1260 hPa absolute
  /// digital output barometer" on the expansion board.
  LPS25H get lps25h {
    if (_lps25h == null) {
      _lps25h = new LPS25H(new I2CDevice(lps25hAddress, i2c));
    }
    return _lps25h;
  }

  /// Access the LSM6DS0 "iNEMO inertial module: 3D accelerometer and
  /// 3D gyroscope" on the expansion board.
  LSM6DS0 get lsm6ds0 {
    if (_lsm6ds0 == null) {
      _lsm6ds0 = new LSM6DS0(new I2CDevice(lsm6ds0Address, i2c));
    }
    return _lsm6ds0;
  }

  /// Access the LIS3MDL "Digital output magnetic sensor:
  /// ultra-low-power, high-performance 3-axis magnetometer" on the
  /// expansion board.
  LIS3MDL get lis3mdl {
    if (_lis3mdl == null) {
      _lis3mdl = new LIS3MDL(new I2CDevice(lis3mdlAddress, i2c));
    }
    return _lis3mdl;
  }
}
