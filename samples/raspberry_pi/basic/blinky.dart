// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// The 'hello world' of embedded: Blinking an LED. Uses the on-board
// Raspberry Pi 2 activity LED.

import 'package:gpio/gpio.dart';
import 'package:os/os.dart';

main() {
  // Constant for the Raspberry Pi 2 onboard green LED.
  const int led = 47;

  // Initialize gpio and configure the pin.
  PiMemoryMappedGPIO gpio = new PiMemoryMappedGPIO();
  gpio.setMode(led, Mode.output);

  // Turn LED on and off in a continuous loop.
  while (true) {
    gpio.setPin(led, true);
    sleep(500);
    gpio.setPin(led, false);
    sleep(500);
  }
}
