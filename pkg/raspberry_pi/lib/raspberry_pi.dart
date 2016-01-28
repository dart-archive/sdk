// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Access to Raspberry Pi 2 specific hardware features such as onboard LEDs.
/// Also provides an API to the Sense HAT shield.
///
/// The class [RaspberryPi] provide access to the Raspberry Pi features.
///
/// Usage
/// -----
/// ```dart
/// import 'package:raspberry_pi/raspberry_pi.dart';
///
/// main() {
///   // Initialize Raspberry Pi and configure the activity LED to be GPIO
///   // controlled.
///   RaspberryPi pi = new RaspberryPi();
///   pi.leds.activityLED.setMode(OnboardLEDMode.gpio);
///
///   // Turn LED on
///   pi.leds.activityLED.on();
/// }
/// ```
///
/// Reporting issues
/// ----------------
/// Please file an issue [in the issue
/// tracker](https://github.com/dart-lang/fletch/issues/new?title=Add%20title&labels=Area-Package&body=%3Cissue%20description%3E%0A%3Crepro%20steps%3E%0A%3Cexpected%20outcome%3E%0A%3Cactual%20outcome%3E).
library raspberry_pi;

import 'dart:fletch.ffi';
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:gpio/gpio.dart' as gpio;

// Foreign functions used.
final ForeignFunction _open = ForeignLibrary.main.lookup('open');
final ForeignFunction _mmap = ForeignLibrary.main.lookup('mmap');

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
/// Use GPIO through the memory mapped interface:
///
/// ```
/// import 'package:raspberry_pi/raspberry_pi.dart';
/// import 'package:gpio/gpio.dart';
///
/// main() {
///   RaspberryPi pi = new RaspberryPi();
///   GPIO gpio = pi.memoryMappedGPIO; // Selecting memory mapped GPIO.
///   gpio.setMode(4, Mode.output);
///   gpio.setPin(4, true);
/// }
/// ```
///
/// Use GPIO through the sysfs interface:
///
/// ```
/// import 'package:raspberry_pi/raspberry_pi.dart';
/// import 'package:gpio/gpio.dart';
///
/// main() {
///   RaspberryPi pi = new RaspberryPi();
///   GPIO gpio = pi.sysfsGPIO; // Selecting sysfs GPIO.
///   gpio.setMode(4, Mode.output);
///   gpio.setPin(4, true);
/// }
/// ```
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
  /// The number of GPIO pins on the Raspberry Pi 2.
  static const int gpioPins = 54;
  var _memoryMappedGPIO;
  var _sysfsGPIO;

  /// Provide access to the on-board LEDs.
  final OnBoardLEDs leds = new OnBoardLEDs._();

  RaspberryPi();

  get memoryMappedGPIO {
    if (_memoryMappedGPIO == null) {
      _memoryMappedGPIO = new PiMemoryMappedGPIO();
    }
    return _memoryMappedGPIO;
  }

  get sysfsGPIO {
    if (_sysfsGPIO == null) {
      _sysfsGPIO = new gpio.SysfsGPIO(gpioPins);
    }
    return _sysfsGPIO;

  }
}

/// Pull-up/down resistor state.
enum PullUpDown {
  floating,
  pullDown,
  pullUp,
}

/// Provide GPIO access on Raspberry Pi using direct memory access.
///
/// The following code shows how to turn on GPIO pin 4:
///
/// ```
/// PiMemoryMappedGPIO gpio = new PiMemoryMappedGPIO();
/// gpio.setMode(4, Mode.output);
/// gpio.setPin(4, true));
/// ```
///
/// The following code shows how to read GPIO pin 17:
///
/// ```
/// PiMemoryMappedGPIO gpio = new PiMemoryMappedGPIO();
/// gpio.setMode(17, Mode.input);
/// print(gpio.getPin(17));
/// ```
class PiMemoryMappedGPIO extends gpio.GPIOBase {
  // See datasheet:
  // https://www.raspberrypi.org/wp-content/uploads/2012/02/BCM2835-ARM-Peripherals.pdf

  // Raspberry Pi model 1 (A/A+/B)
  // BCM2708 / BCM 2835

  // Raspberry Pi model 2
  // BCM2709 / BCM 2836

  // Peripherals base address.
  static const int _baseAddressModel1 = 0x20000000;
  static const int _baseAddressModel2 = 0x3F000000;
  static const int _baseAddressGPIOOffset = 0x00200000;

  // Size of the peripherals area.
  static const int _blockSize = 4096;

  // Offsets (in bytes) to various areas.
  static const int _gpioFunctionSelectBase = 0 << 2;
  static const int _gpioOutputSetBase = 7 << 2;
  static const int _gpioOutputClearBase = 10 << 2;
  static const int _gpioPinLevelBase = 13 << 2;
  static const int _gpioPullUpPullDown = 37 << 2;
  static const int _gpioPullUpPullDownClockBase = 38 << 2;

  // All alternative functions are mapped to `Mode.other` for now.
  static const _functionToMode =
      const [gpio.Mode.input, gpio.Mode.output,
       gpio.Mode.other, gpio.Mode.other,
       gpio.Mode.other, gpio.Mode.other, gpio.Mode.other];

  int _fd;  // File descriptor for /dev/mem.
  ForeignPointer _addr;
  ForeignMemory _mem;

  PiMemoryMappedGPIO(): super(RaspberryPi.gpioPins) {
    // From /usr/include/x86_64-linux-gnu/bits/fcntl-linux.h.
    const int oRDWR = 02;  // O_RDWR
    // Found from C code 'printf("%x\n", O_SYNC);'.
    const int oSync = 0x101000;  // O_SYNC

    // Open /dev/mem to get to the physical memory.
    var devMem = new ForeignMemory.fromStringAsUTF8('/dev/mem');
    _fd = _open.icall$2Retry(devMem, oRDWR | oSync);
    if (_fd < 0) {
      throw new gpio.GPIOException("Failed to open '/dev/mem'", Foreign.errno);
    }
    devMem.free();

    // From /usr/include/x86_64-linux-gnu/bits/mman-linux.h.
    const int protRead = 0x1;  // PROT_READ.
    const int protWrite = 0x2;  // PROT_WRITE.
    const int mapShared = 0x01;  // MAP_SHARED.

    _addr = _mmap.pcall$6(0, _blockSize, protRead | protWrite, mapShared,
                          _fd, _baseAddressModel2 + _baseAddressGPIOOffset);
    _mem = new ForeignMemory.fromAddress(_addr.address, _blockSize);
  }

  void setMode(int pin, gpio.Mode mode) {
    checkPinRange(pin);
    // GPIO function select registers each have 3 bits for 10 pins.
    var fsel = (pin ~/ 10);
    var shift = (pin % 10) * 3;
    var function = mode == gpio.Mode.input ? 0 : 1;
    var offset = _gpioFunctionSelectBase + (fsel << 2);
    var value = _mem.getUint32(offset);
    value = (value & ~(0x07 << shift)) | function << shift;
    _mem.setUint32(offset, value);
  }

  gpio.Mode getMode(int pin) {
    checkPinRange(pin);
    // GPIO function select registers each have 3 bits for 10 pins.
    var fsel = (pin ~/ 10);
    var shift = (pin % 10) * 3;
    var offset = _gpioFunctionSelectBase + (fsel << 2);
    var function = (_mem.getUint32(offset) >> shift) & 0x07;
    return _functionToMode[function];
  }

  void setPin(int pin, bool value) {
    checkPinRange(pin);
    // GPIO output set and output clear registers each have 1 bits for 32 pins.
    int register = pin ~/ 32;
    int shift = pin % 32;
    if (value) {
      _mem.setUint32(_gpioOutputSetBase + (register << 2), 1 << shift);
    } else {
      _mem.setUint32(_gpioOutputClearBase + (register << 2), 1 << shift);
    }
  }

  bool getPin(int pin) {
    checkPinRange(pin);
    // GPIO pin level registers each have 1 bits for 32 pins.
    int register = pin ~/ 32;
    int shift = pin % 32;
    return
        (_mem.getUint32(_gpioPinLevelBase + (register << 2)) & 1 << shift) != 0;
  }

  /// Set the floating/pull-up/pull-down state of [pin].
  ///
  /// Use `0` for floating, `1` for pull down and `2` for pull-up.
  void setPullUpDown(int pin, PullUpDown pullUpDown) {
    checkPinRange(pin);
    int register = pin ~/ 32;
    int shift = pin % 32;
    // First set the value in the update register.
    _mem.setUint32(_gpioPullUpPullDown, pullUpDown.index);
    sleep(1);  // Datasheet says: "Wait for 150 cycles".
    // Then set the clock bit.
    _mem.setUint32(_gpioPullUpPullDownClockBase + (register << 2), 1 << shift);
    sleep(1);  // Datasheet says: "Wait for 150 cycles".
    // Clear value and clock bit.
    _mem.setUint32(_gpioPullUpPullDown, 0);
    _mem.setUint32(_gpioPullUpPullDownClockBase + (register << 2), 0);
  }
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
