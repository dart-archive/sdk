// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.


/// Mock implementation of the GPIO interface.
library gpio_mock;

import 'package:gpio/gpio.dart';

/// Mock implementation of the GPIO interface.
class MockGPIO extends GPIOBase {
  Function _setPin;
  Function _getPin;

  List<bool> _pinValues;

  MockGPIO([int pins = GPIO.defaultPins]) : super(pins) {
    _pinValues = new List.filled(pins, false);
  }

  /// The simulated values of the pins.
  ///
  /// The default ´getPin´ will return the value in this `List`. The default
  /// ´setPin´ will update it. Initially all values are ´false´.
  List<bool> get pinValues => _pinValues;

  void setMode(int pin, Mode mode) {
    checkPinRange(pin);
    print('Setting mode for pin $pin to $mode');
  }

  Mode getMode(int pin) {
    checkPinRange(pin);
    print('Reading mode of pin $pin');
  }

  void setPin(int pin, bool value) {
    checkPinRange(pin);
    if (_setPin == null) {
      _pinValues[pin] = value;
      print('Writing pin $pin value $value');
    } else {
      _setPin(pin, value);
    }
  }

  bool getPin(int pin) {
    checkPinRange(pin);
    if (_getPin == null) {
      bool value = _pinValues[pin];
      print('Reading pin $pin value $value');
      return value;
    } else {
      return _getPin(pin);
    }
  }

  /// Register ´callback´ to be called for ´setPin´.
  void registerSetPin(void callback(int pin, bool value)) {
    _setPin = callback;
  }

  /// Register ´callback´ to be called for ´getPin´.
  void registerGetPin(bool callback(int pin)) {
    _getPin = callback;
  }
}
