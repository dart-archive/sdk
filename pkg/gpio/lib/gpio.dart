// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// GPIO support providing access to controlling GPIO pins.
///
/// Currently this has only been tested with a Raspberry Pi 2 and the
/// STM32F746G-Discovery board.
///
/// Access types
/// ------------
/// There are two ways of accessing the GPIO pins: direct access or
/// access through a Sysfs driver.
///
/// When direct access is used, the physical memory addresses, where the
/// SoC registers for the GPIO pins are mapped, are accessed directly. If this
/// is on Linux on the Raspberry Pi this always requires root access.
///
/// On Linux on the Raspberry Pi the Sysfs driver is also an option. As this
/// uses the filesystem under `/sys/class/gpio`; root access is also required
/// by default. However this can be changed through udev rules, e.g. by
/// adding a file to ` /etc/udev/rules.d`. In addition the Sysfs driver
/// supports state change notifications.
///
/// Usage on Raspberry Pi 2
/// -----------------------
/// ```dart
/// import 'package:gpio/gpio.dart';
/// import 'package:raspberry_pi/raspberry_pi.dart';
///
/// main() {
///   // Initialize Raspberry Pi and configure the pins.
///   RaspberryPi pi = new RaspberryPi();
///   Gpio gpio = pi.memoryMappedGPIO;
///   GpioOutputPin pin = gpio.initOutput(RaspberryPiPin.GPIO6);
///
///   // Access pin.
///   pin.state =  true;
/// ```
///
/// Usage on STM32F746G Discovery board
/// -----------------------------------
/// ```dart
/// import 'package:gpio/gpio.dart';
/// import 'package:stm32/stm32f746g_disco.dart';
///
/// main() {
///   // Initialize STM32F746G Discovery board and configure the pins.
///   STM32F746GDiscovery board = new STM32F746GDiscovery();
///   GpioOutputPin pin = board.gpio.initOutput(STM32F746GDiscovery.LED1);
///
///   // Access pin.
///   pin.state =  true;
/// ```
///
/// See `samples/raspberry_pi/` and `samples/stm32f746g-discovery` for
/// additional details.
///
/// Reporting issues
/// ----------------
/// Please file an issue [in the issue
/// tracker](https://github.com/dartino/sdk/issues/new?title=Add%20title&labels=Area-Package&body=%3Cissue%20description%3E%0A%3Crepro%20steps%3E%0A%3Cexpected%20outcome%3E%0A%3Cactual%20outcome%3E).
library gpio;

import 'dart:dartino.ffi';
import 'dart:typed_data';

import 'package:file/file.dart';

// Foreign functions used.
final ForeignFunction _lseek = ForeignLibrary.main.lookup('lseek');
final ForeignFunction _poll = ForeignLibrary.main.lookup('poll');

/// Describes a pin on a MCU/SoC.
///
/// Each GPIO platform have its own implementation of this.
abstract class Pin {
  /// Name of the pin.
  String get name;
}

/// Pull-up/down resistor state.
enum GpioPullUpDown {
  floating,
  pullDown,
  pullUp,
}

/// Interrupt triggers.
enum GpioInterruptTrigger {
  none,
  rising,
  falling,
  both,
}

/// Pin on a MCU/SoC configured for GPIO operation.
///
/// This is a common super interface for the different types GPIO pin
/// configuration.
abstract class GpioPin {
  /// The pin configured.
  Pin get pin;
}

/// Pin on a MCU/SoC configured for GPIO output.
abstract class GpioOutputPin extends GpioPin {
  /// Gets or sets the state of the GPIO pin.
  bool state;

  void low() {
    state = false;
  }

  /// Sets the state of the GPIO pin to high (`true`).
  void high() {
    state = true;
  }

  /// Toggles the state of the GPIO pin.
  ///
  /// Returns the new state if the pin.
  bool toggle() => state = !state;
}

/// Pin on a MCU/SoC configured for GPIO input.
abstract class GpioInputPin extends GpioPin {
  /// Gets the state of the GPIO pin.
  bool get state;

  /// Waits for this pin to achieve value [value] within the timeout
  /// [timeout].
  ///
  /// The `timeout` value is specified in milliseconds. Specifying a
  /// negative value in `timeout` means an infinite timeout.
  ///
  /// Returns the value of this after the transition, or `null` of a
  /// timeout occurred.
  bool waitFor(bool value, int timeout);
}

/// Access to GPIO interface to configure GPIO pins.
abstract class Gpio {
  /// Initialize a GPIO pin for output.
  GpioOutputPin initOutput(Pin pin);

  /// Initialize a GPIO pin for input.
  GpioInputPin initInput(
      Pin pin, {GpioPullUpDown pullUpDown, GpioInterruptTrigger trigger});
}

/// Concrete pins on a Sysfs GPIO interface.
class SysfsPin implements Pin {
  final int pin;

  const SysfsPin(this.pin);
  String get name => 'Sysfs GPIO pin $pin';
  String toString() => name;
}

/// Pins on the Raspberry Pi configured for GPIO output.
class _SysfsGpioOutputPin extends GpioOutputPin {
  SysfsGpio _gpio;
  final SysfsPin pin;

  _SysfsGpioOutputPin(this._gpio, this.pin);

  bool get state => _gpio._getState(pin);

  void set state(bool newState) {
    _gpio._setState(pin, newState);
  }
}

/// Pins on the Raspberry Pi configured for GPIO input.
class _SysfsGpioInputPin extends GpioInputPin {
  SysfsGpio _gpio;
  final SysfsPin pin;

  _SysfsGpioInputPin(this._gpio, this.pin);

  bool get state => _gpio._getState(pin);

  bool waitFor(bool value, int timeout)  => _gpio._waitFor(pin, value, timeout);
}

/// Provide GPIO access using the Sysfs Interface for Userspace.
///
/// The following code shows how to turn on GPIO pin 4:
///
/// ```
/// Pin pin4 = const SysfsPin(4)
/// SysfsGpio gpio = new SysfsGpio();
/// gpio.exportPin(pin4);
/// GpioOutputPin gpio4 = gpio.initOutput(pin4);
/// gpio4.state = true;
/// ```
///
/// The following code shows how to read GPIO pin 17:
///
/// ```
/// Pin pin17 = const SysfsPin(17)
/// SysfsGpio gpio = new SysfsGpio();
/// gpio.exportPin(pin17);
/// GpioInputPin gpio17 = gpio.initInput(pin17);
/// print(gpio17.state);
/// ```
///
/// The Sysfs Interface provides state change notifications. The following
/// code will echo the state of GPIO pin 17 to GPIO pin 4.
///
/// ```
/// Pin pin4 = const SysfsPin(4)
/// Pin pin17 = const SysfsPin(17)
/// SysfsGpio gpio = new SysfsGpio();
/// gpio.exportPin(4);
/// GpioOutputPin gpio4 = gpio.initOutput(pin4);
/// gpio.exportPin(17);
/// GpioInputPin gpio17 = gpio.initInput(pin17, trigger: GpioInterruptTrigger.both);
///
/// gpio4.state = gpio17.state;
/// while (true) {
///   var value = gpio17.waitFor(!value, -1);
///   gpio4.state = value;
/// }
/// ```
class SysfsGpio implements Gpio {
  /// The default number of pins for GPIO is 50.
  static const int defaultPins = 50;

  /// The number of supported pins.
  final int pins;

  // For documentation on the GPIO Sysfs Interface for Userspace see
  // https://www.kernel.org/doc/Documentation/gpio/sysfs.txt.
  static const String _basePath = '/sys/class/gpio/';

  // Cached constants.
  ByteBuffer _zero;
  ByteBuffer _one;
  ByteBuffer _in;
  ByteBuffer _out;
  ByteBuffer _none;
  ByteBuffer _rising;
  ByteBuffer _falling;
  ByteBuffer _both;

  // Open value files for all tracked (exported) pins. Indexed by pin
  // number.
  List<File> _tracked;

  /// Create a GPIO controller using the GPIO Sysfs Interface.
  SysfsGpio({this.pins: defaultPins}) {
    // Byte buffers for string constants.
    var data;
    data = new Uint8List(1);
    data.setRange(0, 1, '0'.codeUnits);
    _zero = data.buffer;
    data = new Uint8List(1);
    data.setRange(0, 1, '1'.codeUnits);
    _one = data.buffer;
    data = new Uint8List(2);
    data.setRange(0, 2, 'in'.codeUnits);
    _in = data.buffer;
    data = new Uint8List(3);
    data.setRange(0, 3, 'out'.codeUnits);
    _out = data.buffer;
    data = new Uint8List(4);
    data.setRange(0, 4, 'none'.codeUnits);
    _none = data.buffer;
    data = new Uint8List(6);
    data.setRange(0, 6, 'rising'.codeUnits);
    _rising = data.buffer;
    data = new Uint8List(7);
    data.setRange(0, 7, 'falling'.codeUnits);
    _falling = data.buffer;
    data = new Uint8List(4);
    data.setRange(0, 4, 'both'.codeUnits);
    _both = data.buffer;

    // Find the exported pins by just running through all pins, trying to open
    // the value file.
    _tracked = new List<File>(pins);
    for (int pin = 0; pin < pins; pin++) {
      _track(pin);
    }
  }

  /// Initialize a GPIO pin for output.
  GpioOutputPin initOutput(Pin pin) {
    _init(_checkPinArgument(pin), true, null);
    return new _SysfsGpioOutputPin(this, pin);
  }

  /// Initialize a GPIO pin for input.
  GpioInputPin initInput(
      Pin pin, {GpioPullUpDown pullUpDown, GpioInterruptTrigger trigger}) {
    if (pullUpDown != null) {
      throw new ArgumentError('Pull-up/down not supported for sysfs GPIO');
    }
    _init(_checkPinArgument(pin), false, trigger);
    return new _SysfsGpioInputPin(this, pin);
  }

  void _init(SysfsPin pin, bool output, GpioInterruptTrigger trigger) {
    _checkTracked(pin);
    var f =
        new File.open('${_basePath}gpio${pin.pin}/direction', mode: File.WRITE);
    f.write(output ? _out : _in);
    f.close();
    if (!output && trigger != null) {
      // Write the trigger mode to the edge file.
      var f =
          new File.open('${_basePath}gpio${pin.pin}/edge', mode: File.WRITE);
      try {
        switch (trigger) {
          case GpioInterruptTrigger.none:
            f.write(_none);
            break;
          case GpioInterruptTrigger.rising:
            f.write(_rising);
            break;
          case GpioInterruptTrigger.falling:
            f.write(_falling);
            break;
          case GpioInterruptTrigger.both:
            f.write(_both);
            break;
        }
      } finally {
        f.close();
      }
    }
  }

  void _setState(SysfsPin pin, bool value) {
    _checkTracked(pin);
    var f = _tracked[pin.pin];
    f.write(value ? _one : _zero);
  }

  bool _getState(SysfsPin pin) {
    _checkTracked(pin);
    var f = _tracked[pin.pin];
    // Always seek to the beginning of the file before reading.
    _lseek.icall$3Retry(f.fd, 0, 0);
    var result = new Uint8List.view(f.read(1))[0] == 0x31;  // '1';
    return result;
  }

  bool _waitFor(SysfsPin pin, bool value, int timeout) {
    _checkTracked(pin);
    // From /usr/include/asm-generic/poll.h:#define POLLPRI 0x0002
    // struct pollfd
    // {
    //   int fd;                  /* File descriptor to poll.  */
    //   short int events;        /* Types of events poller cares about.  */
    //   short int revents;       /* Types of events that actually occurred.  */
    // };
    // ...
    // #define POLLPRI 0x0002
    const int pollfdSize = 8;
    const int pollfdFdOffset = 0;
    const int pollfdEventsOffset = 4;
    const int pollfdReventsOffset = 6;
    const int pollpriFlag = 0x0002;

    while (true) {
      // Return if the pin has the requested value.
      if (_getState(pin) == value) return value;

      // Wait for a transition.
      var pollfd = new ForeignMemory.allocated(pollfdSize);

      // Setup the pollfd structure.
      pollfd.setUint32(pollfdFdOffset, _tracked[pin.pin].fd);
      pollfd.setUint16(pollfdEventsOffset, pollpriFlag);
      pollfd.setUint16(pollfdReventsOffset, 0);
      var rc = _poll.icall$3Retry(pollfd, 1, timeout);
      var revents = pollfd.getUint16(pollfdReventsOffset);
      pollfd.free();
      if (rc < 0) throw new GpioException("poll failed");

      // If there is no event a timeout occurred.
      if ((revents & pollpriFlag) == 0) {
        return null;
      }
    }
  }

  void _exportUnexport(bool export, SysfsPin pin) {
    // Write pin number to the export or unexport file.
    var exportOrUnexport = export ? 'export' : 'unexport';
    var f = new File.open('${_basePath}${exportOrUnexport}',
                          mode: File.WRITE_ONLY);
    var value = '${pin.pin}'.codeUnits;
    var bytes = new Uint8List(value.length);
    bytes.setRange(0, value.length, value);
    f.write(bytes.buffer);
    f.close();
  }

  void _track(int pin) {
    _untrack(pin);
    var f;
    try {
      // Open the value file for this pin.
      f = new File.open('${_basePath}gpio${pin}/value', mode: File.WRITE);
    } catch (e) {
      // Ignore pins which cannot be opened.
      return;
    }
    _tracked[pin] = f;
  }

  void _untrack(int pin) {
    if (_tracked[pin] != null) {
      _tracked[pin].close();
      _tracked[pin] = null;
    }
  }

  void _checkTracked(SysfsPin pin) {
    if (!isTracked(pin)) new GpioException('Pin $pin is not tracked');
  }

  /// Returns a list with the pins currently tracked.
  List tracked() {
    var result = [];
    for (int pin = 0; pin < pins; pin++) {
      if (_tracked[pin] != null) result.add(pin);
    }
    return result;
  }

  /// Checks if [pin] is tracked.
  bool isTracked(SysfsPin pin) {
    return _tracked[pin.pin] != null;
  }

  void exportPin(SysfsPin pin) {
    _checkPinArgument(pin);
    // If already exported do nothing.
    if (isTracked(pin)) return;
    _exportUnexport(true, pin);
    _track(pin.pin);  // This is now tracked.
  }

  void unexportPin(SysfsPin pin) {
    _checkPinArgument(pin);
    // If not exported do nothing.
    if (!isTracked(pin)) return;
    _exportUnexport(false, pin);
    _untrack(pin.pin);  // This is no longer tracked.
  }

  SysfsPin _checkPinArgument(Pin pin) {
    if (pin is! SysfsPin) {
      throw new ArgumentError('Illegal pin type');
    }
    SysfsPin p = pin;
    if (p.pin < 0 || pins <= p.pin) {
      throw new RangeError.index(p.pin, this, 'pin', null, pins);
    }
    return p;
  }
}

/// Exceptions thrown by GPIO.
class GpioException implements Exception {
  /// Exception message.
  final String message;
  /// OS error number if any.
  final int errno;
  const GpioException(this.message, [this.errno]);
  String toString() {
    if (errno == null) return message;
    return '$message (error ${errno})';
  }
}
