// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32f746g.gpio;

import 'dart:fletch.ffi';

import 'package:stm32f746g_disco/src/stm32f7_constants.dart';
import 'package:stm32f746g_disco/src/stm32f7_peripherals.dart';

/*
 * Proposed New GPIO API.
 */

/// Describes a pin on a MCU/SoC
abstract class Pin {
  /// Name of the pin.
  String get name;
}

/// Pull-up/down resistor state.
enum GpioPullUpDown {
  floating,
  pullDown,
  pullUp,
}

/// Interrupt triggers.
enum GpioInterruptTrigger {
  none,
  rising,
  falling,
  both,
}

/// Pin on a MCU/SoC configured for GPIO operation.
///
/// This is a common super interface for the different types GPIO pin
/// configuration.
abstract class GpioPin {
  /// The pin configured.
  Pin get pin;
}

/// Pin on a MCU/SoC configured for GPIO output.
abstract class GpioOutputPin extends GpioPin {
  /// Gets or sets the state of the GPIO pin.
  bool state;

  void low() {
    state = false;
  }

  /// Sets the state of the GPIO pin to high (`true`).
  void high() {
    state = true;
  }

  /// Toggles the state of the GPIO pin.
  ///
  /// Returns the new state if the pin.
  bool toggle() => state = !state;
}

/// Pin on a MCU/SoC configured for GPIO input.
abstract class GpioInputPin extends GpioPin {
  /// Gets the state of the GPIO pin.
  bool get state;
}

/// Access to GPIO interface to configure GPIO pins.
abstract class Gpio {
  /// Initialize a GPIO pin for output.
  GpioOutputPin initOutput(Pin pin);

  /// Initialize a GPIO pin for input.
  GpioInputPin initInput(
      Pin pin, [GpioPullUpDown pullUpDown = GpioPullUpDown.floating]);
}

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
  /// ...
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
  /// ...
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
  /// ...

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
      Pin pin, [GpioPullUpDown pullUpDown = GpioPullUpDown.floating]) {
    int pull = GPIO_NOPULL;
    if (pullUpDown != GpioPullUpDown.floating) {
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
    print(mode);
    temp |= (((mode & GPIO_OUTPUT_TYPE) >> 4) << p.pin);
    peripherals.setUint32(base + OTYPER, temp);

    // Activate the pull-up/pull-down resistor (GPIOx->PUPDR).
    temp = peripherals.getUint32(base + PUPDR);
    temp &= ~(GPIO_PUPDR_PUPDR0 << (p.pin * 2));
    temp |= (pull << (p.pin * 2));
    peripherals.setUint32(base + PUPDR, temp);
  }
}
