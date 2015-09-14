// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

import 'package:i2c/i2c.dart';
import 'package:i2c/devices/hts221.dart';

const int slaveId = 0x12;

class I2CBusAddressMock implements I2CBusAddress {
  int get bus => 0;
  I2CBus open() => new I2CBusMock();
  noSuchMethod(_) => throw 1;
}

/// I2C device connected to a I2C bus.
class I2CBusMock implements I2CBus {
  int readCount = 0;

  int readByte(int slave, int register) {
    // Initially all the calibration registers are read.
    Expect.equals(0x30 + readCount, register);
    readCount++;
    return 0;
  }

  void writeByte(int slave, int register, int value) {
    // Read all configuration values.
    Expect.equals(16, readCount);

    // Power on.
    Expect.equals(slaveId, slave);
    Expect.equals(0x20, register);
    Expect.equals(0x85, value);
  }

  noSuchMethod(_) => throw 1;
}

main() {
  var address = new I2CBusAddressMock();
  var bus = address.open();
  var device = new I2CDevice(slaveId, bus);
  var hts221 = new HTS221(device);

  // Test the power on sequence.
  hts221.powerOn();
}
