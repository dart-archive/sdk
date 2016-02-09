// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// A small buzzer example illustrating both input and output GPIO pins.
//
// For breadboard layout and connections to the Pi, see:
// https://storage.googleapis.com/dartino-archive/images/buzzer-schematic.png

import 'package:gpio/gpio.dart';
import 'package:raspberry_pi/raspberry_pi.dart';

main() {
  // GPIO pin constants.
  Pin buttonPin = RaspberryPiPin.GPIO16;
  Pin speakerPin = RaspberryPiPin.GPIO21;

  // Initialize Raspberry Pi and use the memory mapped GPIO.
  RaspberryPi pi = new RaspberryPi();
  RaspberryPiMemoryMappedGpio gpio = pi.memoryMappedGpio;
  GpioOutputPin speaker = gpio.initOutput(speakerPin);
  GpioInputPin button = gpio.initInput(buttonPin);

  // Map state of button to speaker in a continuous loop.
  while (true) {
    speaker.state = button.state;
  }
}
