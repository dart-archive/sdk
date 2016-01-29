// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32f746g.src.stm32f7_constants;

// Base address of AHB/ABP peripherals.
//
// These are from
// stm32cube_fw_f7/Drivers/CMSIS/Device/ST/STM32F7xx/Include/stm32f746xx.h
const int PERIPH_BASE = 0x40000000;

const int APB1PERIPH_BASE = PERIPH_BASE;
const int APB2PERIPH_BASE = PERIPH_BASE + 0x00010000;
const int AHB1PERIPH_BASE = PERIPH_BASE + 0x00020000;
const int AHB2PERIPH_BASE = PERIPH_BASE + 0x10000000;

const int GPIOA_BASE = AHB1PERIPH_BASE + 0x0000;
const int GPIOB_BASE = AHB1PERIPH_BASE + 0x0400;
const int GPIOC_BASE = AHB1PERIPH_BASE + 0x0800;
const int GPIOD_BASE = AHB1PERIPH_BASE + 0x0C00;
const int GPIOE_BASE = AHB1PERIPH_BASE + 0x1000;
const int GPIOF_BASE = AHB1PERIPH_BASE + 0x1400;
const int GPIOG_BASE = AHB1PERIPH_BASE + 0x1800;
const int GPIOH_BASE = AHB1PERIPH_BASE + 0x1C00;
const int GPIOI_BASE = AHB1PERIPH_BASE + 0x2000;
const int GPIOJ_BASE = AHB1PERIPH_BASE + 0x2400;
const int GPIOK_BASE = AHB1PERIPH_BASE + 0x2800;
const int CRC_BASE = AHB1PERIPH_BASE + 0x3000;
const int RCC_BASE = AHB1PERIPH_BASE + 0x3800;
const int FLASH_R_BASE = AHB1PERIPH_BASE + 0x3C00;
const int DMA1_BASE = AHB1PERIPH_BASE + 0x6000;
const int DMA2_BASE = AHB1PERIPH_BASE + 0x6400;
const int ETH_BASE = AHB1PERIPH_BASE + 0x8000;
const int DMA2D_BASE = AHB1PERIPH_BASE + 0xB000;

// Reset and Clock Control (RCC) registers.
//
// These are offsets into the peripheral refisters from offset RCC_BASE.
class RCC {
  static const int CR = 0x00; // RCC clock control register.
  static const int PLLCFGR = 0x04; // RCC PLL configuration register.
  static const int CFGR = 0x08; // RCC clock configuration register.
  static const int CIR = 0x0C; // RCC clock interrupt register.
  static const int AHB1RSTR = 0x10; // RCC AHB1 peripheral reset register.
  static const int AHB2RSTR = 0x14; // RCC AHB2 peripheral reset register.
  static const int AHB3RSTR = 0x18; // RCC AHB3 peripheral reset register.
  // Reserved, 0x1C.
  static const int APB1RSTR = 0x20; // RCC APB1 peripheral reset register.
  static const int APB2RSTR = 0x24; // RCC APB2 peripheral reset register.
  // Reserved, 0x28-0x2C.
  static const int AHB1ENR = 0x30; // RCC AHB1 peripheral clock register
  static const int AHB2ENR = 0x34; // RCC AHB2 peripheral clock register.
  static const int AHB3ENR = 0x38; // RCC AHB3 peripheral clock register.
  // Reserved, 0x3C.
  static const int APB1ENR = 0x40; // RCC APB1 peripheral clock enable register.
  static const int APB2ENR = 0x44; // RCC APB2 peripheral clock enable register.
  // Reserved, 0x48-0x4C.
  // RCC AHB1 peripheral clock enable in low power mode register.
  static const int AHB1LPENR = 0x50;
  // RCC AHB2 peripheral clock enable in low power mode register.
  static const int AHB2LPENR = 0x54;
  // RCC AHB3 peripheral clock enable in low power mode register.
  static const int AHB3LPENR = 0x58;
  // Reserved, 0x5C.
  // RCC APB1 peripheral clock enable in low power mode register.
  static const int APB1LPENR = 0x60;
  // RCC APB2 peripheral clock enable in low power mode register.
  static const int APB2LPENR = 0x64;
  // Reserved, 0x68-0x6C.
  static const int BDCR = 0x70; // RCC Backup domain control register.
  static const int CSR = 0x74; // RCC clock control & status register.
  // Reserved, 0x78-0x7C.
  // RCC spread spectrum clock generation register.
  static const int SSCGR = 0x80;
  static const int PLLI2SCFGR = 0x84; // RCC PLLI2S configuration register.
  static const int PLLSAICFGR = 0x88; // RCC PLLSAI configuration register.
  // RCC Dedicated Clocks configuration register1.
  static const int DCKCFGR1 = 0x8C;
  // RCC Dedicated Clocks configuration register 2.
  static const int DCKCFGR2 = 0x90;
}

// Bit definition for RCC_AHB1ENR register
const int RCC_AHB1ENR_GPIOAEN = 0x00000001;
const int RCC_AHB1ENR_GPIOBEN = 0x00000002;
const int RCC_AHB1ENR_GPIOCEN = 0x00000004;
const int RCC_AHB1ENR_GPIODEN = 0x00000008;
const int RCC_AHB1ENR_GPIOEEN = 0x00000010;
const int RCC_AHB1ENR_GPIOFEN = 0x00000020;
const int RCC_AHB1ENR_GPIOGEN = 0x00000040;
const int RCC_AHB1ENR_GPIOHEN = 0x00000080;
const int RCC_AHB1ENR_GPIOIEN = 0x00000100;
const int RCC_AHB1ENR_GPIOJEN = 0x00000200;
const int RCC_AHB1ENR_GPIOKEN = 0x00000400;
const int RCC_AHB1ENR_CRCEN = 0x00001000;
const int RCC_AHB1ENR_BKPSRAMEN = 0x00040000;
const int RCC_AHB1ENR_DTCMRAMEN = 0x00100000;
const int RCC_AHB1ENR_DMA1EN = 0x00200000;
const int RCC_AHB1ENR_DMA2EN = 0x00400000;
const int RCC_AHB1ENR_DMA2DEN = 0x00800000;
const int RCC_AHB1ENR_ETHMACEN = 0x02000000;
const int RCC_AHB1ENR_ETHMACTXEN = 0x04000000;
const int RCC_AHB1ENR_ETHMACRXEN = 0x08000000;
const int RCC_AHB1ENR_ETHMACPTPEN = 0x10000000;
const int RCC_AHB1ENR_OTGHSEN = 0x20000000;
const int RCC_AHB1ENR_OTGHSULPIEN = 0x40000000;

// Offset to GPIO registers for each GPIO port.
//
// These are from the GPIO_TypeDef in
// stm32cube_fw_f7/Drivers/CMSIS/Device/ST/STM32F7xx/Include/stm32f746xx.h
const int MODER = 0x00; // GPIO port mode register.
const int OTYPER = 0x04; // GPIO port output type register.
const int OSPEEDR = 0x08; // GPIO port output speed register.
const int PUPDR = 0x0c; // GPIO port pull-up/pull-down register.
const int IDR = 0x10; // GPIO port input data register.
const int ODR = 0x14; // GPIO port output data register.
const int BSRR = 0x18; // GPIO port bit set/reset register.
const int LCKR = 0x1c; // GPIO port configuration lock register.
const int AFR = 0x20; // GPIO alternate function registers.
const int AFR_1 = 0x20; // GPIO alternate function register 1.
const int AFR_2 = 0x24; // GPIO alternate function register 2.

// GPIO modes.
// Input Floating Mode.
const int GPIO_MODE_INPUT = 0x00000000;
// Output Push Pull Mode.
const int GPIO_MODE_OUTPUT_PP = 0x00000001;
// Output Open Drain Mode.
const int GPIO_MODE_OUTPUT_OD = 0x00000011;
// Alternate Function Push Pull Mode.
const int GPIO_MODE_AF_PP = 0x00000002;
// Alternate Function Open Drain Mode.
const int GPIO_MODE_AF_OD = 0x00000012;
// Analog Mode.
const int GPIO_MODE_ANALOG = 0x00000003;
// External Interrupt Mode with Rising edge trigger detection.
const int GPIO_MODE_IT_RISING = 0x10110000;
// External Interrupt Mode with Falling edge trigger detection
const int GPIO_MODE_IT_FALLING = 0x10210000;
// External Interrupt Mode with Rising/Falling edge trigger detection.
const int GPIO_MODE_IT_RISING_FALLING = 0x10310000;
// External Event Mode with Rising edge trigger detection.
const int GPIO_MODE_EVT_RISING = 0x10120000;
// External Event Mode with Falling edge trigger detection.
const int GPIO_MODE_EVT_FALLING = 0x10220000;
// External Event Mode with Rising/Falling edge trigger detection.
const int GPIO_MODE_EVT_RISING_FALLING = 0x10320000;

// GPIO speed.
const int GPIO_SPEED_FREQ_LOW = 0x00000000;
const int GPIO_SPEED_FREQ_MEDIUM = 0x00000001;
const int GPIO_SPEED_FREQ_HIGH = 0x00000002;
const int GPIO_SPEED_FREQ_VERY_HIGH = 0x00000003;

// GPIO pull-up/pull-down.
const int GPIO_NOPULL = 0x00000000;
const int GPIO_PULLUP = 0x00000001;
const int GPIO_PULLDOWN = 0x00000002;

// Mode bits (two bits per pin).
const int GPIO_MODER_MODER0 = 0x00000003;

// Output type bits (one bit per pin).
const int GPIO_OTYPER_OT_0 = 0x00000001;

// IO speed bits (two bits per pin).
const int GPIO_OSPEEDER_OSPEEDR0 = 0x00000003;

// Pull-up/pull-down (two bits per pin).
const int GPIO_PUPDR_PUPDR0 = 0x00000003;

// Masks.
const int GPIO_MODE = 0x00000003;
const int EXTI_MODE = 0x10000000;
const int GPIO_MODE_IT = 0x00010000;
const int GPIO_MODE_EVT = 0x00020000;
const int RISING_EDGE = 0x00100000;
const int FALLING_EDGE = 0x00200000;
const int GPIO_OUTPUT_TYPE = 0x00000010;
