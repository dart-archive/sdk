// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.stm32f746g_discovery;

import 'package:gpio/gpio.dart';
import 'package:i2c/i2c.dart';
import 'package:stm32/adc.dart';
import 'package:stm32/dma.dart';
import 'package:stm32/gpio.dart';
import 'package:stm32/i2c.dart';
import 'package:stm32/lcd.dart';
import 'package:stm32/ts.dart';
import 'package:stm32/uart.dart';
import 'package:stm32/src/constants.dart';

class STM32F746GDiscovery {
  static const int apb1Clock = 100000000;
  static const int apb2Clock = 200000000;
  /// GPIO pin for on-board green LED.
  static const Pin LED1 = STM32Pin.PI1;
  /// GPIO pin for on-board blue button.
  static const Pin Button1 = STM32Pin.PI11;

  /// GPIO pins on the Arduino connector.
  static const Pin A0 = STM32Pin.PA0;
  static const Pin A1 = STM32Pin.PF10;
  static const Pin A2 = STM32Pin.PF9;
  static const Pin A3 = STM32Pin.PF8;
  static const Pin A4 = STM32Pin.PF7;
  static const Pin A5 = STM32Pin.PF6;

  static const Pin D0 = STM32Pin.PC7;
  static const Pin D1 = STM32Pin.PC6;
  static const Pin D2 = STM32Pin.PG6;
  static const Pin D3 = STM32Pin.PB4;
  static const Pin D4 = STM32Pin.PG7;
  static const Pin D5 = STM32Pin.PI0;
  static const Pin D6 = STM32Pin.PH6;
  static const Pin D7 = STM32Pin.PI3;
  static const Pin D8 = STM32Pin.PI2;
  static const Pin D9 = STM32Pin.PA15;
  static const Pin D10 = STM32Pin.PA8;
  static const Pin D11 = STM32Pin.PB15;
  static const Pin D12 = STM32Pin.PB14;
  static const Pin D13 = STM32Pin.PI1;
  static const Pin D14 = STM32Pin.PB9;
  static const Pin D15 = STM32Pin.PB8;
  

  STM32Gpio _gpio;
  Uart _uart;
  I2CBus _i2c1;
  STM32Adc _adc1;
  STM32Adc _adc2;
  STM32Adc _adc3;
  STM32Dma _dma1;
  STM32Dma _dma2;

  FrameBuffer _frameBuffer;
  TouchScreen _touchScreen;

  STM32F746GDiscovery();

  Gpio get gpio {
    if (_gpio == null) {
      _gpio = new STM32Gpio(apb1Clock, apb2Clock);
    }
    return _gpio;
  }

  Uart get uart {
    if (_uart == null) {
      _uart = new Uart();
    }
    return _uart;
  }

  I2CBus get i2c1 {
    if (_i2c1 == null) {
      _i2c1 = new I2CBusSTM('i2c1');
    }
    return _i2c1;
  }

  FrameBuffer get frameBuffer {
    if (_frameBuffer == null) {
      _frameBuffer = new FrameBuffer();
    }
    return _frameBuffer;
  }

  TouchScreen get touchScreen {
    if (_touchScreen == null) {
      _touchScreen =
        new TouchScreen.init(frameBuffer.width, frameBuffer.height);
    }
    return _touchScreen;
  }

  STM32Adc get adc1 {
    if (_adc1 == null) {
      _adc1 = new STM32Adc(STM32AdcConstants.ADC1, gpio, dma2.stream0);
    }
    return _adc1;
  }

  STM32Adc get adc2 {
    if (_adc2 == null) {
      _adc2 = new STM32Adc(STM32AdcConstants.ADC2, gpio, dma2.stream2);
    }
    return _adc2;
  }

  STM32Adc get adc3 {
    if (_adc3 == null) {
      _adc3 = new STM32Adc(STM32AdcConstants.ADC3, gpio, dma2.stream1);
    }
    return _adc3;
  }

  STM32Dma get dma1 {
    if (_dma1 == null) {
      _dma1 = new STM32Dma('DMA1', 1, DMA1_BASE, RCC_AHB1ENR_DMA1EN);
      // Enable DMA clock - assuming no-one asks for the DMA unless they want to
      // use it.
      _dma1.enableClock();
    }
    return _dma1;
  }

  STM32Dma get dma2 {
    if (_dma2 == null) {
      _dma2 = new STM32Dma('DMA2', 2, DMA2_BASE, RCC_AHB1ENR_DMA2EN);
      // Enable DMA clock - assuming no-one asks for the DMA unless they want to
      // use it.
      _dma2.enableClock();
    }
    return _dma2;
  }

}
