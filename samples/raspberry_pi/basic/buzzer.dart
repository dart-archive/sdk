// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// A small buzzer example illustrating both input and output GPIO pins.
//
// For breadboard layout and connections to the Pi, see:
// https://storage.googleapis.com/fletch-archive/images/buzzer-schematic.png

import 'package:gpio/gpio.dart';
import 'package:raspberry_pi/raspberry_pi.dart';

main() {
  // GPIO pin constants.
  const int button = 16;
  const int speaker = 21;

  // Initialize Raspberry Pi and configure the pins.
  RaspberryPi pi = new RaspberryPi();
  PiMemoryMappedGPIO gpio = pi.memoryMappedGPIO;
  gpio.setMode(button, Mode.input);
  gpio.setMode(speaker, Mode.output);

  // Map state of button to speaker in a continuous loop.
  while (true) {
    bool buttonState = gpio.getPin(button);
    gpio.setPin(speaker, buttonState);
  }
}
