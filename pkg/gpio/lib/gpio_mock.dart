// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.


/// Mock implementation of the GPIO interface.
library gpio_mock;

import 'package:gpio/gpio.dart';

/// Concrete pins on a mock GPIO interface.
class MockGpioPin implements Pin {
  final int pin;

  const MockGpioPin(this.pin);
  String get name => 'Mock GPIO pin $pin';
  String toString() => name;
}

/// Mock pin configured for GPIO output.
class _MockGpioOutputPin extends GpioOutputPin {
  MockGpio _gpio;
  final MockGpioPin pin;

  _MockGpioOutputPin(this._gpio, this.pin);

  bool get state => _gpio._getState(pin);

  void set state(bool newState) {
    _gpio._setState(pin, newState);
  }
}

/// Mock pin configured for GPIO input.
class _MockGpioInputPin extends GpioInputPin {
  MockGpio _gpio;
  final MockGpioPin pin;

  _MockGpioInputPin(this._gpio, this.pin);

  bool get state => _gpio._getState(pin);

  bool waitFor(bool value, int timeout) {
    throw new UnsupportedError('waitFor not supported for Mock GPIO');
  }
}

/// Mock implementation of the GPIO interface.
class MockGpio implements Gpio {
  /// The default number of pins for GPIO is 50.
  static const int defaultPins = 50;

  /// The number of supported pins.
  final int pins;

  Function _setPinCallback;
  Function _getPinCallback;

  List<bool> _pinValues;

  MockGpio({this.pins: defaultPins}) {
    _pinValues = new List.filled(pins, false);
  }

  /// The simulated values of the pins.
  ///
  /// The default ´getPin´ will return the value in this `List`. The default
  /// ´setPin´ will update it. Initially all values are ´false´.
  List<bool> get pinValues => _pinValues;

  /// Initialize a GPIO pin for output.
  GpioOutputPin initOutput(Pin pin) {
    return new _MockGpioOutputPin(this, _checkPinArgument(pin));
  }

  /// Initialize a GPIO pin for input.
  GpioInputPin initInput(
      Pin pin, {GpioPullUpDown pullUpDown, GpioInterruptTrigger trigger}) {
    return new _MockGpioInputPin(this, _checkPinArgument(pin));
  }

  void _setState(MockGpioPin pin, bool value) {
    if (_setPinCallback == null) {
      _pinValues[pin.pin] = value;
      print('Writing pin $pin value $value');
    } else {
      _setPinCallback(pin, value);
    }
  }

  bool _getState(MockGpioPin pin) {
    if (_getPinCallback == null) {
      bool value = _pinValues[pin.pin];
      print('Reading pin $pin value $value');
      return value;
    } else {
      return _getPinCallback(pin);
    }
  }

  MockGpioPin _checkPinArgument(Pin pin) {
    if (pin is! MockGpioPin) {
      throw new ArgumentError('Illegal pin type');
    }
    MockGpioPin p = pin;
    if (p.pin < 0 || pins <= p.pin) {
      throw new RangeError.index(p.pin, this, 'pin', null, pins);
    }
    return p;
  }

  /// Register ´callback´ to be called for ´setPin´.
  void registerSetPin(void callback(MockGpioPin pin, bool value)) {
    _setPinCallback = callback;
  }

  /// Register ´callback´ to be called for ´getPin´.
  void registerGetPin(bool callback(MockGpioPin pin)) {
    _getPinCallback = callback;
  }
}
