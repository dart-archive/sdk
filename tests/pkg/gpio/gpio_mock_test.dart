// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';
import 'package:gpio/gpio.dart';
import 'package:gpio/gpio_mock.dart';

main() {
  test1();
  test2();
  test3();
}

void test1() {
  var gpio = new MockGPIO();
  Expect.equals(GPIO.defaultPins, gpio.pins);
  for (int i = 0; i < gpio.pins; i++) {
    Expect.isFalse(gpio.getPin(i));
    gpio.setPin(i, true);
    Expect.isTrue(gpio.getPin(i));
  }
}

void test2() {
  void checkRange(gpio, pins) {
    bool isRangeError(e) => e is RangeError;
    Expect.throws(() => gpio.getPin(-1), isRangeError);
    Expect.throws(() => gpio.getPin(pins + 1), isRangeError);
    Expect.throws(() => gpio.setPin(-1, true), isRangeError);
    Expect.throws(() => gpio.setPin(pins + 1, true), isRangeError);
    Expect.throws(() => gpio.getMode(-1), isRangeError);
    Expect.throws(() => gpio.getMode(pins + 1), isRangeError);
    Expect.throws(() => gpio.setMode(-1, Mode.output), isRangeError);
    Expect.throws(() => gpio.setMode(pins + 1, Mode.output), isRangeError);
  }
  checkRange(new MockGPIO(), GPIO.defaultPins);
  checkRange(new MockGPIO(1), 1);
  checkRange(new MockGPIO(2), 2);
}

void test3() {
  int getCount = 0;
  int setCount = 0;

  bool getPin(int pin) {
    getCount++;
    if (getCount == 1) {
      throw new _MyException();
    } else {
      return true;
    }
  }

  void setPin(int pin, bool value) {
    setCount++;
    if (setCount == 1) {
      throw new _MyException();
    }
  }

  var gpio = new MockGPIO();
  gpio.registerGetPin(getPin);
  gpio.registerSetPin(setPin);
  Expect.throws(() => gpio.getPin(1), (e) => e is _MyException);
  Expect.throws(() => gpio.setPin(1, false), (e) => e is _MyException);
  Expect.isTrue(gpio.getPin(1));
  gpio.setPin(1, false);
  Expect.equals(2, getCount);
  Expect.equals(2, setCount);
}

class _MyException implements Exception {}
