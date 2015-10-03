// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Library for the basic Raspberry Pi features.
library raspberry_pi;

import 'dart:typed_data';

import 'package:file/file.dart';

/// Possible modes of the on-board LEDs
enum OnboardLEDMode {
  /// The on-board LED is controlled by the system.
  system,
  /// The on-board LED is controlled by the user through GPIO.
  gpio,
  /// The on-board LED is pulsing heart-beat.
  heartbeat,
  /// The on-board LED is in timer state.
  timer,
}

/// Class for accessing Raspberry Pi features.
///
/// Change the activity LED to heartbeat mode:
///
/// ```
/// import 'package:raspberry_pi/raspberry_pi.dart';
///
/// main() {
///   RaspberryPi pi = new RaspberryPi();
///   pi.leds.activityLED.setMode(OnboardLEDMode.heartbeat);
/// }
/// ```
///
/// Change the activity LED to gpio mode to allow it to be used as a
/// normal GPIO pin.
///
/// ```
/// import 'package:raspberry_pi/raspberry_pi.dart';
/// import 'package:gpio/gpio.dart';
///
/// main() {
///   RaspberryPi pi = new RaspberryPi();
///   GPIO gpio = new PiMemoryMappedGPIO();
///   pi.leds.activityLED.setMode(OnboardLEDMode.gpio);
///   gpio.setPin(pi.leds.activityLED.pin, true);
/// }
/// ```
class RaspberryPi {
  /// Provide access to the on-board LEDs.
  final OnBoardLEDs leds = new OnBoardLEDs._();

  RaspberryPi();
}

// The on-board LEDs.
enum _OnboardLED {
  power,
  activity,
}

/// Access to the on-board LEDs.
class OnBoardLEDs {
  // Values of the on-board LEDs GPIO pins for Raspberry Pi 2. On a model 1 the
  // values are ? and 16.
  static const int _powerLEDGpioPin = 35;
  static const int _activityLEDGpioPin = 47;

  // Cached constants.
  ByteBuffer _gpio;
  ByteBuffer _heartbeat;
  ByteBuffer _timer;
  ByteBuffer _input;
  ByteBuffer _mmc0;
  ByteBuffer _zero;
  ByteBuffer _twofivefive;

  OnBoardLED _power;
  OnBoardLED _activity;

  OnBoardLEDs._() {
    // Byte buffers for string constants.
    var data;
    data = new Uint8List(4);
    data.setRange(0, 4, 'gpio'.codeUnits);
    _gpio = data.buffer;
    data = new Uint8List(9);
    data.setRange(0, 9, 'heartbeat'.codeUnits);
    _heartbeat = data.buffer;
    data = new Uint8List(5);
    data.setRange(0, 5, 'timer'.codeUnits);
    _timer = data.buffer;
    data = new Uint8List(5);
    data.setRange(0, 5, 'input'.codeUnits);
    _input = data.buffer;
    data = new Uint8List(4);
    data.setRange(0, 4, 'mmc0'.codeUnits);
    _mmc0 = data.buffer;
    data = new Uint8List(1);
    data.setRange(0, 1, '0'.codeUnits);
    _zero = data.buffer;
    data = new Uint8List(3);
    data.setRange(0, 3, '255'.codeUnits);
    _twofivefive = data.buffer;

    _power = new OnBoardLED._(this, _OnboardLED.power, _powerLEDGpioPin);
    _activity = new OnBoardLED._(
        this, _OnboardLED.activity, _activityLEDGpioPin);
  }

  /// Get the power LED.
  OnBoardLED get powerLED => _power;

  /// Get the activity LED.
  OnBoardLED get activityLED => _activity;

  // The directory name for the LED control files.
  String _ledDirectoryName(_OnboardLED led) {
    return led == _OnboardLED.power ? 'led1' : 'led0';
  }

  _setMode(_OnboardLED led, OnboardLEDMode mode) {

    // Open the trigger file for this onboard LED.
    var dir = _ledDirectoryName(led);
    var f = new File.open('/sys/class/leds/$dir/trigger', mode: File.WRITE);
    var value;
    switch (mode) {
      case OnboardLEDMode.system:
        value = led == _OnboardLED.power ? _input : _mmc0;
        break;
      case OnboardLEDMode.gpio:
        value = _gpio;
        break;
      case OnboardLEDMode.heartbeat:
        value = _heartbeat;
        break;
      case OnboardLEDMode.timer:
        value = _timer;
        break;
      default:
        throw new UnsupportedError('Unsupported enum value');
    }
    f.write(value);
    f.close();
  }

  _setBrightness(_OnboardLED led, bool value) {
    // Open the brightness file for this onboard LED..
    var dir = _ledDirectoryName(led);
    var f = new File.open('/sys/class/leds/$dir/brightness', mode: File.WRITE);
    f.write(value ? _twofivefive : _zero);
    f.close();
  }
}

/// Access to an on-board LEDs.
class OnBoardLED {
  OnBoardLEDs _leds;
  _OnboardLED _led;

  /// The GPIO pin associated with this on-board LED.
  ///
  // Use this value for manipulating the LED through the GPIO API.
  final int pin;

  OnBoardLED._(this._leds, this._led, this.pin);

  /// Set the mode of the on-board LED.
  void setMode(OnboardLEDMode mode) {
    _leds._setMode(_led, mode);
  }

  /// Turn on the LED.
  void on() => _leds._setBrightness(_led, true);

  /// Turn off the LED.
  void off() => _leds._setBrightness(_led, false);
}
