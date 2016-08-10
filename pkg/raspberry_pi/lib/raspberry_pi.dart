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
/// tracker](https://github.com/dartino/sdk/issues/new?title=Add%20title&labels=Area-Package&body=%3Cissue%20description%3E%0A%3Crepro%20steps%3E%0A%3Cexpected%20outcome%3E%0A%3Cactual%20outcome%3E).
library raspberry_pi;

import 'dart:dartino';

import 'dart:dartino.ffi';
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:gpio/gpio.dart';

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
///   Gpio gpio = pi.memoryMappedGpio; // Selecting memory mapped GPIO.
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
///   GPIO gpio = pi.sysfsGpio; // Selecting sysfs GPIO.
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
  RaspberryPiMemoryMappedGpio _memoryMappedGpio;
  var _sysfsGpio;

  /// Provide access to the on-board LEDs.
  final OnBoardLEDs leds = new OnBoardLEDs._();

  RaspberryPi();

  Gpio get memoryMappedGpio {
    if (_memoryMappedGpio == null) {
      _memoryMappedGpio = new RaspberryPiMemoryMappedGpio();
    }
    return _memoryMappedGpio;
  }

  SysfsGpio get sysfsGpio {
    if (_sysfsGpio == null) {
      _sysfsGpio = new SysfsGpio(pins: 54);
    }
    return _sysfsGpio;
  }
}

const int _fselInput = 0;
const int _fselOutput = 1;
const int _fselAlternativeFn0 = 4;
const int _fselAlternativeFn1 = 4 + 1;
const int _fselAlternativeFn2 = 4 + 2;
const int _fselAlternativeFn3 = 4 + 3;
const int _fselAlternativeFn4 = 3;
const int _fselAlternativeFn5 = 2;

class _PwmChannel {
  final int channel;
  final int alternativeFunction;
  const _PwmChannel(this.channel, this.alternativeFunction);
}

/// Concrete pins on the Raspberry Pi.
class RaspberryPiPin implements Pin {
  static const Pin GPIO4 = const RaspberryPiPin('GPIO4', 4);
  static const Pin GPIO5 = const RaspberryPiPin('GPIO5', 5);
  static const Pin GPIO6 = const RaspberryPiPin('GPIO6', 6);
  static const Pin GPIO12 = const RaspberryPiPin('GPIO12', 12,
    const _PwmChannel(0, _fselAlternativeFn0));
  static const Pin GPIO13 = const RaspberryPiPin('GPIO13', 13,
    const _PwmChannel(1, _fselAlternativeFn0));
  static const Pin GPIO16 = const RaspberryPiPin('GPIO16', 16);
  static const Pin GPIO17 = const RaspberryPiPin('GPIO17', 17);
  static const Pin GPIO18 = const RaspberryPiPin('GPIO18', 18,
    const _PwmChannel(0, _fselAlternativeFn5));
  static const Pin GPIO19 = const RaspberryPiPin('GPIO19', 19,
    const _PwmChannel(1, _fselAlternativeFn5));
  static const Pin GPIO20 = const RaspberryPiPin('GPIO20', 20);
  static const Pin GPIO21 = const RaspberryPiPin('GPIO21', 21);
  static const Pin GPIO22 = const RaspberryPiPin('GPIO22', 22);
  static const Pin GPIO23 = const RaspberryPiPin('GPIO23', 23);
  static const Pin GPIO24 = const RaspberryPiPin('GPIO24', 24);
  static const Pin GPIO25 = const RaspberryPiPin('GPIO25', 25);
  static const Pin GPIO26 = const RaspberryPiPin('GPIO26', 26);
  static const Pin GPIO27 = const RaspberryPiPin('GPIO27', 27);

  final String name;
  final int pin;
  final _PwmChannel _pwm;

  const RaspberryPiPin(this.name, this.pin, [this._pwm]);
  String toString() => 'GPIO pin $name';
}

/// Pins on the Raspberry Pi configured for GPIO output.
class _RaspberryPiGpioOutputPin extends GpioOutputPin {
  RaspberryPiMemoryMappedGpio _gpio;
  final RaspberryPiPin pin;

  _RaspberryPiGpioOutputPin(this._gpio, this.pin);

  bool get state => _gpio._getState(pin);

  void set state(bool newState) {
    _gpio._setState(pin, newState);
  }
}

/// Pins on the Raspberry Pi configured for hardware PWM output.
class _RaspberryPiPwmOutputPin extends GpioPwmOutputPin {
  static const int _pwmClock = 19200000;  // PWM Clock speed in Hz.
  final RaspberryPiMemoryMappedGpio _gpio;
  final Pin _pin;
  final int _channel;
  int _divisor;
  int _period;
  num _frequency;
  num _pulse;

  _RaspberryPiPwmOutputPin(this._gpio, this._pin, this._channel)
      : _divisor = 0,
        _period = 0,
        _frequency = 0,
        _pulse = 0;

  Pin get pin => _pin;

  num get frequency => _frequency;

  void set frequency (num freq) {
    _frequency = freq;
    int ticks = (_pwmClock / freq).round();
    int err = ticks;
    for(int p = 2; p < 4096; p++) {
      int q = (ticks / p).round();
      int newErr = (ticks - p * q).abs();
      if(newErr < err) {
        err = newErr;
        _divisor = p;
        _period = q;
      }
      if(err == 0) {
        break;
      }
    }
    _gpio._setPwmClock(_divisor);
    _gpio._enablePwm(_channel);
    _gpio._setPeriod(_channel, _period);
    _outPulse();
  }

  num get pulse => _pulse;

  void set pulse (num length) {
    _pulse = length;
    _outPulse();
  }

  _outPulse() {
    int out = (_pulse * _period / 100.0).round();
    _gpio._setLevel(_channel, out);
  }
}

/// Pins on the Raspberry Pi configured for GPIO input.
class _RaspberryPiGpioInputPin extends GpioInputPin {
  RaspberryPiMemoryMappedGpio _gpio;
  final RaspberryPiPin pin;

  _RaspberryPiGpioInputPin(this._gpio, this.pin);

  bool get state => _gpio._getState(pin);

  bool waitFor(bool value, int timeout) {
    throw new UnsupportedError(
        'waitFor not supported for Raspberry Pi memory mapped GPIO');
  }
}

/// Provide GPIO access on Raspberry Pi using direct memory access.
///
/// The following code shows how to turn on GPIO pin 4:
///
/// ```
/// RaspberryPiMemoryMappedGpio gpio = new RaspberryPiMemoryMappedGpio();
/// GpioOutputPin gpio4 = gpio.initOutput(RaspberryPiPin.GPIO4);
/// gpio4.state = true;
/// ```
///
/// The following code shows how to read GPIO pin 17:
///
/// ```
/// RaspberryPiMemoryMappedGpio gpio = new RaspberryPiMemoryMappedGpio();
/// GpioInputPin gpio17 = gpio.initInput(RaspberryPiPin.GPIO17);
/// gpio17.state = true;
/// print(gpio17.state);
/// ```
class RaspberryPiMemoryMappedGpio implements Gpio {
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
  static const int _baseAddressClockOffset = 0x00101000;
  static const int _baseAddressPwmOffset = 0x0020C000;

  // Size of the peripherals area.
  static const int _blockSize = 4096;

  // Offsets (in bytes) to various areas.
  static const int _gpioFunctionSelectBase = 0 << 2;
  static const int _gpioOutputSetBase = 7 << 2;
  static const int _gpioOutputClearBase = 10 << 2;
  static const int _gpioPinLevelBase = 13 << 2;
  static const int _gpioPullUpPullDown = 37 << 2;
  static const int _gpioPullUpPullDownClockBase = 38 << 2;

  // Offsets for PWM clock registers.
  static const int _PWMCLK_CNTL = 40 << 2;
  static const int _PWMCLK_DIV = 41 << 2;

  // Offsets for PWM registers.
  static const int _PWM_CTL = 0;
  static const int _PWM_RNG0 = 4 << 2;
  static const int _PWM_DAT0 = 5 << 2;
  static const int _PWM_RNG1 = 8 << 2;
  static const int _PWM_DAT1 = 9 << 2;

  static const int _PWM_PASSWRD = 0x5A << 24;

  // Bit masks for PWM control register.
  static const int _PWM1_MS_MODE = 0x8000;  // Run in Mark/Space mode.
  static const int _PWM1_USEFIFO = 0x2000;  // Data from FIFO.
  static const int _PWM1_REVPOLAR = 0x1000;  // Reverse polarity.
  static const int _PWM1_OFFSTATE = 0x0800;  // Output Off state.
  static const int _PWM1_REPEATFF = 0x0400;  // Repeat last value if FIFO empty.
  static const int _PWM1_SERIAL = 0x0200;  // Run in serial mode.
  static const int _PWM1_ENABLE = 0x0100;  // Channel enable.
  static const int _PWM0_MS_MODE = 0x0080;  // Run in Mark/Space mode.
  static const int _PWM0_CLEAR_FIFO = 0x0040;  // Clear FIFO.
  static const int _PWM0_USEFIFO = 0x0020;  // Data from FIFO.
  static const int _PWM0_REVPOLAR = 0x0010;  // Reverse polarity.
  static const int _PWM0_OFFSTATE = 0x0008;  // Output Off state.
  static const int _PWM0_REPEATFF = 0x0004;  // Repeat last value if FIFO empty.
  static const int _PWM0_SERIAL = 0x0002;  // Run in serial mode.
  static const int _PWM0_ENABLE = 0x0001;  // Channel enable.

  int _fd;  // File descriptor for /dev/mem.
  ForeignMemory _gpioMem, _pwmMem, _clockMem;

  RaspberryPiMemoryMappedGpio() {
    // From /usr/include/x86_64-linux-gnu/bits/fcntl-linux.h.
    const int oRDWR = 02;  // O_RDWR
    // Found from C code 'printf("%x\n", O_SYNC);'.
    const int oSync = 0x101000;  // O_SYNC

    // Open /dev/mem to get to the physical memory.
    var devMem = new ForeignMemory.fromStringAsUTF8('/dev/mem');
    _fd = _open.icall$2Retry(devMem, oRDWR | oSync);
    if (_fd < 0) {
      throw new GpioException("Failed to open '/dev/mem'", Foreign.errno);
    }
    devMem.free();

    // From /usr/include/x86_64-linux-gnu/bits/mman-linux.h.
    const int protRead = 0x1;  // PROT_READ.
    const int protWrite = 0x2;  // PROT_WRITE.
    const int mapShared = 0x01;  // MAP_SHARED.

    ForeignMemory mapMemory(int offset) {
      ForeignPointer _addr = _mmap.pcall$6(0, _blockSize, protRead | protWrite,
        mapShared, _fd, _baseAddressModel2 + offset);
      return new ForeignMemory.fromAddress(_addr.address, _blockSize);
    }

    _gpioMem = mapMemory(_baseAddressGPIOOffset);
    _clockMem = mapMemory(_baseAddressClockOffset);
    _pwmMem = mapMemory(_baseAddressPwmOffset);
  }

  void _setPwmClock(int divisor) {
    // Stop PWM Clock.
    if (divisor < 0 || divisor > 4096) {
      throw new ArgumentError("Invalid divisor for RaspberryPi");
    }
    _clockMem.setUint32(_PWMCLK_CNTL, _PWM_PASSWRD | 0x01);
    sleep(1);
    // Wait for clock busy status to clear.
    while (_clockMem.getUint32(_PWMCLK_CNTL) & 0x80 != 0) {
      sleep(1);
    }
    _clockMem.setUint32(_PWMCLK_DIV, _PWM_PASSWRD | (divisor << 12));
    _clockMem.setUint32(_PWMCLK_CNTL, _PWM_PASSWRD | 0x11);
  }

  void _enablePwm(int channel) {
    int control = _pwmMem.getUint32(_PWM_CTL);
    if (channel == 0) {
      _pwmMem.setUint32(_PWM_CTL, control | _PWM0_MS_MODE | _PWM0_ENABLE);
    } else if(channel == 1) {
      _pwmMem.setUint32(_PWM_CTL, control | _PWM1_MS_MODE | _PWM1_ENABLE);
    }
  }

  void _setPeriod(int channel, int period) {
    if (channel == 0) {
      _pwmMem.setUint32(_PWM_RNG0, period);
    } else if (channel == 1) {
      _pwmMem.setUint32(_PWM_RNG1, period);
    }
  }

  void _setLevel(int channel, int value) {
    if (channel == 0) {
      _pwmMem.setUint32(_PWM_DAT0, value);
    } else if (channel == 1) {
      _pwmMem.setUint32(_PWM_DAT1, value);
    }
  }

  GpioOutputPin initOutput(Pin pin) {
    _init(pin, _fselOutput, GpioPullUpDown.floating);
    return new _RaspberryPiGpioOutputPin(this, pin);
  }

  GpioInputPin initInput(
      Pin pin, {GpioPullUpDown pullUpDown, GpioInterruptTrigger trigger}) {
    if (trigger != null) {
      throw new UnsupportedError(
          'trigger not supported for Raspberry Pi memory mapped GPIO');
    }
    _init(pin, _fselInput, pullUpDown);
    return new _RaspberryPiGpioInputPin(this, pin);
  }

  GpioPwmOutputPin initPwmOutput(Pin pin){
    if (pin is! RaspberryPiPin) {
      throw new ArgumentError('Illegal pin type');
    }
    RaspberryPiPin p = pin;
    if (p._pwm == null) {
      throw new ArgumentError('PWM not supported on pin ${pin}');
    }
    _init(pin, p._pwm.alternativeFunction, GpioPullUpDown.floating);
    return new _RaspberryPiPwmOutputPin(this, pin, p._pwm.channel);
  }

  void _init(Pin pin, int function, GpioPullUpDown pullUpDown) {
    if (pin is! RaspberryPiPin) {
      throw new ArgumentError('Illegal pin type');
    }
    RaspberryPiPin p = pin;

    // GPIO function select registers each have 3 bits for 10 pins.
    int fsel = (p.pin ~/ 10);
    int shift = (p.pin % 10) * 3;
    int offset = _gpioFunctionSelectBase + (fsel << 2);
    int value = _gpioMem.getUint32(offset);
    value = (value & ~(0x07 << shift)) | function << shift;
    _gpioMem.setUint32(offset, value);

    // Configure pull-up/pull-down for input.
    if (function == _fselInput) {
      // Use 0 for floating, 1 for pull down and 2 for pull-up.
      int register = p.pin ~/ 32;
      int shift = p.pin % 32;
      int value = 0;
      if (pullUpDown != GpioPullUpDown.floating) {
        value = pullUpDown == GpioPullUpDown.pullDown ? 1 : 2;
      }
      // First set the value in the update register.
      _gpioMem.setUint32(_gpioPullUpPullDown, value);
      sleep(1);  // Datasheet says: "Wait for 150 cycles".
      // Then set the clock bit.
      _gpioMem.setUint32(
          _gpioPullUpPullDownClockBase + (register << 2), 1 << shift);
      sleep(1);  // Datasheet says: "Wait for 150 cycles".
      // Clear value and clock bit.
      _gpioMem.setUint32(_gpioPullUpPullDown, 0);
      _gpioMem.setUint32(_gpioPullUpPullDownClockBase + (register << 2), 0);
    }
  }

  void _setState(Pin pin, bool value) {
    if (pin is! RaspberryPiPin) {
      throw new ArgumentError('Illegal pin type');
    }
    RaspberryPiPin p = pin;

    // GPIO output set and output clear registers each have 1 bits for 32 pins.
    int register = p.pin ~/ 32;
    int shift = p.pin % 32;
    if (value) {
      _gpioMem.setUint32(_gpioOutputSetBase + (register << 2), 1 << shift);
    } else {
      _gpioMem.setUint32(_gpioOutputClearBase + (register << 2), 1 << shift);
    }
  }

  bool _getState(Pin pin) {
    if (pin is! RaspberryPiPin) {
      throw new ArgumentError('Illegal pin type');
    }
    RaspberryPiPin p = pin;

    // GPIO pin level registers each have 1 bits for 32 pins.
    int register = p.pin ~/ 32;
    int shift = p.pin % 32;
    int state = 
      _gpioMem.getUint32(_gpioPinLevelBase + (register << 2)) & (1 << shift);
    return state != 0;
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
