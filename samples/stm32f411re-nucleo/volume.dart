// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// This sample implements a 'volume' control using the ADC.
//
// To use, hook up a potentiometer to A0 (PA0 - ADC1_IN0) on the board, and
// connected to GND and 3V3 (I/O pins are not 5V tolerant in analog mode, per
// the documentation). The code will take 10 samples of the pin using DMA and
// output the resulting values on the console every 100ms.
//
// This sample uses two Fibers to demonstrate waiting on an interrupt from the
// DMA. The 'sample' Fiber configures the ADC and DMA, and signals the 'main'
// Fiber just before waiting on the interrupt. The 'main' Fiber waits for the
// signal, and sleeps for 100ms before starting the ADC. This is done to show
// that the 'sample' Fiber really is waiting for the interrupt.

import 'dart:dartino';
import 'dart:dartino.ffi';

import 'package:gpio/gpio.dart';
import 'package:stm32/stm32f411re_nucleo.dart';
import 'package:stm32/adc.dart';
import 'package:stm32/dma.dart';
import 'package:stm32/gpio.dart';

final int CHANNEL = 0;
final int NUM_SAMPLES = 10;

final STM32F411RENucleo board = new STM32F411RENucleo();
final STM32Adc adc = board.adc;
final Channel sampleSignal = new Channel();

sample() {
  STM32DmaStream dmaStream = board.dma2.stream0;

  Struct data = new Struct32.finalized(NUM_SAMPLES);

  adc.init();
  adc.initChannel(CHANNEL);
  adc.configureSingleChannelSequence(CHANNEL);
  adc.continuousMode = true;
  adc.configureDmaMode(data, NUM_SAMPLES);
  while (true) {
    print('Reading volume...');
    sampleSignal.send(0);
    dmaStream.waitForTransferComplete();
    dmaStream.disableAndWait();
    var values = 'Values:';
    for (int i = 0; i < 10; i++) {
      values += ' ${data.getField(i)}';
    }
    print(values);
    adc.configureSingleChannelSequence(CHANNEL);
    adc.configureDmaMode(data, NUM_SAMPLES);
  }
}

main() {
  STM32Gpio gpio = board.gpio;
  GpioOutputPin led = gpio.initOutput(STM32F411RENucleo.LED2);

  Fiber.fork(sample);

  while (true) {
    sampleSignal.receive();
    led.toggle();
    sleep(100);
    adc.start();
  }
}
