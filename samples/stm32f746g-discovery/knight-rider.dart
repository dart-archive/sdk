// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// Remember those red running lights KITT had in Knight Rider?
// https://www.youtube.com/watch?v=Mo8Qls0HnWo
//
// This sample recreates those with a chain of LEDs running right and left:
// https://storage.googleapis.com/dartino-archive/images/knight-rider.mp4
//
// For breadboard layout and connections to the STM32F746G Discovery board, see:
// https://dartino.org/images/knight-rider-schematic.png
// Connect the four blue wires to D8, D9, D10, and D11.
// Connect the black wire to ground.

import 'dart:dartino';

import 'package:gpio/gpio.dart';
import 'package:stm32/stm32f746g_disco.dart';
import 'package:stm32/gpio.dart';

main() {
  STM32F746GDiscovery board = new STM32F746GDiscovery();

  // Array constant containing the GPIO pins of the connected LEDs.
  // You can add more LEDs simply by extending the list. Make sure
  // the pins are listed in the order the LEDs are connected.
  List<Pin> leds = [
    STM32Pin.PI2, // D8
    STM32Pin.PA15, // D9
    STM32Pin.PA8, // D10
    STM32Pin.PB15, // D11
  ];

  // A button which when pressed, stops or starts the blink sequence
  Pin button = STM32Pin.PB14; // D12

  // Initialize the lights controller class.
  Lights lights = new Lights(board.gpio, leds, button);
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
  List<GpioOutputPin> gpioPins = [];
  final Pin button;
  GpioInputPin buttonGpioPin;

  Lights(this._gpio, this.leds, this.button);

  // Initializes all pins as output.
  void init() {
    for (Pin led in leds) {
      gpioPins.add(_gpio.initOutput(led));
    }
    buttonGpioPin =
        _gpio.initInput(button, pullUpDown: GpioPullUpDown.pullDown);
  }

  /// Iterates though the lights in increasing order, and sets the LEDs using
  /// a helper function. Pauses [waitTime] milliseconds before returning.
  void runLightLeft(int waitTime) {
    for (int counter = 0; counter < leds.length; counter++) {
      _setLeds(counter);
      _checkPause();
      sleep(waitTime);
    }
  }

  /// Iterates though the lights in decreasing order, and sets the LEDs using
  /// a helper function. Pauses [waitTime] milliseconds before returning.
  void runLightRight(int waitTime) {
    for (int counter = leds.length - 1; counter >= 0; counter--) {
      _setLeds(counter);
      _checkPause();
      sleep(waitTime);
    }
  }

  /// Sets LED [ledToEnable] to true, and all others to false.
  void _setLeds(int ledToEnable) {
    for (int i = 0; i < gpioPins.length; i++) {
      gpioPins[i].state = (i == ledToEnable);
    }
  }

  /// If the button is pressed, then wait until the button has been pressed
  /// again before returning, otherwise return immediately.
  void _checkPause() {
    if (buttonGpioPin.state) {
      while (buttonGpioPin.state) sleep(10);
      while (!buttonGpioPin.state) sleep(10);
      while (buttonGpioPin.state) sleep(10);
    }
  }
}
