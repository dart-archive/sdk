// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';

import 'package:i2c/i2c.dart';

/// MPL3115A2 i2c sensor device
///
/// With thanks to the folks at Sparkfun
/// https://learn.sparkfun.com/tutorials/mpl3115a2-pressure-sensor-hookup-guide
class MPL3115A2 {
  static const int _address = 0x60;

  static const int _statusRegister = 0x00;
  static const int _outPmsbRegister = 0x01;
  static const int _outPcsbRegister = 0x02;
  static const int _outPlsbRegister = 0x03;
  static const int _outTmsbRegister = 0x04;
  static const int _outTlsbRegister = 0x05;
  static const int _ptDataCfgRegister = 0x13;
  static const int _ctrlRegister1 = 0x26;

  final I2CDevice _device;

  MPL3115A2(I2CBus bus) : _device = new I2CDevice(_address, bus);

  /// Initialize the sensor
  void powerOn() {
    // Clear SBYB bit for Standby mode before modifying control registers
    _device.writeByte(_ctrlRegister1, _device.readByte(_ctrlRegister1) & ~1);

    // Update the sensor mode
    int mode = _device.readByte(_ctrlRegister1); //Read current settings
    mode &= ~(1 << 7); // Clear ALT bit for barometer
    mode |= 0x38; // Set oversampling to recommended value
    _device.writeByte(_ctrlRegister1, mode);

    // Enable pressure and temp event flags
    _device.writeByte(_ptDataCfgRegister, 0x07);

    ///Puts the sensor in active mode
    ///This is needed so that we can modify the major control registers
    //Set SBYB bit for Active mode
    _device.writeByte(_ctrlRegister1, _device.readByte(_ctrlRegister1) | 1);
  }

  /// Return the current pressure in Pa
  double get pressure {
    _waitForData(1 << 2); // Status PDR

    // Read pressure registers
    int msb = _device.readByte(_outPmsbRegister);
    int csb = _device.readByte(_outPcsbRegister);
    int lsb = _device.readByte(_outPlsbRegister);

    // Trigger another reading
    _triggerSensor();

    // Pressure is 16 bit + 2 bit fraction
    return (msb << 10 | csb << 2 | lsb >> 6) + ((lsb & 0x30) >> 4) / 4.0;
  }

  /// Return the current temperature in degrees celsius
  double get temperature {
    _waitForData(1 << 1); // Status TDR

    // Read temperature registers
    int msb = _device.readByte(_outTmsbRegister); // OUT_T_MSB
    int lsb = _device.readByte(_outTlsbRegister); // OUT_T_LSB

    // Trigger another reading
    _triggerSensor();

    bool negative = msb >= 0x7F;
    if (negative) {
      // 2s complement
      int temp = ~((msb << 8) + lsb) + 1;
      msb = temp >> 8;
      lsb = temp &= 0x00F0;
    }

    // Temperature is 8 bit + 4 bit fraction
    double temp = msb + (lsb >> 4) / 16.0;
    if (negative) temp = 0 - temp;
    return temp;
  }

  /// Wait for the specified bit to be set indicating data is available.
  /// Throw an exception if waiting longer than 600 ms.
  void _waitForData(int statusFlag) {
    // If no data, then trigger the sensor to take a reading
    if (_device.readByte(_statusRegister) & statusFlag == 0) _triggerSensor();

    // Wait for new data to become available
    int counter = 0;
    while (_device.readByte(_statusRegister) & statusFlag == 0) {
      if (++counter > 600) throw new I2CException('No new data available');
      sleep(1);
    }
  }

  /// Trigger device to take measurements
  void _triggerSensor() {
    int tempSetting = _device.readByte(_ctrlRegister1); //Read current settings
    tempSetting &= ~(1 << 1); //Clear OST bit
    _device.writeByte(_ctrlRegister1, tempSetting & ~(1 << 1));

    tempSetting =
        _device.readByte(_ctrlRegister1); //Read current settings to be safe
    tempSetting |= (1 << 1); //Set OST bit
    _device.writeByte(_ctrlRegister1, tempSetting);
  }
}
