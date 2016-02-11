// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// The 'hello world' of embedded: Blinking an LED. Uses the on-board
// Raspberry Pi 2 activity LED.

import 'dart:dartino';

import 'package:gpio/gpio.dart';
import 'package:raspberry_pi/raspberry_pi.dart';

main() {
  // Initialize Raspberry Pi and configure the activity LED to be GPIO
  // controlled.
  RaspberryPi pi = new RaspberryPi();
  pi.leds.activityLED.setMode(OnboardLEDMode.gpio);

  // Turn LED on and off in a continuous loop.
  while (true) {
    pi.leds.activityLED.on();
    sleep(500);
    pi.leds.activityLED.off();
    sleep(500);
  }
}
