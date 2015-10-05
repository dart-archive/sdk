// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// Remember those red running lights KITT had in Knight Rider?
// https://www.youtube.com/watch?v=Mo8Qls0HnWo
//
// This sample recreates those with a chain of LEDs running right and left:
// https://storage.googleapis.com/fletch-archive/images/knight-rider.mp4
//
// For breadboard layout and connections to the Pi, see:
// https://storage.googleapis.com/fletch-archive/images/k-r-schematic.png

import 'package:gpio/gpio.dart';
import 'package:raspberry_pi/raspberry_pi.dart';
import 'package:os/os.dart';

main() {
  // Initialize Raspberry Pi
  RaspberryPi pi = new RaspberryPi();

  // Array constant containing the GPIO pins of the connected LEDs.
  // You can add more LEDs simply by extending the list. Make sure
  // the pins are listed in the order the LEDs are connected.
  List<int> leds = [26, 19, 13, 6];

  // Initialize the lights controller class.
  Lights lights = new Lights(pi.memoryMappedGPIO, leds);
  lights.init();

  // Alternate between running left and right in a continuous loop.
  const int waitTime = 100;
  while (true) {
    lights.runLightLeft(waitTime);
    lights.runLightRight(waitTime);
  }
}

class Lights {
  final GPIO _gpio;
  final List<int> leds;

  Lights(this._gpio, this.leds);

  // Initializes GPIO and configures the pins.
  void init() {
    leds.forEach((pin) => _gpio.setMode(pin, Mode.output));
    leds.forEach((pin) => _gpio.setPin(pin, false));
  }

  // Iterates though the lights in increasing order, and sets the LEDs using
  // a helper function. Pauses [waitTime] milliseconds before returning.
  void runLightLeft(int waitTime) {
    for (int counter = 0; counter < leds.length; counter++) {
      _setLeds(counter);
      sleep(waitTime);
    }
  }

  // Iterates though the lights in decreasing order, and sets the LEDs using
  // a helper function. Pauses [waitTime] milliseconds before returning.
  void runLightRight(int waitTime) {
    for (int counter = leds.length - 1; counter >= 0; counter--) {
      _setLeds(counter);
      sleep(waitTime);
    }
  }

  // Sets LED [ledToEnable] to true, and all others to false.
  void _setLeds(int ledToEnable) {
    var state;

    for (int i = 0; i < leds.length; i++) {
      bool state = (i == ledToEnable);
      _gpio.setPin(leds[i], state);
    }
  }
}
