// Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// Remember those red running lights KITT had in Knight Rider?
// https://www.youtube.com/watch?v=Mo8Qls0HnWo
//
// This sample recreates those with a chain of LEDs running right and left:
// https://storage.googleapis.com/fletch-archive/images/knight-rider.mp4
//
// TODO: Add a schematics.
// For breadboard layout and connections to the STM32F746G Discovery board, see:
// https://storage.googleapis.com/fletch-archive/images/xxx.png

import 'dart:fletch';

import 'package:stm32f746g_disco/gpio.dart';
import 'package:stm32f746g_disco/stm32f746g_disco.dart';

main() {
  // Initialize STM32F746G Discovery board.
  STM32F746GDiscovery board = new STM32F746GDiscovery();

  // Array constant containing the GPIO pins of the connected LEDs.
  // You can add more LEDs simply by extending the list. Make sure
  // the pins are listed in the order the LEDs are connected.
  List<Pin> leds = [
      STM32F746GDiscovery.A1,
      STM32F746GDiscovery.A2,
      STM32F746GDiscovery.A3,
      STM32F746GDiscovery.A4];

  // Initialize the lights controller class.
  Lights lights = new Lights(board.gpio, leds);
  lights.init();

  // Alternate between running left and right in a continuous loop.
  const int waitTime = 100;
  while (true) {
    lights.runLightLeft(waitTime);
    lights.runLightRight(waitTime);
  }
}

class Lights {
  final Gpio _gpio;
  final List<Pin> leds;
  List<GpioOutputPin> gpioPins;

  Lights(this._gpio, this.leds);

  // Initializes all pins as output.
  void init() {
    gpioPins = leds.map((pin) => _gpio.initOutput(pin)).toList();
  }

  // Iterates though the lights in increasing order, and sets the LEDs using
  // a helper function. Pauses [waitTime] milliseconds before returning.
  void runLightLeft(int waitTime) {
    for (int counter = 0; counter < leds.length; counter++) {
      _setLeds(counter);
      // TODO(sgjesse): Use the Fletch sleep function.
      for (int i= 0; i < 50000; i++) {}
      //sleep(waitTime);
    }
  }

  // Iterates though the lights in decreasing order, and sets the LEDs using
  // a helper function. Pauses [waitTime] milliseconds before returning.
  void runLightRight(int waitTime) {
    for (int counter = leds.length - 1; counter >= 0; counter--) {
      _setLeds(counter);
      // TODO(sgjesse): Use the Fletch sleep function.
      for (int i= 0; i < 50000; i++) {}
      //sleep(waitTime);
    }
  }

  // Sets LED [ledToEnable] to true, and all others to false.
  void _setLeds(int ledToEnable) {
    for (int i = 0; i < gpioPins.length; i++) {
      gpioPins[i].state = (i == ledToEnable);
    }
  }
}
