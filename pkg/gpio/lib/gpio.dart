// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// GPIO support.
///
/// Provides access to controlling GPIO pins.
///
/// The library provide two ways of accessing the GPIO pins: direct access or
/// access through a Sysfs driver.
///
/// When direct access is used, the physical memory addresses, where the
/// SoC registers for the GPIO pins are mapped, are accessed directly. This
/// always require root access.
///
/// When the Sysfs driver is used the filesystem under `/sys/class/gpio` is
/// used; root access is also required by default. However this can be changed
/// through udev rules, e.g. by adding a file to ` /etc/udev/rules.d`.
/// In addition the Sysfs driver supports state change notifications.
///
/// Currently this has only been tested with a Raspberry Pi 2.
library gpio;

import 'dart:fletch.ffi';
import 'dart:typed_data';

import 'package:file/file.dart';

// Foreign functions used.
final ForeignFunction _lseek = ForeignLibrary.main.lookup('lseek');
final ForeignFunction _poll = ForeignLibrary.main.lookup('poll');

/// GPIO modes.
enum Mode {
  /// GPIO pin input mode.
  input,
  /// GPIO pin output mode.
  output,
  /// GPIO has other functions than `input` and `output`. Most GPIO pins have
  /// several special functions, so when receiving the mode this value can be
  /// returned. This value cannot be used when setting the mode.
  other
}

/// Base GPIO interface supported by all GPIO implementations.
abstract class GPIO {
  /// The default number of pins for GPIO is 50.
  static const int defaultPins = 50;

  /// Number of pins exposed by this GPIO.
  int get pins;

  /// Set the mode of [pin] to [mode].
  void setMode(int pin, Mode mode);

  /// Get the current mode of [pin].
  Mode getMode(int pin);

  /// Set the value of the [pin] to [value]. The boolean value
  /// [true] represents high (1) and the boolean value [false]
  /// represents low (0).
  void setPin(int pin, bool value);

  /// Get the value of the [pin]. The boolean value
  /// [true] represents high (1) and the boolean value [false]
  /// represents low (0).
  bool getPin(int pin);
}

// Internal base class.
abstract class GPIOBase implements GPIO {
  // Number of GPIO pins.
  final int _pins;

  GPIOBase(this._pins);

  get pins => _pins;

  void checkPinRange(int pin) {
    if (pin < 0 || _pins <= pin) {
      throw new RangeError.index(pin, this, 'pin', null, _pins);
    }
  }
}

/// Interrupt triggers.
enum Trigger {
  none,
  rising,
  falling,
  both,
}

/// Provide GPIO access using the Sysfs Interface for Userspace.
///
/// The following code shows how to turn on GPIO pin 4:
///
/// ```
/// SysfsGPIO gpio = new SysfsGPIO();
/// gpio.exportPin(4);
/// gpio.setMode(4, Mode.output);
/// gpio.setPin(4, true));
/// ```
///
/// The following code shows how to read GPIO pin 17:
///
/// ```
/// SysfsGPIO gpio = new SysfsGPIO();
/// gpio.exportPin(17);
/// gpio.setMode(17, Mode.input);
/// print(gpio.getPin(17));
/// ```
///
/// The Sysfs Interface provides state change notifications. The following
/// code will echo the state of GPIO pin 17 to GPIO pin 4.
///
/// ```
/// SysfsGPIO gpio = new SysfsGPIO();
/// gpio.exportPin(4);
/// gpio.setMode(4, Mode.output);
/// gpio.exportPin(17);
/// gpio.setMode(17, Mode.input);
/// gpio.setTrigger(17, Trigger.both);
/// bool value = gpio.getPin(17)
/// gpio.setPin(4, value);
/// while (true) {
///   var value = gpio.waitFor(17, !value, -1);
///   gpio.setPin(4, value);
/// }
/// ```
class SysfsGPIO extends GPIOBase {
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

  // Open value files for all tracked pins. Indexed by pin number.
  List<File> _tracked;

  /// Create a GPIO controller using the GPIO Sysfs Interface.
  SysfsGPIO([int pins = GPIO.defaultPins]): super(pins) {
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

    // Find the exported pins by just running through all trying to open
    // the value file.
    _tracked = new List<File>(pins);
    for (int pin = 0; pin < pins; pin++) {
      _track(pin);
    }
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

  void _untrack(pin) {
    if (_tracked[pin] != null) {
      _tracked[pin].close();
      _tracked[pin] = null;
    }
  }

  void _checkTracked(int pin) {
    checkPinRange(pin);
    if (!isTracked(pin)) throw 'Pin $pin is not tracked';
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
  bool isTracked(int pin) {
    return _tracked[pin] != null;
  }

  void setMode(int pin, Mode mode) {
    _checkTracked(pin);
    var f = new File.open('${_basePath}gpio${pin}/direction', mode: File.WRITE);
    f.write(mode == Mode.input ? _in : _out);
    f.close();
  }

  Mode getMode(int pin) {
    _checkTracked(pin);
    var f = new File.open('${_basePath}gpio${pin}/direction', mode: File.WRITE);
    f.write(mode == Mode.input ? _in : _out);
    f.close();
  }

  void setPin(int pin, bool value) {
    _checkTracked(pin);
    var f = _tracked[pin];
    f.write(value ? _one : _zero);
  }

  bool getPin(int pin) {
    _checkTracked(pin);
    var f = _tracked[pin];
    // Always seek to the beginning of the file before reading.
    _lseek.icall$3Retry(f.fd, 0, 0);
    var result = new Uint8List.view(f.read(1))[0] == 0x31;  // '1';
    return result;
  }

  /// Sets the interrupt trigger for [pin] to [trigger].
  ///
  /// When a trigger is set use `waitFor` to wait for transitions on pin `pin`.
  void setTrigger(int pin, Trigger trigger) {
    _checkTracked(pin);
    // Write the trigger mode to the edge file.
    var f = new File.open('${_basePath}gpio${pin}/edge', mode: File.WRITE);
    try {
      switch (trigger) {
        case Trigger.none:
          f.write(_none);
          break;
        case Trigger.rising:
          f.write(_rising);
          break;
        case Trigger.falling:
          f.write(_falling);
          break;
        case Trigger.both:
          f.write(_both);
          break;
      }
    } finally {
      f.close();
    }
  }

  /// Waits for the [pin] to achieve value [value] within the timeout
  /// [timeout].
  ///
  /// The `timeout` value is specified in milliseconds. Specifying a
  /// negative value in `timeout` means an infinite timeout.
  ///
  /// Returns the value of `pin` after the transition, or `null` of a
  /// timeout occurred.
  bool waitFor(int pin, bool value, int timeout) {
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
      if (getPin(pin) == value) return value;

      // Wait for a transition.
      var pollfd = new ForeignMemory.allocated(pollfdSize);

      // Setup the pollfd structure.
      pollfd.setUint32(pollfdFdOffset, _tracked[pin].fd);
      pollfd.setUint16(pollfdEventsOffset, pollpriFlag);
      pollfd.setUint16(pollfdReventsOffset, 0);
      var rc = _poll.icall$3Retry(pollfd, 1, timeout);
      var revents = pollfd.getUint16(pollfdReventsOffset);
      pollfd.free();
      if (rc < 0) throw "poll failed";

      // If there is no event a timeout occurred.
      if ((revents & pollpriFlag) == 0) {
        return null;
      }
    }
  }

  void _exportUnexport(bool export, int pin) {
    // Write pin number to the export or unexport file.
    var exportOrUnexport = export ? 'export' : 'unexport';
    var f = new File.open('${_basePath}${exportOrUnexport}',
                          mode: File.WRITE_ONLY);
    var value = '$pin'.codeUnits;
    var bytes = new Uint8List(value.length);
    bytes.setRange(0, value.length, value);
    f.write(bytes.buffer);
    f.close();
  }

  void exportPin(int pin) {
    checkPinRange(pin);
    // If already exported do nothing.
    if (isTracked(pin)) return;
    _exportUnexport(true, pin);
    _track(pin);  // This is now tracked.
  }

  void unexportPin(int pin) {
    checkPinRange(pin);
    // If not exported do nothing.
    if (!isTracked(pin)) return;
    _exportUnexport(false, pin);
    _untrack(pin);  // This is no longer tracked.
  }
}

/// Exceptions thrown by GPIO.
class GPIOException implements Exception {
  /// Exception message.
  final String message;
  /// OS error number if any.
  final int errno;
  const GPIOException(this.message, [this.errno]);
  String toString() {
    if (errno == null) return message;
    return '$message (error ${errno})';
  }
}
