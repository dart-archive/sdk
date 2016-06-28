// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// API for HTS221 "capacitive digital sensor for relative humidity and
/// temperature" chip using the I2C bus.
///
/// Currently this has only been tested with a Raspberry Pi 2 and the Sense HAT.
library hts221;

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
}

class HTS221 {
  // HTS221 datasheet:
  // http://www.st.com/st-web-ui/static/active/en/resource/technical/document/datasheet/DM00116291.pdf

  // Registers.
  static const _whoAmI = 0x0f;
  static const _avConf = 0x10;
  static const _ctrlReg1 = 0x20;
  static const _ctrlReg2 = 0x21;
  static const _ctrlReg3 = 0x22;
  static const _statusReg = 0x27;
  static const _humidityOutL = 0x28;
  static const _humidityOutH = 0x29;
  static const _tempOutL = 0x2a;
  static const _tempOutH = 0x2b;
  static const _firstCalibrationCoefficient = 0x30;

  static const _numCalibrationCoefficients = 0x10;

  final I2CDevice _device;

  // Calibaration coefficients.
  double t0; // Value of T0_degC_x8 / 8.0.
  double t1; // Value of T0_degC_x8 / 8.0.
  int t0Out; // Value of T0_OUT
  int t1Out; // Value of T1_OUT

  double h0; // Value of H0_rH_x2 / 2.0.
  double h1; // Value of H1_rH_x2 / 2.0.
  int h0Out; // Value of H0_T0_OUT
  int h1Out; // Value of H1_T0_OUT

  /// Create a HTS221 API on a I2C device.
  HTS221(this._device) {
    // Read the calibration data.
    var cal = new Uint8List(_numCalibrationCoefficients);
    for (int i = 0; i < _numCalibrationCoefficients; i++) {
      var register = _firstCalibrationCoefficient + i;
      cal[i] = _device.readByte(register);
    }

    // Calibration values.
    int signed16(int index) => _signed16(cal[index + 1], cal[index]);
    t0 = (cal[0x02] | (cal[0x05] & 0x03) << 8) / 8.0;
    t1 = (cal[0x03] | (cal[0x05] & 0x0c) << 6) / 8.0;
    t0Out = signed16(0x0c);
    t1Out = signed16(0x0e);
    h0 = cal[0x00] / 2.0;
    h1 = cal[0x01] / 2.0;
    h0Out = signed16(0x06);
    h1Out = signed16(0x0a);
  }

  /// Power on the chip with the convertion rate of [rate].
  void powerOn({OutputRate rate: OutputRate.oneHz}) {
    const powerOn = 0x80; // Power-on bit.
    const bdu = 0x04; // Block data update bit.
    const ctrlReg1Values = const {
      OutputRate.oneShot: powerOn,
      OutputRate.oneHz: powerOn | bdu | 0x01,
      OutputRate.sevenHz: powerOn | bdu | 0x02,
      OutputRate.twelwePointFiveHz: powerOn | bdu | 0x03,
    };
    _device.writeByte(_ctrlReg1, ctrlReg1Values[rate]);
  }

  /// Power off the chip.
  void powerOff() {
    _device.writeByte(_ctrlReg1, 0x00);
  }

  /// Read the current temperature value.
  double readTemperature() {
    var t_out = _readSigned16(_tempOutH, _tempOutL);
    // Interpolate using the calibration values.
    return t0 + (t_out - t0Out) * (t1 - t0) / (t1Out - t0Out);
  }

  /// Read the current humidity value.
  double readHumidity() {
    var h_out = _signed16(
        _device.readByte(_humidityOutH), _device.readByte(_humidityOutL));
    // Interpolate using the calibration values.
    return h0 + (h_out - h0Out) * (h1 - h0) / (h1Out - h0Out);
  }

  /// Perform a one-shot conversion. After calling this call [readTemperature]
  /// and [readHumidity] to get the values.
  void oneShotRead() {
    _device.writeByte(_ctrlReg2, 0x01);
    // Wait for result.
    while (true) {
      var status = _device.readByte(_statusReg);
      if ((status & 0x03) == 0x03) break;
    }
  }

  int _readSigned16(int msbRegister, int lsbRegister) {
    // Always read LSB before MSB.
    var lsb = _device.readByte(lsbRegister);
    var msb = _device.readByte(msbRegister);
    var x = msb << 8 | lsb;
    return x < 0x7fff ? x : x - 0x10000;
  }

  int _signed16(int msb, int lsb) {
    var x = msb << 8 | lsb;
    return x < 0x7fff ? x : x - 0x10000;
  }
}
