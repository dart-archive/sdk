// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

import 'package:i2c/i2c.dart';
import 'package:i2c/devices/lsm9ds1.dart';

const int slaveIdAG = 0x12;
const int slaveIdM = 0x13;

class I2CBusAddressMock implements I2CBusAddress {
  int get bus => 0;
  I2CBus open() => new I2CBusMock();
  noSuchMethod(_) => throw 1;
}

/// I2C device connected to a I2C bus.
class I2CBusMock implements I2CBus {
  int writeCount = 0;
  int readCount = 0;

  int readByte(int slave, int register) {
    Expect.equals(12, writeCount);
    if (readCount < 6) {
      Expect.equals(slaveIdAG, slave);
    } else if (readCount < 12) {
      Expect.equals(slaveIdM, slave);
    } else if (readCount < 18) {
      Expect.equals(slaveIdAG, slave);
    } else {
      Expect.fail('unexpected');
    }
    readCount++;
    return 0;
  }

  void writeByte(int slave, int register, int value) {
    Expect.equals(0, readCount);
    Expect.isTrue(slave == slaveIdAG || slave == slaveIdM);
    writeCount++;
  }

  noSuchMethod(_) => throw 1;
}

main() {
  var address = new I2CBusAddressMock();
  var bus = address.open();
  var deviceAG = new I2CDevice(slaveIdAG, bus);
  var deviceM = new I2CDevice(slaveIdM, bus);
  var lsm9ds1 = new LSM9DS1(accelGyroDevice: deviceAG, magnetDevice: deviceM);
  lsm9ds1.powerOn();
  lsm9ds1.readAccel();
  lsm9ds1.readMagnet();
  lsm9ds1.readGyro();

  Expect.equals(12, bus.writeCount);
  Expect.equals(18, bus.readCount);
}
