// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32f746g.gpio;

import 'dart:dartino.ffi';

import 'package:gpio/gpio.dart';
import 'package:stm32f746g_disco/src/stm32f7_constants.dart';
import 'package:stm32f746g_disco/src/stm32f7_peripherals.dart';

/*
 * Proposed New GPIO API.
 */

/*
 * STM32F7 implementation of new GPIO API.
 */

/// All the GPIO ports on the STM32F7 MCU.
class _STM32F7GpioPort {
  static const A = const _STM32F7GpioPort(
      "A", GPIOA_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOAEN);
  static const B = const _STM32F7GpioPort(
      "B", GPIOB_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOBEN);
  static const C = const _STM32F7GpioPort(
      "C", GPIOC_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOCEN);
  static const D = const _STM32F7GpioPort(
      "D", GPIOD_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIODEN);
  static const E = const _STM32F7GpioPort(
      "E", GPIOE_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOEEN);
  static const F = const _STM32F7GpioPort(
      "F", GPIOF_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOFEN);
  static const G = const _STM32F7GpioPort(
      "G", GPIOG_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOGEN);
  static const H = const _STM32F7GpioPort(
      "H", GPIOH_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOHEN);
  static const I = const _STM32F7GpioPort(
      "I", GPIOI_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOIEN);
  static const J = const _STM32F7GpioPort(
      "J", GPIOJ_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOJEN);
  static const K = const _STM32F7GpioPort(
      "K", GPIOK_BASE - PERIPH_BASE, RCC_AHB1ENR_GPIOKEN);

  final String port;
  final int _base; // Peripheral base.
  final int _ahb1enr; // Clock enable bit in RCC->AHB1ENR.

  const _STM32F7GpioPort(this.port, this._base, this._ahb1enr);

  String toString() => 'GPIO port $port';
}

/// All the GPIO pins on the STM32F7 MCU.
class STM32F7Pin implements Pin {
  static const Pin PA0 = const STM32F7Pin('PA0', _STM32F7GpioPort.A, 0);
  static const Pin PA1 = const STM32F7Pin('PA1', _STM32F7GpioPort.A, 1);
  static const Pin PA2 = const STM32F7Pin('PA2', _STM32F7GpioPort.A, 2);
  static const Pin PA3 = const STM32F7Pin('PA3', _STM32F7GpioPort.A, 3);
  static const Pin PA4 = const STM32F7Pin('PA4', _STM32F7GpioPort.A, 4);
  static const Pin PA5 = const STM32F7Pin('PA5', _STM32F7GpioPort.A, 5);
  static const Pin PA6 = const STM32F7Pin('PA6', _STM32F7GpioPort.A, 6);
  static const Pin PA7 = const STM32F7Pin('PA7', _STM32F7GpioPort.A, 7);
  static const Pin PA8 = const STM32F7Pin('PA8', _STM32F7GpioPort.A, 8);
  static const Pin PA9 = const STM32F7Pin('PA9', _STM32F7GpioPort.A, 9);
  static const Pin PA10 = const STM32F7Pin('PA10', _STM32F7GpioPort.A, 10);
  static const Pin PA11 = const STM32F7Pin('PA11', _STM32F7GpioPort.A, 11);
  static const Pin PA12 = const STM32F7Pin('PA12', _STM32F7GpioPort.A, 12);
  static const Pin PA13 = const STM32F7Pin('PA13', _STM32F7GpioPort.A, 13);
  static const Pin PA14 = const STM32F7Pin('PA14', _STM32F7GpioPort.A, 14);
  static const Pin PA15 = const STM32F7Pin('PA15', _STM32F7GpioPort.A, 15);

  static const Pin PB0 = const STM32F7Pin('PB0', _STM32F7GpioPort.B, 0);
  static const Pin PB1 = const STM32F7Pin('PB1', _STM32F7GpioPort.B, 1);
  static const Pin PB2 = const STM32F7Pin('PB2', _STM32F7GpioPort.B, 2);
  static const Pin PB3 = const STM32F7Pin('PB3', _STM32F7GpioPort.B, 3);
  static const Pin PB4 = const STM32F7Pin('PB4', _STM32F7GpioPort.B, 4);
  static const Pin PB5 = const STM32F7Pin('PB5', _STM32F7GpioPort.B, 5);
  static const Pin PB6 = const STM32F7Pin('PB6', _STM32F7GpioPort.B, 6);
  static const Pin PB7 = const STM32F7Pin('PB7', _STM32F7GpioPort.B, 7);
  static const Pin PB8 = const STM32F7Pin('PB8', _STM32F7GpioPort.B, 8);
  static const Pin PB9 = const STM32F7Pin('PB9', _STM32F7GpioPort.B, 9);
  static const Pin PB10 = const STM32F7Pin('PB10', _STM32F7GpioPort.B, 10);
  static const Pin PB11 = const STM32F7Pin('PB11', _STM32F7GpioPort.B, 11);
  static const Pin PB12 = const STM32F7Pin('PB12', _STM32F7GpioPort.B, 12);
  static const Pin PB13 = const STM32F7Pin('PB13', _STM32F7GpioPort.B, 13);
  static const Pin PB14 = const STM32F7Pin('PB14', _STM32F7GpioPort.B, 14);
  static const Pin PB15 = const STM32F7Pin('PB15', _STM32F7GpioPort.B, 15);

  static const Pin PC0 = const STM32F7Pin('PC0', _STM32F7GpioPort.C, 0);
  static const Pin PC1 = const STM32F7Pin('PC1', _STM32F7GpioPort.C, 1);
  static const Pin PC2 = const STM32F7Pin('PC2', _STM32F7GpioPort.C, 2);
  static const Pin PC3 = const STM32F7Pin('PC3', _STM32F7GpioPort.C, 3);
  static const Pin PC4 = const STM32F7Pin('PC4', _STM32F7GpioPort.C, 4);
  static const Pin PC5 = const STM32F7Pin('PC5', _STM32F7GpioPort.C, 5);
  static const Pin PC6 = const STM32F7Pin('PC6', _STM32F7GpioPort.C, 6);
  static const Pin PC7 = const STM32F7Pin('PC7', _STM32F7GpioPort.C, 7);
  static const Pin PC8 = const STM32F7Pin('PC8', _STM32F7GpioPort.C, 8);
  static const Pin PC9 = const STM32F7Pin('PC9', _STM32F7GpioPort.C, 9);
  static const Pin PC10 = const STM32F7Pin('PC10', _STM32F7GpioPort.C, 10);
  static const Pin PC11 = const STM32F7Pin('PC11', _STM32F7GpioPort.C, 11);
  static const Pin PC12 = const STM32F7Pin('PC12', _STM32F7GpioPort.C, 12);
  static const Pin PC13 = const STM32F7Pin('PC13', _STM32F7GpioPort.C, 13);
  static const Pin PC14 = const STM32F7Pin('PC14', _STM32F7GpioPort.C, 14);
  static const Pin PC15 = const STM32F7Pin('PC15', _STM32F7GpioPort.C, 15);

  static const Pin PD0 = const STM32F7Pin('PD0', _STM32F7GpioPort.D, 0);
  static const Pin PD1 = const STM32F7Pin('PD1', _STM32F7GpioPort.D, 1);
  static const Pin PD2 = const STM32F7Pin('PD2', _STM32F7GpioPort.D, 2);
  static const Pin PD3 = const STM32F7Pin('PD3', _STM32F7GpioPort.D, 3);
  static const Pin PD4 = const STM32F7Pin('PD4', _STM32F7GpioPort.D, 4);
  static const Pin PD5 = const STM32F7Pin('PD5', _STM32F7GpioPort.D, 5);
  static const Pin PD6 = const STM32F7Pin('PD6', _STM32F7GpioPort.D, 6);
  static const Pin PD7 = const STM32F7Pin('PD7', _STM32F7GpioPort.D, 7);
  static const Pin PD8 = const STM32F7Pin('PD8', _STM32F7GpioPort.D, 8);
  static const Pin PD9 = const STM32F7Pin('PD9', _STM32F7GpioPort.D, 9);
  static const Pin PD10 = const STM32F7Pin('PD10', _STM32F7GpioPort.D, 10);
  static const Pin PD11 = const STM32F7Pin('PD11', _STM32F7GpioPort.D, 11);
  static const Pin PD12 = const STM32F7Pin('PD12', _STM32F7GpioPort.D, 12);
  static const Pin PD13 = const STM32F7Pin('PD13', _STM32F7GpioPort.D, 13);
  static const Pin PD14 = const STM32F7Pin('PD14', _STM32F7GpioPort.D, 14);
  static const Pin PD15 = const STM32F7Pin('PD15', _STM32F7GpioPort.D, 15);

  static const Pin PE0 = const STM32F7Pin('PE0', _STM32F7GpioPort.E, 0);
  static const Pin PE1 = const STM32F7Pin('PE1', _STM32F7GpioPort.E, 1);
  static const Pin PE2 = const STM32F7Pin('PE2', _STM32F7GpioPort.E, 2);
  static const Pin PE3 = const STM32F7Pin('PE3', _STM32F7GpioPort.E, 3);
  static const Pin PE4 = const STM32F7Pin('PE4', _STM32F7GpioPort.E, 4);
  static const Pin PE5 = const STM32F7Pin('PE5', _STM32F7GpioPort.E, 5);
  static const Pin PE6 = const STM32F7Pin('PE6', _STM32F7GpioPort.E, 6);
  static const Pin PE7 = const STM32F7Pin('PE7', _STM32F7GpioPort.E, 7);
  static const Pin PE8 = const STM32F7Pin('PE8', _STM32F7GpioPort.E, 8);
  static const Pin PE9 = const STM32F7Pin('PE9', _STM32F7GpioPort.E, 9);
  static const Pin PE10 = const STM32F7Pin('PE10', _STM32F7GpioPort.E, 10);
  static const Pin PE11 = const STM32F7Pin('PE11', _STM32F7GpioPort.E, 11);
  static const Pin PE12 = const STM32F7Pin('PE12', _STM32F7GpioPort.E, 12);
  static const Pin PE13 = const STM32F7Pin('PE13', _STM32F7GpioPort.E, 13);
  static const Pin PE14 = const STM32F7Pin('PE14', _STM32F7GpioPort.E, 14);
  static const Pin PE15 = const STM32F7Pin('PE15', _STM32F7GpioPort.E, 15);

  static const Pin PF1 = const STM32F7Pin('PF1', _STM32F7GpioPort.F, 1);
  static const Pin PF2 = const STM32F7Pin('PF2', _STM32F7GpioPort.F, 2);
  static const Pin PF3 = const STM32F7Pin('PF3', _STM32F7GpioPort.F, 3);
  static const Pin PF4 = const STM32F7Pin('PF4', _STM32F7GpioPort.F, 4);
  static const Pin PF5 = const STM32F7Pin('PF5', _STM32F7GpioPort.F, 5);
  static const Pin PF6 = const STM32F7Pin('PF6', _STM32F7GpioPort.F, 6);
  static const Pin PF7 = const STM32F7Pin('PF7', _STM32F7GpioPort.F, 7);
  static const Pin PF8 = const STM32F7Pin('PF8', _STM32F7GpioPort.F, 8);
  static const Pin PF9 = const STM32F7Pin('PF9', _STM32F7GpioPort.F, 9);
  static const Pin PF10 = const STM32F7Pin('PF10', _STM32F7GpioPort.F, 10);
  static const Pin PF11 = const STM32F7Pin('PF11', _STM32F7GpioPort.F, 11);
  static const Pin PF12 = const STM32F7Pin('PF12', _STM32F7GpioPort.F, 12);
  static const Pin PF13 = const STM32F7Pin('PF13', _STM32F7GpioPort.F, 13);
  static const Pin PF14 = const STM32F7Pin('PF14', _STM32F7GpioPort.F, 14);
  static const Pin PF15 = const STM32F7Pin('PF15', _STM32F7GpioPort.F, 15);

  static const Pin PG0 = const STM32F7Pin('PG0', _STM32F7GpioPort.G, 0);
  static const Pin PG1 = const STM32F7Pin('PG1', _STM32F7GpioPort.G, 1);
  static const Pin PG2 = const STM32F7Pin('PG2', _STM32F7GpioPort.G, 2);
  static const Pin PG3 = const STM32F7Pin('PG3', _STM32F7GpioPort.G, 3);
  static const Pin PG4 = const STM32F7Pin('PG4', _STM32F7GpioPort.G, 4);
  static const Pin PG5 = const STM32F7Pin('PG5', _STM32F7GpioPort.G, 5);
  static const Pin PG6 = const STM32F7Pin('PG6', _STM32F7GpioPort.G, 6);
  static const Pin PG7 = const STM32F7Pin('PG7', _STM32F7GpioPort.G, 7);
  static const Pin PG8 = const STM32F7Pin('PG8', _STM32F7GpioPort.G, 8);
  static const Pin PG9 = const STM32F7Pin('PG9', _STM32F7GpioPort.G, 9);
  static const Pin PG10 = const STM32F7Pin('PG10', _STM32F7GpioPort.G, 10);
  static const Pin PG11 = const STM32F7Pin('PG11', _STM32F7GpioPort.G, 11);
  static const Pin PG12 = const STM32F7Pin('PG12', _STM32F7GpioPort.G, 12);
  static const Pin PG13 = const STM32F7Pin('PG13', _STM32F7GpioPort.G, 13);
  static const Pin PG14 = const STM32F7Pin('PG14', _STM32F7GpioPort.G, 14);
  static const Pin PG15 = const STM32F7Pin('PG15', _STM32F7GpioPort.G, 15);

  static const Pin PH0 = const STM32F7Pin('PH0', _STM32F7GpioPort.H, 0);
  static const Pin PH1 = const STM32F7Pin('PH1', _STM32F7GpioPort.H, 1);
  static const Pin PH2 = const STM32F7Pin('PH2', _STM32F7GpioPort.H, 2);
  static const Pin PH3 = const STM32F7Pin('PH3', _STM32F7GpioPort.H, 3);
  static const Pin PH4 = const STM32F7Pin('PH4', _STM32F7GpioPort.H, 4);
  static const Pin PH5 = const STM32F7Pin('PH5', _STM32F7GpioPort.H, 5);
  static const Pin PH6 = const STM32F7Pin('PH6', _STM32F7GpioPort.H, 6);
  static const Pin PH7 = const STM32F7Pin('PH7', _STM32F7GpioPort.H, 7);
  static const Pin PH8 = const STM32F7Pin('PH8', _STM32F7GpioPort.H, 8);
  static const Pin PH9 = const STM32F7Pin('PH9', _STM32F7GpioPort.H, 9);
  static const Pin PH10 = const STM32F7Pin('PH10', _STM32F7GpioPort.H, 10);
  static const Pin PH11 = const STM32F7Pin('PH11', _STM32F7GpioPort.H, 11);
  static const Pin PH12 = const STM32F7Pin('PH12', _STM32F7GpioPort.H, 12);
  static const Pin PH13 = const STM32F7Pin('PH13', _STM32F7GpioPort.H, 13);
  static const Pin PH14 = const STM32F7Pin('PH14', _STM32F7GpioPort.H, 14);
  static const Pin PH15 = const STM32F7Pin('PH15', _STM32F7GpioPort.H, 15);

  static const Pin PI0 = const STM32F7Pin('PI0', _STM32F7GpioPort.I, 0);
  static const Pin PI1 = const STM32F7Pin('PI1', _STM32F7GpioPort.I, 1);
  static const Pin PI2 = const STM32F7Pin('PI2', _STM32F7GpioPort.I, 2);
  static const Pin PI3 = const STM32F7Pin('PI3', _STM32F7GpioPort.I, 3);
  static const Pin PI4 = const STM32F7Pin('PI4', _STM32F7GpioPort.I, 4);
  static const Pin PI5 = const STM32F7Pin('PI5', _STM32F7GpioPort.I, 5);
  static const Pin PI6 = const STM32F7Pin('PI6', _STM32F7GpioPort.I, 6);
  static const Pin PI7 = const STM32F7Pin('PI7', _STM32F7GpioPort.I, 7);
  static const Pin PI8 = const STM32F7Pin('PI8', _STM32F7GpioPort.I, 8);
  static const Pin PI9 = const STM32F7Pin('PI9', _STM32F7GpioPort.I, 9);
  static const Pin PI10 = const STM32F7Pin('PI10', _STM32F7GpioPort.I, 10);
  static const Pin PI11 = const STM32F7Pin('PI11', _STM32F7GpioPort.I, 11);
  static const Pin PI12 = const STM32F7Pin('PI12', _STM32F7GpioPort.I, 12);
  static const Pin PI13 = const STM32F7Pin('PI13', _STM32F7GpioPort.I, 13);
  static const Pin PI14 = const STM32F7Pin('PI14', _STM32F7GpioPort.I, 14);
  static const Pin PI15 = const STM32F7Pin('PI15', _STM32F7GpioPort.I, 15);

  static const Pin PJ0 = const STM32F7Pin('PJ0', _STM32F7GpioPort.J, 0);
  static const Pin PJ1 = const STM32F7Pin('PJ1', _STM32F7GpioPort.J, 1);
  static const Pin PJ2 = const STM32F7Pin('PJ2', _STM32F7GpioPort.J, 2);
  static const Pin PJ3 = const STM32F7Pin('PJ3', _STM32F7GpioPort.J, 3);
  static const Pin PJ4 = const STM32F7Pin('PJ4', _STM32F7GpioPort.J, 4);
  static const Pin PJ5 = const STM32F7Pin('PJ5', _STM32F7GpioPort.J, 5);
  static const Pin PJ6 = const STM32F7Pin('PJ6', _STM32F7GpioPort.J, 6);
  static const Pin PJ7 = const STM32F7Pin('PJ7', _STM32F7GpioPort.J, 7);
  static const Pin PJ8 = const STM32F7Pin('PJ8', _STM32F7GpioPort.J, 8);
  static const Pin PJ9 = const STM32F7Pin('PJ9', _STM32F7GpioPort.J, 9);
  static const Pin PJ10 = const STM32F7Pin('PJ10', _STM32F7GpioPort.J, 10);
  static const Pin PJ11 = const STM32F7Pin('PJ11', _STM32F7GpioPort.J, 11);
  static const Pin PJ12 = const STM32F7Pin('PJ12', _STM32F7GpioPort.J, 12);
  static const Pin PJ13 = const STM32F7Pin('PJ13', _STM32F7GpioPort.J, 13);
  static const Pin PJ14 = const STM32F7Pin('PJ14', _STM32F7GpioPort.J, 14);
  static const Pin PJ15 = const STM32F7Pin('PJ15', _STM32F7GpioPort.J, 15);

  final String name;
  final _STM32F7GpioPort _port;
  final int pin;

  const STM32F7Pin(this.name, this._port, this.pin);
  String toString() => 'GPIO pin $name';
}

/// Pin on the STM32F7 MCU configured for GPIO output.
class _STM32F7GpioOutputPin extends GpioOutputPin {
  final STM32F7Pin pin;

  _STM32F7GpioOutputPin._(this.pin);

  bool get state {
    // Read bit for pin (GPIOx->ODR).
    return peripherals.getUint32(pin._port._base + ODR) & (1 << pin.pin) != 0;
  }

  void set state(bool newState) {
    if (newState) {
      peripherals.setUint32(pin._port._base + BSRR, 1 << pin.pin);
    } else {
      peripherals.setUint32(pin._port._base + BSRR, (1 << pin.pin) << 16);
    }
  }
}

/// Pin on the STM32F7 MCU configured for GPIO input.
class _STM32F7GpioInputPin extends GpioInputPin {
  final STM32F7Pin pin;

  _STM32F7GpioInputPin._(this.pin);

  bool get state {
    // Read bit for pin (GPIOx->IDR).
    return (peripherals.getUint32(pin._port._base + IDR) & (1 << pin.pin)) != 0;
  }
}

/// Access to STM32F7 MCU GPIO interface to configure GPIO pins.
class STM32F7Gpio extends Gpio {
  GpioOutputPin initOutput(Pin pin) {
    _init(pin, GPIO_MODE_OUTPUT_PP, GPIO_PULLUP, GPIO_SPEED_FREQ_HIGH);
    return new _STM32F7GpioOutputPin._(pin);
  }

  GpioInputPin initInput(
      Pin pin, {GpioPullUpDown pullUpDown, GpioInterruptTrigger trigger}) {
    int pull = GPIO_NOPULL;
    if (pullUpDown != null && pullUpDown != GpioPullUpDown.floating) {
      pull = pullUpDown == GpioPullUpDown.pullUp ? GPIO_PULLUP : GPIO_PULLDOWN;
    }
    _init(pin, GPIO_MODE_INPUT, pull, GPIO_SPEED_FREQ_HIGH);
    return new _STM32F7GpioInputPin._(pin);
  }

  void _init(STM32F7Pin pin, int mode, int pull, int speed) {
    if (pin is! STM32F7Pin) {
      throw new ArgumentError('Illegal pin type');
    }
    STM32F7Pin p = pin;
    int base = p._port._base;
    int temp;

    // Enable clock for the GPIO port (RCC->AHB1ENR).
    int ahb1enrOffset = RCC_BASE - PERIPH_BASE + RCC.AHB1ENR;
    temp = peripherals.getUint32(ahb1enrOffset);
    temp |= p._port._ahb1enr;
    peripherals.setUint32(ahb1enrOffset, temp);
    // Delay after an RCC peripheral clock enabling.
    peripherals.getUint32(ahb1enrOffset);

    // Configure pin mode (GPIOx->MODER).
    temp = peripherals.getUint32(base + MODER);
    temp &= ~(GPIO_MODER_MODER0 << (p.pin * 2));
    temp |= ((mode & GPIO_MODE) << (p.pin * 2));
    peripherals.setUint32(base + MODER, temp);

    // Configure the IO speed (GPIOx->OSPEEDR).
    temp = peripherals.getUint32(base + OSPEEDR);
    temp &= ~(GPIO_OSPEEDER_OSPEEDR0 << (p.pin * 2));
    temp |= (speed << (p.pin * 2));
    peripherals.setUint32(base + OSPEEDR, temp);

    // Configure the IO output type (GPIOx->OTYPER).
    temp = peripherals.getUint32(base + OTYPER);
    temp &= ~(GPIO_OTYPER_OT_0 << p.pin);
    temp |= (((mode & GPIO_OUTPUT_TYPE) >> 4) << p.pin);
    peripherals.setUint32(base + OTYPER, temp);

    // Activate the pull-up/pull-down resistor (GPIOx->PUPDR).
    temp = peripherals.getUint32(base + PUPDR);
    temp &= ~(GPIO_PUPDR_PUPDR0 << (p.pin * 2));
    temp |= (pull << (p.pin * 2));
    peripherals.setUint32(base + PUPDR, temp);
  }
}
