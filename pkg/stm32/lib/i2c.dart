// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.i2c;

import 'dart:dartino';
import 'dart:dartino.ffi';
import 'dart:dartino.os';
import 'dart:typed_data';

import 'package:i2c/i2c.dart';

final _i2c_open = new Ffi('i2c_open', Ffi.returnsInt32, [Ffi.pointer]);
final _i2c_is_device_ready = new Ffi('i2c_is_device_ready',
  Ffi.returnsInt32, [Ffi.int32, Ffi.int32]);
final _i2c_request_read_register = new Ffi('i2c_request_read_register',
  Ffi.returnsInt32, [Ffi.int32, Ffi.int32, Ffi.int32, Ffi.pointer, Ffi.int32]);
final _i2c_request_write_register = new Ffi('i2c_request_write_register',
  Ffi.returnsInt32, [Ffi.int32, Ffi.int32, Ffi.int32, Ffi.pointer, Ffi.int32]);
final _i2c_request_read = new Ffi('i2c_request_read',
  Ffi.returnsInt32, [Ffi.int32, Ffi.int32, Ffi.pointer, Ffi.int32]);
final _i2c_request_write = new Ffi('i2c_request_write',
  Ffi.returnsInt32, [Ffi.int32, Ffi.int32, Ffi.pointer, Ffi.int32]);
final _i2c_acknowledge_result = new Ffi('i2c_acknowledge_result',
  Ffi.returnsInt32, [Ffi.int32]);

/// I2C bus on ST device.
class I2CBusSTM implements I2CBus {
  final String _deviceName;
  final int _handle;
  final Channel _channel = new Channel();
  Port _port;
  final Uint8List oneByteBuffer = new Uint8List(1);

  // Device manager event flags.
  static const int _RESULT_READY_FLAG = 1 << 0;
  static const int _RESULT_ERROR_FLAG = 1 << 1;

  I2CBusSTM._(this._deviceName, this._handle) {
    _port = new Port(_channel);
  }

  factory I2CBusSTM(String deviceName) {
    int handle;
    var foreignDeviceName = new ForeignMemory.fromStringAsUTF8(deviceName);
    try {
      handle = _i2c_open([foreignDeviceName]);
      if (handle == -1) {
        throw new I2CException("Cannot open I2C bus");
      }
    } finally {
      foreignDeviceName.free();
    }
    return new I2CBusSTM._(deviceName, handle);
  }

  /// Check if the [slave] device is ready.
  bool isDeviceReady(int slave) {
    int rc = _i2c_is_device_ready([_handle, slave]);
    return rc == 0;
  }

  /// Read one byte from register [register] on slave device [slave].
  int readByte(int slave, int register) {
    int rc = _readRegisterBytes(slave, register, oneByteBuffer);
    if (rc == 1) {
      return oneByteBuffer[0];
    } else {
      throw new I2CException("Read error", rc);
    }
  }

  /// Wite one byte to register [register] on slave device [slave].
  void writeByte(int slave, int register, int value) {
    oneByteBuffer[0] = value;
    int rc = _writeRegisterBytes(slave, register, oneByteBuffer);
    if (rc != 1) {
      throw new I2CException("Write error", rc);
    }
  }

  /// Read bytes from slave device [slave].
  void receive(int slave, ByteBuffer buffer, int size) {
    var foreignBuffer = _getForeign(buffer);
    var rc = _i2c_request_read([_handle, slave, foreignBuffer, size]);
    if (rc != 0) {
      throw new I2CException("Read error", rc);
    }

    eventHandler.registerPortForNextEvent(
        _handle, _port, _RESULT_READY_FLAG | _RESULT_ERROR_FLAG);
    _channel.receive();
    rc = _i2c_acknowledge_result([_handle]);
    if (rc != 0) {
      throw new I2CException("Read error", rc);
    }
  }

  /// Write bytes to slave device [slave].
  void transmit(int slave, ByteBuffer buffer, int size) {
    var foreignBuffer = _getForeign(buffer);
    var rc = _i2c_request_write([_handle, slave, foreignBuffer, size]);
    if (rc != 0) {
      throw new I2CException("Write error", rc);
    }

    eventHandler.registerPortForNextEvent(
        _handle, _port, _RESULT_READY_FLAG | _RESULT_ERROR_FLAG);
    _channel.receive();
    rc = _i2c_acknowledge_result([_handle]);
    if (rc != 0) {
      throw new I2CException("Write error", rc);
    }
  }

  /// Read bytes from register [register] on slave device
  /// [slave]. Returns the number of bytes read. Returns -1 on error.
  int _readRegisterBytes(int slave, int register, Uint8List buffer) {
    var foreignBuffer = _getForeign(buffer.buffer);
    var rc = _i2c_request_read_register([
        _handle, slave, register, foreignBuffer, buffer.length]);
    if (rc != 0) return rc;

    eventHandler.registerPortForNextEvent(
        _handle, _port, _RESULT_READY_FLAG | _RESULT_ERROR_FLAG);
    _channel.receive();
    rc = _i2c_acknowledge_result([_handle]);
    return rc == 0 ? buffer.length : rc;
  }

  /// Write bytes to register [register] on slave device
  /// [slave]. Returns the number of bytes written. Returns -1 on error.
  int _writeRegisterBytes(int slave, int register, Uint8List buffer) {
    var foreignBuffer = _getForeign(buffer.buffer);
    var rc = _i2c_request_write_register([
        _handle, slave, register, foreignBuffer, buffer.length]);
    if (rc != 0) return rc;

    eventHandler.registerPortForNextEvent(
        _handle, _port, _RESULT_READY_FLAG | _RESULT_ERROR_FLAG);
    _channel.receive();
    rc = _i2c_acknowledge_result([_handle]);
    return rc == 0 ? buffer.length : rc;
  }

  ForeignMemory _getForeign(ByteBuffer buffer) {
    var b = buffer;
    return b.getForeign();
  }

  toString() => 'I2CBusSTM $_deviceName';
}
