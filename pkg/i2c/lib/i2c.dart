// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// I2C support for Linux.
///
/// Currently this has only been tested with a Raspberry Pi 2.
///
/// The following sample code show how to access the HTS221 humidity and
/// temperature sensor and the LPS25H preassure sensor on a Raspberry Pi Sense
/// HAT.
///
/// ```
/// import 'package:i2c/i2c.dart';
/// import 'package:i2c/devices/hts221.dart';
/// import 'package:i2c/devices/lps25h.dart';
///
/// main() {
///   // The Raspberry Pi 2 has I2C bus 1.
///   var busAddress = new I2CBusAddress(1);
///   var bus = busAddress.open();
///
///   // Connect to the two devices.
///   var hts221 = new HTS221(new I2CDevice(0x5f, bus));
///   var lps25h = new LPS25H(new I2CDevice(0x5c, bus));
///   hts221.powerOn();
///   lps25h.powerOn();
///   while (true) {
///     print('Temperature: ${hts221.readTemperature()}');
///     print('Humidity: ${hts221.readHumidity()}');
///     print('Pressure: ${lps25h.readPressure()}');
///     io.sleep(1000);
///   }
/// }
/// ```
library i2c;

import 'dart:fletch';
import 'dart:fletch.ffi';
import 'dart:fletch.io' as io;

import 'src/process_object.dart';

// Foreign functions used.
final ForeignFunction _open = ForeignLibrary.main.lookup('open');
final ForeignFunction _close = ForeignLibrary.main.lookup('close');
final ForeignFunction _ioctl = ForeignLibrary.main.lookup('ioctl');

/// Address of an I2C bus.
///
/// An I2C bus is addressed using the bus number.
class I2CBusAddress {
  final int bus;

  /// Create an I2CBusAddress for I2C bus number [bus].
  const I2CBusAddress(this.bus);

  /// Open the I2C bus addressed by this address.
  I2CBus open() => new I2CBus(this);
}

/// I2C device connected to a I2C bus.
class I2CDevice {
  /// Slave address of this device.
  final int address;
  final I2CBus _bus;

  /// Bus number of the bus this device is connected to.
  int get bus => _bus.bus;

  /// Create a I2C device with address [address] on the I2C bus [bus].
  const I2CDevice(this.address, this._bus);

  /// Read a byte from register [register].
  int readByte(int register) => _bus.readByte(address, register);

  /// Write the byte [value] to register [register].
  void writeByte(int register, int value) {
    _bus.writeByte(address, register, value);
  }
}

/// I2C bus connection.
///
/// Each I2C bus is identified by an [I2CBusAddress].
class I2CBus {
  // From /usr/include/x86_64-linux-gnu/bits/fcntl-linux.h.
  static const _oRDWR = 02;  // O_RDWR

  /// Bus number of this I2C bus.
  final int bus;
  final ProcessObject _busObject;

  const I2CBus._(this.bus, this._busObject);

  factory I2CBus(I2CBusAddress address) {
    var fd = _openDevice(address.bus);
    var busObject = new ProcessObject((fd) => new _I2CBusImpl(fd), fd);
    return new I2CBus._(address.bus, busObject);
  }

  static int _openDevice(int bus) {
    var fileName = new ForeignMemory.fromStringAsUTF8('/dev/i2c-$bus');
    var fd;
    try {
      fd = _open.icall$2Retry(fileName, _oRDWR);
      if (fd < 0) {
        throw new I2CException('Failed to open $fileName', Foreign.errno);
      }
    } finally {
      fileName.free();
    }
    return fd;
  }

  bool get hasI2CFeatures {
    return (supportedFunctions() & _I2CBusImpl.I2C_FUNC_I2C) != 0;
  }

  bool get has10BitAddresses {
    return (supportedFunctions() & _I2CBusImpl.I2C_FUNC_10BIT_ADDR) != 0;
  }

  int supportedFunctions() => _busObject.run((bus) => bus.supportedFunctions());

  /// Read one byte from register [register] on slave device [slave].
  int readByte(int slave, int register) {
    return _busObject.run((bus) => bus.readByte(slave, register));
  }

  /// Wite one byte to register [register] on slave device [slave].
  void writeByte(int slave, int register, int value) {
    return _busObject.run((bus) => bus.writeByte(slave, register, value));
  }

  /// Write one byte to register [register] on slave device [slave].
  void close() => _busObject.run((bus) => bus.close());

  toString() => 'I2CBus $bus';
}

/// Exceptions thrown by I2C.
class I2CException implements Exception {
  /// Exception message.
  final String message;
  /// OS error number if any.
  final int errno;
  const I2CException(this.message, [this.errno = 0]);
  String toString() {
    if (errno == null) return message;
    return '$message (error ${errno})';
  }
}

// Implementation class used in the process running the I2C bus.
class _I2CBusImpl {
  // Constants from /usr/include/linux/i2c-dev.h
  static const I2C_FUNC_I2C                    = 0x00000001;
  static const I2C_FUNC_10BIT_ADDR             = 0x00000002;
  static const I2C_FUNC_PROTOCOL_MANGLING      = 0x00000004;
  static const I2C_FUNC_SMBUS_PEC              = 0x00000008;
  static const I2C_FUNC_NOSTART                = 0x00000010;
  static const I2C_FUNC_SMBUS_BLOCK_PROC_CALL  = 0x00008000;
  static const I2C_FUNC_SMBUS_QUICK            = 0x00010000;
  static const I2C_FUNC_SMBUS_READ_BYTE        = 0x00020000;
  static const I2C_FUNC_SMBUS_WRITE_BYTE       = 0x00040000;
  static const I2C_FUNC_SMBUS_READ_BYTE_DATA   = 0x00080000;
  static const I2C_FUNC_SMBUS_WRITE_BYTE_DATA  = 0x00100000;
  static const I2C_FUNC_SMBUS_READ_WORD_DATA   = 0x00200000;
  static const I2C_FUNC_SMBUS_WRITE_WORD_DATA  = 0x00400000;
  static const I2C_FUNC_SMBUS_PROC_CALL        = 0x00800000;
  static const I2C_FUNC_SMBUS_READ_BLOCK_DATA  = 0x01000000;
  static const I2C_FUNC_SMBUS_WRITE_BLOCK_DATA = 0x02000000;
  static const I2C_FUNC_SMBUS_READ_I2C_BLOCK   = 0x04000000;
  static const I2C_FUNC_SMBUS_WRITE_I2C_BLOCK  = 0x08000000;

  static const I2C_RETRIES = 0x0701;
  static const I2C_TIMEOUT = 0x0702;
  static const I2C_SLAVE   = 0x0703;
  static const I2C_TENBIT  = 0x0704;
  static const I2C_FUNCS   = 0x0705;
  static const I2C_RDWR    = 0x0707;
  static const I2C_PEC     = 0x0708;
  static const I2C_SMBUS   = 0x0720;

  static const I2C_SMBUS_BLOCK_MAX     = 32;
  static const I2C_SMBUS_I2C_BLOCK_MAX = 32;

  static const I2C_SMBUS_READ  = 1;
  static const I2C_SMBUS_WRITE = 0;

  static const I2C_SMBUS_QUICK            = 0;
  static const I2C_SMBUS_BYTE             = 1;
  static const I2C_SMBUS_BYTE_DATA        = 2;
  static const I2C_SMBUS_WORD_DATA        = 3;
  static const I2C_SMBUS_PROC_CALL        = 4;
  static const I2C_SMBUS_BLOCK_DATA       = 5;
  static const I2C_SMBUS_I2C_BLOCK_BROKEN = 6;
  static const I2C_SMBUS_BLOCK_PROC_CALL  = 7;
  static const I2C_SMBUS_I2C_BLOCK_DATA   = 8;

  // File descriptor for the opened I2C device.
  final int _fd;

  // Bits determining the functions available. Cached after the first call
  // to `supportedFunctions`.
  int _funcs;

  _I2CBusImpl(this._fd);

  void _selectSlave(int slave) {
    int err = _ioctl.icall$3Retry(_fd, I2C_SLAVE, slave);
    if (err < 0) {
      throw new I2CException('Failed to select slave', Foreign.errno);
    }
  }

  // Allocate memory for 'union i2c_smbus_data'.
  //
  //   union i2c_smbus_data {
  //     __u8 byte;
  //     __u16 word;
  //     __u8 block[I2C_SMBUS_BLOCK_MAX + 2];
  //   };
  _allocateData() => new ForeignMemory.allocated(34);

  // Allocate memory for 'struct i2c_smbus_ioctl_data'.
  //
  //   struct i2c_smbus_ioctl_data {
  //     char read_write;
  //     __u8 command;
  //     int size;
  //     union i2c_smbus_data *data;
  //   };
  _allocateIoctlData(
      int readWrite, int register, int transactionType, ForeignMemory data) {
    var args = new ForeignMemory.allocated(12);
    try {
      args.setUint8(0, readWrite);
      args.setUint8(1, register);
      args.setInt32(4, transactionType);
      args.setUint32(8, data.address);
    } catch (e) {
      args.free();
      rethrow;
    }
    return args;
  }

  void _smBusAccess(
      int readWrite, int register, int transactionType, ForeignMemory data) {
    var args = _allocateIoctlData(readWrite, register, transactionType, data);
    try {
      int err = _ioctl.icall$3Retry(_fd, I2C_SMBUS, args);
      if (err < 0) {
        throw new I2CException('Failed to access bus', Foreign.errno);
      }
    } finally {
      args.free();
    }
  }

  // Read the supported functions.
  int supportedFunctions() {
    if (_funcs == null) {
      var funcs = new ForeignMemory.allocated(4);
      try {
        int rc = _ioctl.icall$3Retry(_fd, I2C_FUNCS, funcs);
        _funcs = funcs.getUint32(0);
      } finally {
        funcs.free();
      }
    }
    return _funcs;
  }

  // Read one byte
  int readByte(int slave, int register) {
    _selectSlave(slave);
    var result;
    var data = _allocateData();
    try {
      _smBusAccess(I2C_SMBUS_READ, register, I2C_SMBUS_BYTE_DATA, data);
      result = data.getUint8(0);
    } finally {
      data.free();
    }
    return result;
  }

  // Write one byte
  void writeByte(int slave, int register, int value) {
    _selectSlave(slave);
    var data = _allocateData();
    try {
      data.setUint8(0, value);
      _smBusAccess(I2C_SMBUS_WRITE, register, I2C_SMBUS_BYTE_DATA, data);
    } finally {
      data.free();
    }
  }

  // Close the connection to the I2C bus freeing up system resources.
  void close() {
    _close.icall$1Retry(_fd);
  }
}
