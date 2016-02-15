// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// A door bell example. Illustrates watching GPIO pin state with events.
//
// For breadboard layout and connections to the Pi, see:
// https://storage.googleapis.com/dartino-archive/images/buzzer-schematic.png

import 'dart:dartino';

import 'package:gpio/gpio.dart';
import 'package:raspberry_pi/raspberry_pi.dart';

main() {
  // GPIO pin constants.
  Pin buttonPin = const SysfsPin(16);
  Pin speakerPin = const SysfsPin(21);

  // Initialize Raspberry Pi and use the Sysfs GPIO.
  RaspberryPi pi = new RaspberryPi();
  SysfsGpio gpio = pi.sysfsGpio;

  // Initialize pins.
  gpio.exportPin(speakerPin);
  GpioOutputPin speaker = gpio.initOutput(speakerPin);
  gpio.exportPin(buttonPin);
  GpioInputPin button =
      gpio.initInput(buttonPin, trigger: GpioInterruptTrigger.both);

  // Continuously monitor button.
  while (true) {
    // Wait for button press.
    button.waitFor(true, -1);

    // Sound bell.
    for (var i = 1; i <= 3; i++) {
      speaker.state = true;
      sleep(100);
      speaker.state = false;
      sleep(500);
    }
  }
}
