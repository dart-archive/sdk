// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// A door bell example. Illustrates watching GPIO pin state with events.
//
// For breadboard layout and connections to the Pi, see:
// https://storage.googleapis.com/fletch-archive/images/buzzer-schematic.png

import 'package:gpio/gpio.dart';
import 'package:os/os.dart';

main() {
  // GPIO pin constants.
  const int button = 16;
  const int speaker = 21;

  // Initialize GPIO and speaker pin.
  SysfsGPIO gpio = new SysfsGPIO();
  gpio.exportPin(speaker);
  gpio.setMode(speaker, Mode.output);

  // Initialize button pin. Enable a button down trigger.
  gpio.exportPin(button);
  gpio.setMode(button, Mode.input);
  gpio.setTrigger(button, Trigger.falling);

  // Continuously monitor button.
  while (true) {
    // Wait for button press.
    // TODO(mit-mit): Update to new event API when it lands.
    gpio.waitFor(button, -1);

    // Sound bell
    for (var i = 1; i <= 3; i++) {
      gpio.setPin(speaker, true);
      sleep(100);
      gpio.setPin(speaker, false);
      sleep(500);
    }
  }
}
