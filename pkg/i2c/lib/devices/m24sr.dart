// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// API for M24SR "Dynamic NFC/RFID tag" chip using the I2C bus.
library m24sr;

import 'dart:dartino';
import 'dart:typed_data';

import 'package:i2c/i2c.dart';

const _actionCompleted = 0x9000;

const _claDefault = 0x00;
const _claSt = 0xA2;

const _insSelectFile = 0xA4;
const _insUpdateBinary = 0xD6;
const _insReadBinary = 0xB0;

const _maskBlock = 0xC0;
const _maskIBlock = 0x00;
const _maskRBlock = 0x80;
const _maskSBlock = 0xC0;

const _statusByteCount = 5; // PCB, SW1, SW2, CRC1, CRC2

const _systemFileId = 0xE101;
const _ccFileId = 0xE103;

const _i2cTimeoutMs = 200;

class _Apdu {
  // Serialize a command APDU. Format:
  // PCB | CLA | INS | P1 | P2 | LC | <payload> | LE | CRC1 | CRC2
  static ByteData buildCommand(
      int blockNumber, int type, int instruction, int parameter,
      [Uint8List payload, int expectedResponseBytes]) {
    int bufferSize = 7;
    int payloadSize = 0;
    if (payload != null) {
      payloadSize = payload.length;
      if (payloadSize > 255) {
        throw new ArgumentError("Payload too large");
      }
      bufferSize += 1 + payloadSize;
    }
    if (expectedResponseBytes != null) {
      bufferSize++;
    }
    ByteData data = new ByteData(bufferSize);

    var offset = 0;
    data.setUint8(offset++, 0x02 | blockNumber);
    data.setUint8(offset++, type);
    data.setUint8(offset++, instruction);
    int p1 = parameter >> 8 & 0xFF;
    int p2 = parameter & 0xFF;
    data.setUint8(offset++, p1);
    data.setUint8(offset++, p2);
    if (payload != null) {
      data.setUint8(offset++, payloadSize);
      for (int b in payload) {
        data.setUint8(offset++, b);
      }
    }
    if (expectedResponseBytes != null) {
      data.setUint8(offset++, expectedResponseBytes);
    }

    int crc = computeCrc(data.buffer, offset);
    data.setUint8(offset++, crc & 0xFF);
    data.setUint8(offset++, crc >> 8 & 0xFF);

    return data;
  }

  static int _updateCrc(int oldCrc, int data) {
    data = (data ^ (oldCrc & 0x00FF)) & 0x00FF;
    data = (data ^ ((data << 4) & 0x00FF)) & 0x00FF;
    return ((oldCrc >> 8) ^ (data << 8) ^ (data << 3) ^ (data >> 4)) & 0xFFFF;
  }

  // Compute CRC16 checksum of data. See ISO 14443-3.
  static int computeCrc(ByteBuffer data, int size) {
    var result = data.asUint8List(0, size).fold(0x6363, _updateCrc);
    return result;
  }

  static void verifyStatus(ByteData data, int size) {
    if (size < _statusByteCount) {
      throw new NfcException('Reply too short');
    }
    int crcResidue = computeCrc(data.buffer, size);
    if (crcResidue != 0) {
      // CRC check failed, try verifying as error response.
      if (size > _statusByteCount) {
        verifyStatus(data, _statusByteCount);
      }
      throw new NfcException('Incorrect checksum');
    }

    // CRC check passed, extract status code.
    int status = _getUint16BigEndian(data, size - 4);
    if (status != _actionCompleted) {
      throw new NfcException.fromStatus(status);
    }
  }
}

int _getUint16BigEndian(ByteData data, int offset) =>
    data.getUint8(offset) << 8 | data.getUint8(offset + 1);

class NfcException implements Exception {
  final String _message;

  NfcException(this._message);

  factory NfcException.fromStatus(int status) {
    String message = 'Error: ${status.toRadixString(16)}';
    switch (status) {
      case 0x6280:
        message = 'File overflow';
        break;
      case 0x6282:
        message = 'End of file';
        break;
      case 0x6300:
        message = 'Password required';
        break;
      case 0x63C0:
        message = 'Incorrect password, no more attempts';
        break;
      case 0x63C1:
        message = 'Incorrect password, 1 more attempt';
        break;
      case 0x63C2:
        message = 'Incorrect password, 2 more attempts';
        break;
      case 0x6581:
        message = 'Update failed';
        break;
      case 0x6700:
        message = 'Wrong length';
        break;
      case 0x6981:
        message = 'Incompatible command';
        break;
      case 0x6982:
        message = 'No access';
        break;
      case 0x6984:
        message = 'Reference data not usable';
        break;
      case 0x6A80:
        message = 'Invalid lengths';
        break;
      case 0x6A82:
        message = 'File not found';
        break;
      case 0x6A84:
        message = 'File overflow';
        break;
      case 0x6A86:
        message = 'Incorrect parameters';
        break;
      case 0x6D00:
        message = 'Instruction not supported';
        break;
      case 0x6E00:
        message = 'Class not supported';
        break;
    }
    return new NfcException(message);
  }

  String toString() => _message;
}

class _CapabilityFile {
  static const int _fileSizeOffset = 0x00;
  static const int _mappingVersionOffset = 0x02;
  static const int _maxReadableBytesOffset = 0x03;
  static const int _maxWritableBytesOffset = 0x05;
  static const int _ndefTypeOffset = 0x07;
  static const int _ndefLengthOffset = 0x08;
  static const int _ndefFileIdOffset = 0x09;
  static const int _ndefMaxSizeOffset = 0x0B;
  static const int _ndefReadAccessOffset = 0x0D;
  static const int _ndefWriteAccessOffset = 0x0E;

  static const int _ccFileSize = 15;

  ByteData data;

  _CapabilityFile(this.data) {
    if (data.lengthInBytes != _ccFileSize) {
      throw new NfcException("Invalid capability file size");
    }
    if (fileSize != _ccFileSize) {
      throw new NfcException("Invalid capability file size");
    }
  }

  int get fileSize => _getUint16BigEndian(data, _fileSizeOffset);
  int get mappingVersion => data.getUint8(_mappingVersionOffset);
  int get maxReadableBytes =>
      _getUint16BigEndian(data, _maxReadableBytesOffset);
  int get maxWritableBytes =>
      _getUint16BigEndian(data, _maxWritableBytesOffset);
  int get ndefType => data.getUint8(_ndefTypeOffset);
  int get ndefLength => data.getUint8(_ndefLengthOffset);
  int get ndefFileId => _getUint16BigEndian(data, _ndefFileIdOffset);
  int get ndefMaxSize => _getUint16BigEndian(data, _ndefMaxSizeOffset);
  bool get ndefReadAccess => data.getUint8(_ndefReadAccess) == 0x00;
  bool get ndefWriteAccess => data.getUint8(_ndefWriteAccess) == 0x00;
}

class _M24SRSystemFile {
  static const int _fileSizeOffset = 0x00;
  static const int _i2cProtectOffset = 0x02;
  static const int _i2cWatchdogOffset = 0x03;
  static const int _gpoOffset = 0x04;
  static const int _stReservedOffset = 0x05;
  static const int _rfEnableOffset = 0x06;
  static const int _ndefFileNumberOffset = 0x07;
  static const int _uidOffset = 0x08;
  static const int _memorySizeOffset = 0x0F;
  static const int _productCodeOffset = 0x11;

  static const int _uidSize = 7;

  static const int _i2cPasswordNotNeeded = 0x00;
  static const int _i2cPasswordNeeded = 0x01;

  static const int _unlocked = 0x00;
  static const int _locked = 0x80;
  static const int _noReadAccess = 0xFE;
  static const int _noWriteAccess = 0xFF;

  static const int _minFileSize = 18;

  ByteData data;

  _M24SRSystemFile(this.data) {
    if (fileSize < _minFileSize) {
      throw new NfcException("System file too small");
    }
  }

  int get fileSize => _getUint16BigEndian(data, _fileSizeOffset);
  bool get i2cPasswordNeeded =>
      data.getUint8(_i2cProtectOffset) != _i2cPasswordNotNeeded;
  void set i2cPasswordNeeded(bool value) {
    data.setUint8(_i2cProtectOffset,
                  value ? _i2cPasswordNeeded : _i2cPasswordNotNeeded);
  }
  int get i2cWatchdog => data.getUint8(_i2cWatchdogOffset);
  void set i2cWatchdog(int value) {
    data.setUint8(_i2cWatchdogOffset, value);
  }
  int get gpo => data.getUint8(_gpoOffset);
  void set gpo(int value) {
    data.setUint8(_gpoOffset, value);
  }
  int get stReserved => data.getUint8(_stReservedOffset);
  int get rfEnable => data.getUint8(_rfEnableOffset);
  void set rfEnable(int value) {
    data.setUint8(_rfEnableOffset, value);
  }
  ByteData get uid =>
    new ByteData.view(data.buffer, data.offsetInBytes + _uidOffset,
                      _uidSize);
  int get memorySize => _getUint6BigEndian(data, _memorySizeOffset);
  int get productCode => data.getUint8(_productCodeOffset);
}

class M24SR {
  final I2CDevice _device;

  int _currentBlock = 0;
  int ndefFileId = 0;
  int ndefFileSize;
  int productCode;
  ByteData uid;

  /// Create a M24SR API on a I2C device.
  M24SR(this._device);

  Uint8List _toUint8List(List<int> data) => new Uint8List.fromList(data);
  ByteBuffer _toBuffer(List<int> data) => _toUint8List(data).buffer;

  void initialize() {
    openSession(force: true);
    selectApplication();
    var systemFile = _readSystemFile();
    productCode = systemFile.productCode;
    uid = systemFile.uid;
    var ccFile = _readCapabilityFile();
    ndefFileId = ccFile.ndefFileId;
    selectNdefFile();
    ndefFileSize = readFileLength();

    closeSession();
  }

  void openSession({bool force: false}) {
    int command = force ? 0x52 : 0x26;
    var data = _toBuffer([command]);
    _device.transmit(data, data.lengthInBytes);
    _pollI2C();
  }

  void closeSession() {
    // Magic: S-Block with deselect command in PCB.
    // Format: PCB | CRC1 | CRC2
    var data = _toBuffer([0xC2, 0xE0, 0xB4]);
    _device.transmit(data, data.lengthInBytes);
    _waitForAnswer();
    _receive(3);
  }

  void selectApplication() {
    var pData = _toUint8List([0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01]);
    _sendCommand(_claDefault, _insSelectFile, 0x0400, pData, 0);
    _waitForAnswer();
    var result = _receive(_statusByteCount);
    _Apdu.verifyStatus(result, _statusByteCount);
  }

  _M24SRSystemFile _readSystemFile() {
    selectFile(_systemFileId);
    var data = readFile();
    return new _M24SRSystemFile(data);
  }

  _CapabilityFile _readCapabilityFile() {
    selectFile(_ccFileId);
    var data = readFile();
    return new _CapabilityFile(data);
  }

  void selectNdefFile() {
    selectFile(ndefFileId);
  }

  ByteData readFile() {
    int fileSize = readFileLength();
    var result = new ByteData(fileSize);
    readBinary(0, result);
    return result;
  }

  void selectFile(int fileId) {
    var fileIdBuf = _toUint8List([(fileId >> 8) & 0xFF, fileId & 0xFF]);
    _sendCommand(_claDefault, _insSelectFile, 0x000C, fileIdBuf);
    _waitForAnswer();
    var result = _receive(_statusByteCount);
    _Apdu.verifyStatus(result, _statusByteCount);
  }

  int readFileLength() {
    var lengthBuf = new ByteData(2);
    readBinary(0, lengthBuf);
    return _getUint16BigEndian(lengthBuf, 0);
  }

  void readBinary(int offset, ByteData data) {
    _readBinary(_claDefault, offset, data);
  }

  void readSTBinary(int offset, ByteData data) {
    _readBinary(_claSt, offset, data);
  }

  void _readBinary(int channel, int offset, ByteData data) {
    final int length = data.lengthInBytes;
    _sendCommand(channel, _insReadBinary, offset, null, length);
    _waitForAnswer();
    var result = _receive(length + _statusByteCount);
    _Apdu.verifyStatus(result, length + _statusByteCount);

    int source = 1;
    int target = 0;
    while (target < length) {
      data.setUint8(target++, result.getUint8(source++));
    }
  }

  void updateBinary(int offset, Uint8List data) {
    _sendCommand(_claDefault, _insUpdateBinary, offset, data);
    _waitForAnswer();
    var result = _receive(_statusByteCount);
    if (result.getUint8(0) & _maskBlock == _maskSBlock) {
      if (_Apdu.computeCrc(result, 4) == 0) {
        // Send frame extension response.
        _sendFwtExtension(result.getUint8(1));
        return;
      }
      throw new NfcException("Invalid checksum");
    }
    _Apdu.verifyStatus(result, _statusByteCount);
  }

  void _sendFwtExtension(int fwtByte) {
    ByteData data = new ByteData(4);

    data.setUint8(0, 0xF2);
    data.setUint8(1, fwtByte);
    var crc = _Apdu.computeCrc(data.buffer, 2);
    data.setUint8(2, crc & 0xFF);
    data.setUint8(3, crc >> 8 & 0xFF);
    _device.transmit(data.buffer, 4);
    _waitForAnswer();
    var result = _receive(_statusByteCount);
    _Apdu.verifyStatus(result, _statusByteCount);
  }

  void _sendCommand(int type, int instruction, int parameter,
                    [Uint8List payload, int expectedResponseBytes]) {
    ByteData apdu = _Apdu.buildCommand(
        _currentBlock, type, instruction, parameter, payload,
        expectedResponseBytes);
    _currentBlock = _currentBlock == 1 ? 0 : 1;
    _pollI2C();
    _device.transmit(apdu.buffer, apdu.lengthInBytes);
  }

  // Receive response from device. Response APDU format:
  // PCB | <response data> | SW1 | SW2 | CRC1 | CRC2
  ByteData _receive(int size) {
    var result = new ByteData(size);
    _pollI2C();
    _device.receive(result.buffer, size);
    return result;
  }

  void _waitForAnswer() {
    // TODO(jakobr): Use GPIO/IRQ method instead of polling I2C.
    _pollI2C();
  }

  void _pollI2C() {
    // TODO(jakobr): Doesn't look like this is actually necessary. Keeping the
    // code here, in case it turns out to be.
    /*
    var timer = new Stopwatch();
    try {
      timer.start();
      if (_device.isReady()) {
        return;
      }
      while (timer.elapsedMilliseconds < _i2cTimeoutMs) {
        Fiber.yield();
        if (_device.isReady()) {
          return;
        }
      }
    } finally {
      timer.stop();
    }
    throw new NfcException("Timed out");
    */
  }

}
