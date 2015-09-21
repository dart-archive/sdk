// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:gpio/gpio.dart';

main(List<String> args) {
  const int led = 4;
  const int button = 17;

  // Un-comment calling one of the samples.

  //testMemoryMapped(led, button);
  //testMemoryMappedPullUpPullDown(27);
  //testSysfs(led, button);
  //testSysfsWithTimeout(led, button);
}

// Use memory mapped GPIO to turn on the led when the button is pressed.
void testMemoryMapped(int led, int button) {
  PiMemoryMappedGPIO gpio = new PiMemoryMappedGPIO();
  gpio.setMode(led, Mode.output);
  gpio.setMode(button, Mode.input);
  while (true) {
    gpio.setPin(led, !gpio.getPin(button));
  }
}

void testMemoryMappedPullUpPullDown(int pin) {
  PiMemoryMappedGPIO gpio = new PiMemoryMappedGPIO();
  gpio.setMode(pin, Mode.input);
  gpio.setPullUpDown(pin, PullUpDown.pullDown);
  print('With pull-down: ${gpio.getPin(pin)}');
  gpio.setPullUpDown(pin, PullUpDown.pullUp);
  print('With pull-up: ${gpio.getPin(pin)}');
  gpio.setPullUpDown(pin, PullUpDown.pullDown);
  print('With pull-down: ${gpio.getPin(pin)}');
  gpio.setPullUpDown(pin, PullUpDown.pullUp);
  print('With pull-up: ${gpio.getPin(pin)}');
  gpio.setPullUpDown(pin, PullUpDown.floating);
  print('With floating: ${gpio.getPin(pin)}');
}

// Use sysfs GPIO to turn on the led when the button is pressed.
//
// This code is using a tight loop.
void testSysfs(int led, int button) {
  SysfsGPIO gpio = new SysfsGPIO();
  gpio.exportPin(led);
  gpio.exportPin(button);
  print('Tracking: ${gpio.tracked()}');

  gpio.setMode(led, Mode.output);
  gpio.setMode(button, Mode.input);
  gpio.setTrigger(button, Trigger.both);
  gpio.setPin(led, !gpio.getPin(button));
  while (true) {
    var value = gpio.waitFor(button, -1);
    gpio.setPin(led, !value);
  }
}

// Use sysfs GPIO to turn on the led when the button is pressed.
//
// This code is waiting to the button state to change.
void testSysfsWithTimeout(int led, int button) {
  SysfsGPIO gpio = new SysfsGPIO();
  gpio.exportPin(led);
  gpio.exportPin(button);
  print('Tracking: ${gpio.tracked()}');

  gpio.setMode(led, Mode.output);
  gpio.setMode(button, Mode.input);
  gpio.setTrigger(button, Trigger.both);
  gpio.setPin(led, !gpio.getPin(button));
  while (true) {
    var value = gpio.waitFor(button, 1000);
    print('Wait timeout');
    gpio.setPin(led, !value);
  }
}
