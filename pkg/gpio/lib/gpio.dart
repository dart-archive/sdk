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

import 'dart:typed_data';
import 'dart:fletch.io';

import 'dart:fletch.ffi';

// Foreign functions used.
final ForeignFunction _open = ForeignLibrary.main.lookup('open');
final ForeignFunction _lseek = ForeignLibrary.main.lookup('lseek');
final ForeignFunction _mmap = ForeignLibrary.main.lookup('mmap');
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

/// Pull-up/down resistor state.
enum PullUpDown {
  floating,
  pullDown,
  pullUp,
}

// Internal base class.
class _GPIOBase {
  // Number of GPIO pins.
  final int _maxPins;

  _GPIOBase(this._maxPins);

  void _checkPinRange(int pin) {
    if (pin < 0 || _maxPins <= pin) {
      throw new RangeError.index(pin, this, 'pin', null, _maxPins);
    }
  }
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
class PiMemoryMappedGPIO extends _GPIOBase implements GPIO {
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
      [Mode.input, Mode.output,
       Mode.other, Mode.other, Mode.other, Mode.other, Mode.other];

  int _fd;  // File descriptor for /dev/mem.
  ForeignPointer _addr;
  ForeignMemory _mem;

  PiMemoryMappedGPIO(): super(54) {
    // From /usr/include/x86_64-linux-gnu/bits/fcntl-linux.h.
    const int oRDWR = 02;  // O_RDWR
    // Found from C code 'printf("%x\n", O_SYNC);'.
    const int oSync = 0x101000;  // O_SYNC

    // Open /dev/mem to get to the physical memory.
    var devMem = new ForeignMemory.fromStringAsUTF8('/dev/mem');
    _fd = _open.icall$2Retry(devMem, oRDWR | oSync);
    if (_fd < 0) {
      throw new GPIOException("Failed to open '/dev/mem'", Foreign.errno);
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

  void setMode(int pin, Mode mode) {
    _checkPinRange(pin);
    // GPIO function select registers each have 3 bits for 10 pins.
    var fsel = (pin ~/ 10);
    var shift = (pin % 10) * 3;
    var function = mode == Mode.input ? 0 : 1;
    var offset = _gpioFunctionSelectBase + (fsel << 2);
    var value = _mem.getUint32(offset);
    value = (value & ~(0x07 << shift)) | function << shift;
    _mem.setUint32(offset, value);
  }

  Mode getMode(int pin) {
    _checkPinRange(pin);
    // GPIO function select registers each have 3 bits for 10 pins.
    var fsel = (pin ~/ 10);
    var shift = (pin % 10) * 3;
    var offset = _gpioFunctionSelectBase + (fsel << 2);
    var function = (_mem.getUint32(offset) >> shift) & 0x07;
    return _functionToMode[function];
  }

  void setPin(int pin, bool value) {
    _checkPinRange(pin);
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
    _checkPinRange(pin);
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
    _checkPinRange(pin);
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
//  gpio.setTrigger(17, Trigger.both);
/// gpio.setPin(4, gpio.getPin(17));
/// while (true) {
///   var value = gpio.waitFor(17, -1);
///   gpio.setPin(4, value);
/// }
/// ```
class SysfsGPIO extends _GPIOBase implements GPIO {
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
  SysfsGPIO([int maxPins = 54]): super(maxPins) {
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
    _tracked = new List<File>(_maxPins);
    for (int pin = 0; pin < _maxPins; pin++) {
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
    _checkPinRange(pin);
    if (!isTracked(pin)) throw 'Pin $pin is not tracked';
  }

  /// Returns a list with the pins currently tracked.
  List tracked() {
    var result = [];
    for (int pin = 0; pin < _maxPins; pin++) {
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

  /// Waits for a transition on the [pin] within the timeout [timeout].
  ///
  /// Specifying a negative value in `timeout` means an infinite timeout.
  ///
  /// Returns the value of `pin` after the transition, or `null` of a
  /// timeout occurred.
  bool waitFor(int pin, int timeout) {
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

    var pollfd = new ForeignMemory.allocated(pollfdSize);

    // Setup the pollfd structure.
    pollfd.setUint32(pollfdFdOffset, _tracked[pin].fd);
    pollfd.setUint16(pollfdEventsOffset, pollpriFlag);
    pollfd.setUint16(pollfdReventsOffset, 0);
    var rc = _poll.icall$3Retry(pollfd, 1, timeout);
    pollfd.free();
    if (rc < 0) throw "poll failed";
    return getPin(pin);
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
    _checkPinRange(pin);
    // If already exported do nothing.
    if (isTracked(pin)) return;
    _exportUnexport(true, pin);
    _track(pin);  // This is now tracked.
  }

  void unexportPin(int pin) {
    _checkPinRange(pin);
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
