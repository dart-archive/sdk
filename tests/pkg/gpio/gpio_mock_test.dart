// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
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
  var gpio = new MockGpio();
  Expect.equals(MockGpio.defaultPins, gpio.pins);
  var gpioPins = [];
  for (int i = 0; i < gpio.pins; i++) {
    var pin = new MockGpioPin(i);
    gpioPins.add(gpio.initOutput(pin));
  }
  for (int i = 0; i < gpio.pins; i++) {
    Expect.isFalse(gpioPins[i].state);
    gpioPins[i].state = true;
    Expect.isTrue(gpioPins[i].state);
  }
}

void test2() {
  void checkRange(gpio, pins) {
    bool isRangeError(e) => e is RangeError;
    //Expect.throws(() => gpio.getPin(-1), isRangeError);
    Expect.throws(() => gpio.initOutput(new MockGpioPin(-1)), isRangeError);
    Expect.throws(() => gpio.initInput(new MockGpioPin(-1)), isRangeError);
    Expect.throws(
        () => gpio.initOutput(new MockGpioPin(pins + 1)), isRangeError);
    Expect.throws(
        () => gpio.initInput(new MockGpioPin(pins + 1)), isRangeError);
  }
  checkRange(new MockGpio(), MockGpio.defaultPins);
  checkRange(new MockGpio(pins: 1), 1);
  checkRange(new MockGpio(pins: 2), 2);
}

void test3() {
  int getCount = 0;
  int setCount = 0;

  bool getPin(Pin pin) {
    getCount++;
    if (getCount == 1) {
      throw new _MyException();
    } else {
      return true;
    }
  }

  void setPin(Pin pin, bool value) {
    setCount++;
    if (setCount == 1) {
      throw new _MyException();
    }
  }

  var gpio = new MockGpio();
  gpio.registerGetPin(getPin);
  gpio.registerSetPin(setPin);
  var gpioPin = gpio.initOutput(new MockGpioPin(1));

  Expect.throws(() => gpioPin.state, (e) => e is _MyException);
  Expect.throws(() => gpioPin.state = false, (e) => e is _MyException);
  Expect.isTrue(gpioPin.state);
  gpioPin.state = false;
  Expect.equals(2, getCount);
  Expect.equals(2, setCount);
}

class _MyException implements Exception {}
