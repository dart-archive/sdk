// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.src.constants;

// Base address of AHB/ABP peripherals.
//
// These are from
// stm32cube_fw_f7/Drivers/CMSIS/Device/ST/STM32F7xx/Include/stm32f746xx.h
//
// Not all models have all the peripherals that F7 has, but the common
// parts have the same addresses.
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

const int ADC1_BASE = APB2PERIPH_BASE + 0x2000;
const int ADC2_BASE = APB2PERIPH_BASE + 0x2100;
const int ADC3_BASE = APB2PERIPH_BASE + 0x2200;
const int ADC_COMMON_BASE = APB2PERIPH_BASE + 0x2300;

const int TIM2_BASE = APB1PERIPH_BASE + 0x0000;
const int TIM3_BASE = APB1PERIPH_BASE + 0x0400;
const int TIM4_BASE = APB1PERIPH_BASE + 0x0800;
const int TIM5_BASE = APB1PERIPH_BASE + 0x0C00;
const int TIM6_BASE = APB1PERIPH_BASE + 0x1000;
const int TIM7_BASE = APB1PERIPH_BASE + 0x1400;
const int TIM12_BASE = APB1PERIPH_BASE + 0x1800;
const int TIM13_BASE = APB1PERIPH_BASE + 0x1C00;
const int TIM14_BASE = APB1PERIPH_BASE + 0x2000;
const int TIM1_BASE = APB2PERIPH_BASE + 0x0000;
const int TIM8_BASE = APB2PERIPH_BASE + 0x0400;
const int TIM9_BASE = APB2PERIPH_BASE + 0x4000;
const int TIM10_BASE = APB2PERIPH_BASE + 0x4400;
const int TIM11_BASE = APB2PERIPH_BASE + 0x4800;


// Reset and Clock Control (RCC) registers.
//
// These are offsets into the peripheral registers from offset RCC_BASE.
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

// Bit definition for RCC_APB2ENR register
const int RCC_APB2ENR_TIM1EN = 0x00000001;
const int RCC_APB2ENR_TIM8EN = 0x00000002;
const int RCC_APB2ENR_USART1EN = 0x00000010;
const int RCC_APB2ENR_USART6EN = 0x00000020;
const int RCC_APB2ENR_ADC1EN = 0x00000100;
const int RCC_APB2ENR_ADC2EN = 0x00000200;
const int RCC_APB2ENR_ADC3EN = 0x00000400;
const int RCC_APB2ENR_SDMMC1EN = 0x00000800;
const int RCC_APB2ENR_SPI1EN = 0x00001000;
const int RCC_APB2ENR_SPI4EN = 0x00002000;
const int RCC_APB2ENR_SYSCFGEN = 0x00004000;
const int RCC_APB2ENR_TIM9EN = 0x00010000;
const int RCC_APB2ENR_TIM10EN = 0x00020000;
const int RCC_APB2ENR_TIM11EN = 0x00040000;
const int RCC_APB2ENR_SPI5EN = 0x00100000;
const int RCC_APB2ENR_SPI6EN = 0x00200000;
const int RCC_APB2ENR_SAI1EN = 0x00400000;
const int RCC_APB2ENR_SAI2EN = 0x00800000;
const int RCC_APB2ENR_LTDCEN = 0x04000000;

// Bit definition for RCC_APB1ENR register
const int RCC_APB1ENR_TIM2EN = 0x00000001;
const int RCC_APB1ENR_TIM3EN = 0x00000002;
const int RCC_APB1ENR_TIM4EN = 0x00000004;
const int RCC_APB1ENR_TIM5EN = 0x00000008;
const int RCC_APB1ENR_TIM6EN = 0x00000010;
const int RCC_APB1ENR_TIM7EN = 0x00000020;
const int RCC_APB1ENR_TIM12EN = 0x00000040;
const int RCC_APB1ENR_TIM13EN = 0x00000080;
const int RCC_APB1ENR_TIM14EN = 0x00000100;
const int RCC_APB1ENR_LPTIM1EN = 0x00000200;
const int RCC_APB1ENR_WWDGEN = 0x00000800;
const int RCC_APB1ENR_SPI2EN = 0x00004000;
const int RCC_APB1ENR_SPI3EN = 0x00008000;
const int RCC_APB1ENR_SPDIFRXEN = 0x00010000;
const int RCC_APB1ENR_USART2EN = 0x00020000;
const int RCC_APB1ENR_USART3EN = 0x00040000;
const int RCC_APB1ENR_UART4EN = 0x00080000;
const int RCC_APB1ENR_UART5EN = 0x00100000;
const int RCC_APB1ENR_I2C1EN = 0x00200000;
const int RCC_APB1ENR_I2C2EN = 0x00400000;
const int RCC_APB1ENR_I2C3EN = 0x00800000;
const int RCC_APB1ENR_I2C4EN = 0x01000000;
const int RCC_APB1ENR_CAN1EN = 0x02000000;
const int RCC_APB1ENR_CAN2EN = 0x04000000;
const int RCC_APB1ENR_CECEN = 0x08000000;
const int RCC_APB1ENR_PWREN = 0x10000000;
const int RCC_APB1ENR_DACEN = 0x20000000;
const int RCC_APB1ENR_UART7EN = 0x40000000;
const int RCC_APB1ENR_UART8EN = 0x80000000;

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

// Analog-to-digital converter (ADC) registers.
class ADC {
  // Offset to ADC registers for each ADC port, relative to port base.
  static const int SR = 0x00; // ADC status register.
  static const int CR1 = 0x04; // ADC control register 1.
  static const int CR2 = 0x08; // ADC control register 2.
  static const int SMPR1 = 0x0C; // ADC sample time register 1.
  static const int SMPR2 = 0x10; // ADC sample time register 2.
  static const int JOFR1 = 0x14; // ADC injected channel data offset register 1.
  static const int JOFR2 = 0x18; // ADC injected channel data offset register 2.
  static const int JOFR3 = 0x1C; // ADC injected channel data offset register 3.
  static const int JOFR4 = 0x20; // ADC injected channel data offset register 4.
  static const int HTR = 0x24; // ADC watchdog higher threshold register.
  static const int LTR = 0x28; // ADC watchdog lower threshold register.
  static const int SQR1 = 0x2C; // ADC regular sequence register 1.
  static const int SQR2 = 0x30; // ADC regular sequence register 2.
  static const int SQR3 = 0x34; // ADC regular sequence register 3.
  static const int JSQR = 0x38; // ADC injected sequence register.
  static const int JDR1 = 0x3C; // ADC injected data register 1.
  static const int JDR2 = 0x40; // ADC injected data register 2.
  static const int JDR3 = 0x44; // ADC injected data register 3.
  static const int JDR4 = 0x48; // ADC injected data register 4.
  static const int DR = 0x4C; // ADC regular data register.

  // Common register offsets, relative to ADC_COMMON_BASE.
  static const int CSR = 0x00; // ADC common status register.
  static const int CCR = 0x04; // ADC common control register.
  // ADC common regular data register for dual and triple modes.
  static const int CDR = 0x08;
}

// Analog to Digital Converter (ADC).

// Bit definition for ADC_SR register.
const int ADC_SR_AWD = 0x00000001; // Analog watchdog flag.
const int ADC_SR_EOC = 0x00000002; // End of conversion.
const int ADC_SR_JEOC = 0x00000004; // Injected channel end of conversion.
const int ADC_SR_JSTRT = 0x00000008; // Injected channel Start flag.
const int ADC_SR_STRT = 0x00000010; // Regular channel Start flag.
const int ADC_SR_OVR = 0x00000020; // Overrun flag.

// Bit definition for ADC_CR1 register.

// AWDCH[4:0] bits (Analog watchdog channel select bits).
const int ADC_CR1_AWDCH_MASK = 0x0000001F;
// Interrupt enable for EOC.
const int ADC_CR1_EOCIE = 0x00000020;
// Analog Watchdog interrupt enable.
const int ADC_CR1_AWDIE = 0x00000040;
// Interrupt enable for injected channels.
const int ADC_CR1_JEOCIE = 0x00000080;
// Scan mode.
const int ADC_CR1_SCAN = 0x00000100;
// Enable the watchdog on a single channel in scan mode.
const int ADC_CR1_AWDSGL = 0x00000200;
// Automatic injected group conversion.
const int ADC_CR1_JAUTO = 0x00000400;
// Discontinuous mode on regular channels.
const int ADC_CR1_DISCEN = 0x00000800;
// Discontinuous mode on injected channels.
const int ADC_CR1_JDISCEN = 0x00001000;
// DISCNUM[2:0] bits (Discontinuous mode channel count).
const int ADC_CR1_DISCNUM_MASK = 0x0000E000;
// Analog watchdog enable on injected channels.
const int ADC_CR1_JAWDEN = 0x00400000;
// Analog watchdog enable on regular channels.
const int ADC_CR1_AWDEN = 0x00800000;
// RES[2:0] bits (Resolution).
const int ADC_CR1_RES_MASK = 0x03000000;
const int ADC_CR1_RES_12BIT = 0x00000000;
const int ADC_CR1_RES_10BIT = 0x01000000;
const int ADC_CR1_RES_8BIT = 0x02000000;
const int ADC_CR1_RES_6BIT = 0x03000000;
// Overrun interrupt enable.
const int ADC_CR1_OVRIE = 0x04000000;

// Bit definition for ADC_CR2 register.

// A/D Converter ON / OFF.
const int ADC_CR2_ADON = 0x00000001;
// Continuous Conversion.
const int ADC_CR2_CONT = 0x00000002;
// Direct Memory access mode.
const int ADC_CR2_DMA = 0x00000100;
// DMA disable selection (Single ADC).
const int ADC_CR2_DDS = 0x00000200;
// End of conversion selection.
const int ADC_CR2_EOCS = 0x00000400;
// Data Alignment.
const int ADC_CR2_ALIGN_MASK = 0x00000800;
const int ADC_CR2_ALIGN_RIGHT = 0x00000000;
const int ADC_CR2_ALIGN_LEFT = 0x00000800;
// JEXTSEL[3:0] bits (External event select for injected group).
const int ADC_CR2_JEXTSEL_MASK = 0x000F0000;
// JEXTEN[1:0] bits (External Trigger Conversion mode for injected channelsp).
const int ADC_CR2_JEXTEN_MASK = 0x00300000;
// Start Conversion of injected channels.
const int ADC_CR2_JSWSTART = 0x00400000;
// EXTSEL[3:0] bits (External Event Select for regular group).
const int ADC_CR2_EXTSEL_MASK = 0x0F000000;
// EXTEN[1:0] bits (External Trigger Conversion mode for regular channelsp).
const int ADC_CR2_EXTEN_MASK = 0x30000000;
// Start Conversion of regular channels.
const int ADC_CR2_SWSTART = 0x40000000;

// Bit definition for ADC_SMPRx registers.

// Channel x Sample time mask.
const int ADC_SMPR_MASK = 0x00000007;
// Sampling time selections (ADCCLK cycles).
const int ADC_SMPR_CYCLES_3 = 0x00000000;
const int ADC_SMPR_CYCLES_15 = 0x00000001;
const int ADC_SMPR_CYCLES_28 = 0x00000002;
const int ADC_SMPR_CYCLES_56 = 0x00000003;
const int ADC_SMPR_CYCLES_84 = 0x00000004;
const int ADC_SMPR_CYCLES_112 = 0x00000005;
const int ADC_SMPR_CYCLES_144 = 0x00000006;
const int ADC_SMPR_CYCLES_480 = 0x00000007;

// Bit definition for ADC_JOFR1 register.

// Data offset for injected channel 1.
const int ADC_JOFR1_JOFFSET1_MASK = 0x0FFF;

// Bit definition for ADC_JOFR2 register.

// Data offset for injected channel 2.
const int ADC_JOFR2_JOFFSET2_MASK = 0x0FFF;

// Bit definition for ADC_JOFR3 register.

// Data offset for injected channel 3.
const int ADC_JOFR3_JOFFSET3_MASK = 0x0FFF;

// Bit definition for ADC_JOFR4 register.

// Data offset for injected channel 4.
const int ADC_JOFR4_JOFFSET4_MASK = 0x0FFF;

// Bit definition for ADC_HTR register.
const int ADC_HTR_HT_MASK = 0x0FFF; // Analog watchdog high threshold.

// Bit definition for ADC_LTR register.
const int ADC_LTR_LT_MASK = 0x0FFF; // Analog watchdog low threshold.

// Bit definition for ADC_SQRx registers.

// Regular sequence channel mask.
const int ADC_SQR_MASK = 0x0000001F;
// L[3:0] bits (Regular channel sequence length).
const int ADC_SQR1_L_MASK = 0x00F00000;

// Bit definition for ADC_JSQR register.

// JSQ1[4:0] bits (1st conversion in injected sequence).
const int ADC_JSQR_JSQ1_MASK = 0x0000001F;
// JSQ2[4:0] bits (2nd conversion in injected sequence).
const int ADC_JSQR_JSQ2_MASK = 0x000003E0;
// JSQ3[4:0] bits (3rd conversion in injected sequence).
const int ADC_JSQR_JSQ3_MASK = 0x00007C00;
// JSQ4[4:0] bits (4th conversion in injected sequence).
const int ADC_JSQR_JSQ4_MASK = 0x000F8000;
// JL[1:0] bits (Injected Sequence length).
const int ADC_JSQR_JL_MASK = 0x00300000;

// Bit definition for ADC_JDR1 register.
const int ADC_JDR1_JDATA_MASK = 0xFFFF; // Injected data.

// Bit definition for ADC_JDR2 register.
const int ADC_JDR2_JDATA_MASK = 0xFFFF; // Injected data.

// Bit definition for ADC_JDR3 register.
const int ADC_JDR3_JDATA_MASK = 0xFFFF; // Injected data.

// Bit definition for ADC_JDR4 register.
const int ADC_JDR4_JDATA_MASK = 0xFFFF; // Injected data.

// Bit definition for ADC_DR register.
const int ADC_DR_DATA_MASK = 0x0000FFFF; // Regular data.
const int ADC_DR_ADC2DATA_MASK = 0xFFFF0000; // ADC2 data.

// Bit definition for ADC_CSR register.

// ADC1 Analog watchdog flag.
const int ADC_CSR_AWD1 = 0x00000001;
// ADC1 End of conversion.
const int ADC_CSR_EOC1 = 0x00000002;
// ADC1 Injected channel end of conversion.
const int ADC_CSR_JEOC1 = 0x00000004;
// ADC1 Injected channel Start flag.
const int ADC_CSR_JSTRT1 = 0x00000008;
// ADC1 Regular channel Start flag.
const int ADC_CSR_STRT1 = 0x00000010;
// ADC1 Overrun flag.
const int ADC_CSR_OVR1 = 0x00000020;
// ADC2 Analog watchdog flag.
const int ADC_CSR_AWD2 = 0x00000100;
// ADC2 End of conversion.
const int ADC_CSR_EOC2 = 0x00000200;
// ADC2 Injected channel end of conversion.
const int ADC_CSR_JEOC2 = 0x00000400;
// ADC2 Injected channel Start flag.
const int ADC_CSR_JSTRT2 = 0x00000800;
// ADC2 Regular channel Start flag.
const int ADC_CSR_STRT2 = 0x00001000;
// ADC2 Overrun flag.
const int ADC_CSR_OVR2 = 0x00002000;
// ADC3 Analog watchdog flag.
const int ADC_CSR_AWD3 = 0x00010000;
// ADC3 End of conversion.
const int ADC_CSR_EOC3 = 0x00020000;
// ADC3 Injected channel end of conversion.
const int ADC_CSR_JEOC3 = 0x00040000;
// ADC3 Injected channel Start flag.
const int ADC_CSR_JSTRT3 = 0x00080000;
// ADC3 Regular channel Start flag.
const int ADC_CSR_STRT3 = 0x00100000;
// ADC3 Overrun flag.
const int ADC_CSR_OVR3 = 0x00200000;

// Bit definition for ADC_CCR register.

// MULTI[4:0] bits (Multi-ADC mode selection).
const int ADC_CCR_MULTI_MASK = 0x0000001F;
// DELAY[3:0] bits (Delay between 2 sampling phases).
const int ADC_CCR_DELAY_MASK = 0x00000F00;
// DMA disable selection (Multi-ADC mode).
const int ADC_CCR_DDS = 0x00002000;
// DMA[1:0] bits (Direct Memory Access mode for multimode).
const int ADC_CCR_DMA_MASK = 0x0000C000;
// ADCPRE[1:0] bits (ADC clock prescaler).
const int ADC_CCR_ADCPRE_MASK = 0x00030000;
const int ADC_CCR_ADCPRE_PCLK2_DIV_2 = 0x00000000;
const int ADC_CCR_ADCPRE_PCLK2_DIV_4 = 0x00010000;
const int ADC_CCR_ADCPRE_PCLK2_DIV_6 = 0x00020000;
const int ADC_CCR_ADCPRE_PCLK2_DIV_8 = 0x00030000;
// VBAT Enable.
const int ADC_CCR_VBATE = 0x00400000;
// Temperature Sensor and VREFINT Enable.
const int ADC_CCR_TSVREFE = 0x00800000;

// Bit definition for ADC_CDR register.

// 1st data of a pair of regular conversions.
const int ADC_CDR_DATA1_MASK = 0x0000FFFF;
// 2nd data of a pair of regular conversions.
const int ADC_CDR_DATA2_MASK = 0xFFFF0000;

// DMA controller registers.
class DMA {
  // Interrupt status registers, relative to DMA controller base.
  static const int LISR = 0x00; // Low Interrupt Status Register.
  static const int HISR = 0x04; // High Interrupt Status Register.
  static const int LIFCR = 0x08; // Low Interrupt Flag Clear Register.
  static const int HIFCR = 0x0C; // High Interrupt Flag Clear Register.

  static const int STREAM_OFFSET = 0x18; // Stream register offset multiplier.

  // Stream registers.
  // Relative to DMA controller base + STREAM_OFFSET * stream number.
  static const int SxCR = 0x10; // Stream Configuration Register.
  static const int SxNDTR = 0x14; // Stream Number of Data Register.
  static const int SxPAR = 0x18; // Stream Peripheral Address Register.
  static const int SxM0AR = 0x1C; // Stream Memory 0 Address Register.
  static const int SxM1AR = 0x20; // Stream Memory 1 Address Register.
  static const int SxFCR = 0x24; // Stream FIFO Control Register.
}

// DMA Controller.

// Bit definitions for DMA_SxCR register.
const int DMA_SxCR_CHSEL_MASK = 0x0E000000;
const int DMA_SxCR_CHSEL_SHIFT = 25;
const int DMA_SxCR_MBURST_MASK = 0x01800000;
const int DMA_SxCR_PBURST_MASK = 0x00600000;
const int DMA_SxCR_CT = 0x00080000;
const int DMA_SxCR_DBM = 0x00040000;
const int DMA_SxCR_PL_MASK = 0x00030000;
const int DMA_SxCR_PL_LOW = 0x00000000;
const int DMA_SxCR_PL_MEDIUM = 0x00010000;
const int DMA_SxCR_PL_HIGH = 0x00020000;
const int DMA_SxCR_PL_VERY_HIGH = 0x00030000;
const int DMA_SxCR_PINCOS = 0x00008000;
const int DMA_SxCR_MSIZE_MASK = 0x00006000;
const int DMA_SxCR_MSIZE_BYTE = 0x00000000;
const int DMA_SxCR_MSIZE_HALF_WORD = 0x00002000;
const int DMA_SxCR_MSIZE_WORD = 0x00004000;
const int DMA_SxCR_PSIZE_MASK = 0x00001800;
const int DMA_SxCR_PSIZE_BYTE = 0x00000000;
const int DMA_SxCR_PSIZE_HALF_WORD = 0x00000800;
const int DMA_SxCR_PSIZE_WORD = 0x00001000;
const int DMA_SxCR_MINC = 0x00000400;
const int DMA_SxCR_PINC = 0x00000200;
const int DMA_SxCR_CIRC = 0x00000100;
const int DMA_SxCR_DIR_MASK = 0x000000C0;
const int DMA_SxCR_DIR_PERIPHERAL_TO_MEMORY = 0x00000000;
const int DMA_SxCR_DIR_MEMORY_TO_PERIPHERAL = 0x00000040;
const int DMA_SxCR_DIR_MEMORY_TO_MEMORY = 0x00000080;
const int DMA_SxCR_PFCTRL = 0x00000020;
const int DMA_SxCR_TCIE = 0x00000010;
const int DMA_SxCR_HTIE = 0x00000008;
const int DMA_SxCR_TEIE = 0x00000004;
const int DMA_SxCR_DMEIE = 0x00000002;
const int DMA_SxCR_EN = 0x00000001;

// Bit definitions for DMA_SxNDTR register.
const int DMA_SxNDTR_MASK = 0x0000FFFF;

// Bit definitions for DMA_SxFCR register.
const int DMA_SxFCR_FEIE = 0x00000080;
const int DMA_SxFCR_FS_MASK = 0x00000038;
const int DMA_SxFCR_DMDIS = 0x00000004;
const int DMA_SxFCR_FTH_MASK = 0x00000003;
const int DMA_SxFCR_FTH_1_4 = 0x00000000;
const int DMA_SxFCR_FTH_HALF = 0x00000001;
const int DMA_SxFCR_FTH_3_4 = 0x00000002;
const int DMA_SxFCR_FTH_FULL = 0x00000003;

// Bit definitions for DMA_(H/L)ISR register.
const int DMA_ISR_MASK = 0x0000003D;
const int DMA_ISR_TCIF = 0x00000020;
const int DMA_ISR_HTIF = 0x00000010;
const int DMA_ISR_TEIF = 0x00000008;
const int DMA_ISR_DMEIF = 0x00000004;
const int DMA_ISR_FEIF = 0x00000001;

// Bits definition for DMA_(H/L)IFCR register.
const int DMA_IFCR_MASK = 0x0000003D;
const int DMA_IFCR_CTCIF = 0x00000020;
const int DMA_IFCR_CHTIF = 0x00000010;
const int DMA_IFCR_CTEIF = 0x00000008;
const int DMA_IFCR_CDMEIF = 0x00000004;
const int DMA_IFCR_CFEIF = 0x00000001;

// Bit definitions taken from stm32f746xx.h CMSIS 
// Device Peripheral Access Layer Header File.

// TIMx peripheral registers.
class TIM {
  static const int CR1 = 0x00;  // TIM control register 1.
  static const int CR2 = 0x04;  // TIM control register 2.
  static const int SMCR = 0x08;  // TIM slave mode control register.
  static const int DIER = 0x0C;  // TIM DMA/interrupt enable register.
  static const int SR = 0x10;  // TIM status register.
  static const int EGR = 0x14;  // TIM event generation register.
  static const int CCMR1 = 0x18;  // TIM capture/compare mode register 1.
  static const int CCMR2 = 0x1C;  // TIM capture/compare mode register 2.
  static const int CCER = 0x20;  // TIM capture/compare enable register.
  static const int CNT = 0x24;  // TIM counter register.
  static const int PSC = 0x28;  // TIM prescaler.
  static const int ARR = 0x2C;  // TIM auto-reload register.
  static const int RCR = 0x30;  // TIM repetition counter register.
  static const int CCR1 = 0x34;  // TIM capture/compare register 1.
  static const int CCR2 = 0x38;  // TIM capture/compare register 2.
  static const int CCR3 = 0x3C;  // TIM capture/compare register 3.
  static const int CCR4 = 0x40;  // TIM capture/compare register 4.
  static const int BDTR = 0x44;  // TIM break and dead-time register.
  static const int DCR = 0x48;  // TIM DMA control register.
  static const int DMAR = 0x4C;  // TIM DMA address for full transfer.
  static const int OR = 0x50;  // TIM option register.
  static const int CCMR3 = 0x54;  // TIM capture/compare mode register 3.
  static const int CCR5 = 0x58;  // TIM capture/compare mode register 5.
  static const int CCR6 = 0x5C;  // TIM capture/compare mode register 6.
}

// Bit definition for TIM_CR1 register.
const int TIM_CR1_CEN = 0x0001;  // Counter enable
const int TIM_CR1_UDIS = 0x0002;  // Update disable.
const int TIM_CR1_URS = 0x0004;  // Update request source.
const int TIM_CR1_OPM = 0x0008;  // One pulse mode.
const int TIM_CR1_DIR = 0x0010;  // Direction.
// CMS[1:0] bits (Center-aligned mode selection).
const int TIM_CR1_CMS = 0x0060;
const int TIM_CR1_CMS_0 = 0x0020;  // Bit 0.
const int TIM_CR1_CMS_1 = 0x0040;  // Bit 1.

const int TIM_CR1_ARPE = 0x0080;  // Auto-reload preload enable.

const int TIM_CR1_CKD = 0x0300;  // CKD[1:0] bits (clock division).
const int TIM_CR1_CKD_0 = 0x0100;  // Bit 0.
const int TIM_CR1_CKD_1 = 0x0200;  // Bit 1.
const int TIM_CR1_UIFREMAP = 0x0800;  // UIF status bit.

// Bit definition for TIM_CR2 register.
// Capture/Compare Preloaded Control.
const int TIM_CR2_CCPC = 0x00000001;
// Capture/Compare Control Update Selection.
const int TIM_CR2_CCUS = 0x00000004;
// Capture/Compare DMA Selection.
const int TIM_CR2_CCDS = 0x00000008;

const int TIM_CR2_OIS5 = 0x00010000;  // Output Idle state 4 (OC4 output).
const int TIM_CR2_OIS6 = 0x00040000;  // Output Idle state 4 (OC4 output).

const int TIM_CR2_MMS = 0x0070;  // MMS[2:0] bits (Master Mode Selection).
const int TIM_CR2_MMS_0 = 0x0010;  // Bit 0.
const int TIM_CR2_MMS_1 = 0x0020;  // Bit 1.
const int TIM_CR2_MMS_2 = 0x0040;  // Bit 2.

const int TIM_CR2_MMS2 = 0x00F00000;  // MMS[2:0] bits (Master Mode Selection).
const int TIM_CR2_MMS2_0 = 0x00100000;  // Bit 0.
const int TIM_CR2_MMS2_1 = 0x00200000;  // Bit 1.
const int TIM_CR2_MMS2_2 = 0x00400000;  // Bit 2.
const int TIM_CR2_MMS2_3 = 0x00800000;  // Bit 2.

const int TIM_CR2_TI1S = 0x0080;  // TI1 Selection.
const int TIM_CR2_OIS1 = 0x0100;  // Output Idle state 1 (OC1 output).
const int TIM_CR2_OIS1N = 0x0200;  // Output Idle state 1 (OC1N output).
const int TIM_CR2_OIS2 = 0x0400;  // Output Idle state 2 (OC2 output).
const int TIM_CR2_OIS2N = 0x0800;  // Output Idle state 2 (OC2N output).
const int TIM_CR2_OIS3 = 0x1000;  // Output Idle state 3 (OC3 output).
const int TIM_CR2_OIS3N = 0x2000;  // Output Idle state 3 (OC3N output).
const int TIM_CR2_OIS4 = 0x4000;  // Output Idle state 4 (OC4 output).

// Bit definition for TIM_SMCR register.
// SMS[2:0] bits (Slave mode selection).
const int TIM_SMCR_SMS = 0x00010007;
const int TIM_SMCR_SMS_0 = 0x00000001;  // Bit 0.
const int TIM_SMCR_SMS_1 = 0x00000002;  // Bit 1.
const int TIM_SMCR_SMS_2 = 0x00000004;  // Bit 2.
const int TIM_SMCR_SMS_3 = 0x00010000;  // Bit 3.
const int TIM_SMCR_OCCS = 0x00000008;  //  OCREF clear selection.

const int TIM_SMCR_TS = 0x0070;  // TS[2:0] bits (Trigger selection).
const int TIM_SMCR_TS_0 = 0x0010;  // Bit 0.
const int TIM_SMCR_TS_1 = 0x0020;  // Bit 1.
const int TIM_SMCR_TS_2 = 0x0040;  // Bit 2.

const int TIM_SMCR_MSM = 0x0080;  // Master/slave mode.

const int TIM_SMCR_ETF = 0x0F00;  // ETF[3:0] bits (External trigger filter).
const int TIM_SMCR_ETF_0 = 0x0100;  // Bit 0.
const int TIM_SMCR_ETF_1 = 0x0200;  // Bit 1.
const int TIM_SMCR_ETF_2 = 0x0400;  // Bit 2.
const int TIM_SMCR_ETF_3 = 0x0800;  // Bit 3.
// ETPS[1:0] bits (External trigger prescaler).
const int TIM_SMCR_ETPS = 0x3000;
const int TIM_SMCR_ETPS_0 = 0x1000;  // Bit 0.
const int TIM_SMCR_ETPS_1 = 0x2000;  // Bit 1.

const int TIM_SMCR_ECE = 0x4000;  // External clock enable.
const int TIM_SMCR_ETP = 0x8000;  // External trigger polarity.

// Bit definition for TIM_DIER register.
const int TIM_DIER_UIE = 0x0001;  // Update interrupt enable.
const int TIM_DIER_CC1IE = 0x0002;  // Capture/Compare 1 interrupt enable.
const int TIM_DIER_CC2IE = 0x0004;  // Capture/Compare 2 interrupt enable.
const int TIM_DIER_CC3IE = 0x0008;  // Capture/Compare 3 interrupt enable.
const int TIM_DIER_CC4IE = 0x0010;  // Capture/Compare 4 interrupt enable.
const int TIM_DIER_COMIE = 0x0020;  // COM interrupt enable.
const int TIM_DIER_TIE = 0x0040;  // Trigger interrupt enable.
const int TIM_DIER_BIE = 0x0080;  // Break interrupt enable.
const int TIM_DIER_UDE = 0x0100;  // Update DMA request enable.
const int TIM_DIER_CC1DE = 0x0200;  // Capture/Compare 1 DMA request enable.
const int TIM_DIER_CC2DE = 0x0400;  // Capture/Compare 2 DMA request enable.
const int TIM_DIER_CC3DE = 0x0800;  // Capture/Compare 3 DMA request enable.
const int TIM_DIER_CC4DE = 0x1000;  // Capture/Compare 4 DMA request enable.
const int TIM_DIER_COMDE = 0x2000;  // COM DMA request enable.
const int TIM_DIER_TDE = 0x4000;  // Trigger DMA request enable.

// Bit definition for TIM_SR register.
const int TIM_SR_UIF = 0x0001;  // Update interrupt Flag.
const int TIM_SR_CC1IF = 0x0002;  // Capture/Compare 1 interrupt Flag.
const int TIM_SR_CC2IF = 0x0004;  // Capture/Compare 2 interrupt Flag.
const int TIM_SR_CC3IF = 0x0008;  // Capture/Compare 3 interrupt Flag.
const int TIM_SR_CC4IF = 0x0010;  // Capture/Compare 4 interrupt Flag.
const int TIM_SR_COMIF = 0x0020;  // COM interrupt Flag.
const int TIM_SR_TIF = 0x0040;  // Trigger interrupt Flag.
const int TIM_SR_BIF = 0x0080;  // Break interrupt Flag.
const int TIM_SR_B2IF = 0x0100;  // Break2 interrupt Flag.
const int TIM_SR_CC1OF = 0x0200;  // Capture/Compare 1 Overcapture Flag.
const int TIM_SR_CC2OF = 0x0400;  // Capture/Compare 2 Overcapture Flag.
const int TIM_SR_CC3OF = 0x0800;  // Capture/Compare 3 Overcapture Flag.
const int TIM_SR_CC4OF = 0x1000;  // Capture/Compare 4 Overcapture Flag.

// Bit definition for TIM_EGR register.
// Update Generation.
const int TIM_EGR_UG = 0x00000001;
// Capture/Compare 1 Generation.
const int TIM_EGR_CC1G = 0x00000002;
// Capture/Compare 2 Generation.
const int TIM_EGR_CC2G = 0x00000004;
// Capture/Compare 3 Generation.
const int TIM_EGR_CC3G = 0x00000008;
// Capture/Compare 4 Generation.
const int TIM_EGR_CC4G = 0x00000010;
// Capture/Compare Control Update Generation.
const int TIM_EGR_COMG = 0x00000020;
// Trigger Generation.
const int TIM_EGR_TG = 0x00000040;
// Break Generation.
const int TIM_EGR_BG = 0x00000080;
// Break2 Generation.
const int TIM_EGR_B2G = 0x00000100;

// Bit definition for TIM_CCMR1 register.
// CC1S[1:0] bits (Capture/Compare 1 Selection).
const int TIM_CCMR1_CC1S = 0x00000003;
const int TIM_CCMR1_CC1S_0 = 0x00000001;  // Bit 0.
const int TIM_CCMR1_CC1S_1 = 0x00000002;  // Bit 1.
// Output Compare 1 Fast enable.
const int TIM_CCMR1_OC1FE = 0x00000004;
// Output Compare 1 Preload enable.
const int TIM_CCMR1_OC1PE = 0x00000008;

// OC1M[2:0] bits (Output Compare 1 Mode).
const int TIM_CCMR1_OC1M = 0x00010070;
const int TIM_CCMR1_OC1M_0 = 0x00000010;  // Bit 0.
const int TIM_CCMR1_OC1M_1 = 0x00000020;  // Bit 1.
const int TIM_CCMR1_OC1M_2 = 0x00000040;  // Bit 2.
const int TIM_CCMR1_OC1M_3 = 0x00010000;  // Bit 3.
// Output Compare 1Clear Enable.
const int TIM_CCMR1_OC1CE = 0x00000080;
// CC2S[1:0] bits (Capture/Compare 2 Selection).
const int TIM_CCMR1_CC2S = 0x00000300;
const int TIM_CCMR1_CC2S_0 = 0x00000100;  // Bit 0.
const int TIM_CCMR1_CC2S_1 = 0x00000200;  // Bit 1.
// Output Compare 2 Fast enable.
const int TIM_CCMR1_OC2FE = 0x00000400;
// Output Compare 2 Preload enable.
const int TIM_CCMR1_OC2PE = 0x00000800;
// OC2M[2:0] bits (Output Compare 2 Mode).
const int TIM_CCMR1_OC2M = 0x01007000;
const int TIM_CCMR1_OC2M_0 = 0x00001000;  // Bit 0.
const int TIM_CCMR1_OC2M_1 = 0x00002000;  // Bit 1.
const int TIM_CCMR1_OC2M_2 = 0x00004000;  // Bit 2.
const int TIM_CCMR1_OC2M_3 = 0x01000000;  // Bit 3.

const int TIM_CCMR1_OC2CE = 0x00008000;  // Output Compare 2 Clear Enable.

/*----------------------------------------------------------------------------*/
// IC1PSC[1:0] bits (Input Capture 1 Prescaler).
const int TIM_CCMR1_IC1PSC = 0x000C;
const int TIM_CCMR1_IC1PSC_0 = 0x0004;  // Bit 0.
const int TIM_CCMR1_IC1PSC_1 = 0x0008;  // Bit 1.
// IC1F[3:0] bits (Input Capture 1 Filter).
const int TIM_CCMR1_IC1F = 0x00F0;
const int TIM_CCMR1_IC1F_0 = 0x0010;  // Bit 0.
const int TIM_CCMR1_IC1F_1 = 0x0020;  // Bit 1.
const int TIM_CCMR1_IC1F_2 = 0x0040;  // Bit 2.
const int TIM_CCMR1_IC1F_3 = 0x0080;  // Bit 3.
// IC2PSC[1:0] bits (Input Capture 2 Prescaler).
const int TIM_CCMR1_IC2PSC = 0x0C00;
const int TIM_CCMR1_IC2PSC_0 = 0x0400;  // Bit 0.
const int TIM_CCMR1_IC2PSC_1 = 0x0800;  // Bit 1.
// IC2F[3:0] bits (Input Capture 2 Filter).
const int TIM_CCMR1_IC2F = 0xF000;
const int TIM_CCMR1_IC2F_0 = 0x1000;  // Bit 0.
const int TIM_CCMR1_IC2F_1 = 0x2000;  // Bit 1.
const int TIM_CCMR1_IC2F_2 = 0x4000;  // Bit 2.
const int TIM_CCMR1_IC2F_3 = 0x8000;  // Bit 3.

// Bit definition for TIM_CCMR2 register.
// CC3S[1:0] bits (Capture/Compare 3 Selection).
const int TIM_CCMR2_CC3S = 0x00000003;
const int TIM_CCMR2_CC3S_0 = 0x00000001;  // Bit 0.
const int TIM_CCMR2_CC3S_1 = 0x00000002;  // Bit 1.
// Output Compare 3 Fast enable.
const int TIM_CCMR2_OC3FE = 0x00000004;
// Output Compare 3 Preload enable.
const int TIM_CCMR2_OC3PE = 0x00000008;
// OC3M[2:0] bits (Output Compare 3 Mode).
const int TIM_CCMR2_OC3M = 0x00010070;
const int TIM_CCMR2_OC3M_0 = 0x00000010;  // Bit 0.
const int TIM_CCMR2_OC3M_1 = 0x00000020;  // Bit 1.
const int TIM_CCMR2_OC3M_2 = 0x00000040;  // Bit 2.
const int TIM_CCMR2_OC3M_3 = 0x00010000;  // Bit 3.

const int TIM_CCMR2_OC3CE = 0x00000080;  // Output Compare 3 Clear Enable.
// CC4S[1:0] bits (Capture/Compare 4 Selection).
const int TIM_CCMR2_CC4S = 0x00000300;
const int TIM_CCMR2_CC4S_0 = 0x00000100;  // Bit 0.
const int TIM_CCMR2_CC4S_1 = 0x00000200;  // Bit 1.

const int TIM_CCMR2_OC4FE = 0x00000400;  // Output Compare 4 Fast enable.
const int TIM_CCMR2_OC4PE = 0x00000800;  // Output Compare 4 Preload enable.
// OC4M[2:0] bits (Output Compare 4 Mode).
const int TIM_CCMR2_OC4M = 0x01007000;
const int TIM_CCMR2_OC4M_0 = 0x00001000;  // Bit 0.
const int TIM_CCMR2_OC4M_1 = 0x00002000;  // Bit 1.
const int TIM_CCMR2_OC4M_2 = 0x00004000;  // Bit 2.
const int TIM_CCMR2_OC4M_3 = 0x01000000;  // Bit 3.

const int TIM_CCMR2_OC4CE = 0x8000;  // Output Compare 4 Clear Enable.

/*----------------------------------------------------------------------------*/
// IC3PSC[1:0] bits (Input Capture 3 Prescaler).
const int TIM_CCMR2_IC3PSC = 0x000C;
const int TIM_CCMR2_IC3PSC_0 = 0x0004;  // Bit 0.
const int TIM_CCMR2_IC3PSC_1 = 0x0008;  // Bit 1.

const int TIM_CCMR2_IC3F = 0x00F0;  // IC3F[3:0] bits (Input Capture 3 Filter).
const int TIM_CCMR2_IC3F_0 = 0x0010;  // Bit 0.
const int TIM_CCMR2_IC3F_1 = 0x0020;  // Bit 1.
const int TIM_CCMR2_IC3F_2 = 0x0040;  // Bit 2.
const int TIM_CCMR2_IC3F_3 = 0x0080;  // Bit 3.
// IC4PSC[1:0] bits (Input Capture 4 Prescaler).
const int TIM_CCMR2_IC4PSC = 0x0C00;
const int TIM_CCMR2_IC4PSC_0 = 0x0400;  // Bit 0.
const int TIM_CCMR2_IC4PSC_1 = 0x0800;  // Bit 1.

const int TIM_CCMR2_IC4F = 0xF000;  // IC4F[3:0] bits (Input Capture 4 Filter).
const int TIM_CCMR2_IC4F_0 = 0x1000;  // Bit 0.
const int TIM_CCMR2_IC4F_1 = 0x2000;  // Bit 1.
const int TIM_CCMR2_IC4F_2 = 0x4000;  // Bit 2.
const int TIM_CCMR2_IC4F_3 = 0x8000;  // Bit 3.

// Bit definition for TIM_CCER register.
const int TIM_CCER_CC1E = 0x00000001;  // Capture/Compare 1 output enable.
const int TIM_CCER_CC1P = 0x00000002;  // Capture/Compare 1 output Polarity.
// Capture/Compare 1 Complementary output enable.
const int TIM_CCER_CC1NE = 0x00000004;
// Capture/Compare 1 Complementary output Polarity.
const int TIM_CCER_CC1NP = 0x00000008;
const int TIM_CCER_CC2E = 0x00000010;  // Capture/Compare 2 output enable.
const int TIM_CCER_CC2P = 0x00000020;  // Capture/Compare 2 output Polarity.
// Capture/Compare 2 Complementary output enable.
const int TIM_CCER_CC2NE = 0x00000040;
// Capture/Compare 2 Complementary output Polarity.
const int TIM_CCER_CC2NP = 0x00000080;
const int TIM_CCER_CC3E = 0x00000100;  // Capture/Compare 3 output enable.
const int TIM_CCER_CC3P = 0x00000200;  // Capture/Compare 3 output Polarity.
// Capture/Compare 3 Complementary output enable.
const int TIM_CCER_CC3NE = 0x00000400;
// Capture/Compare 3 Complementary output Polarity.
const int TIM_CCER_CC3NP = 0x00000800;
const int TIM_CCER_CC4E = 0x00001000;  // Capture/Compare 4 output enable.
const int TIM_CCER_CC4P = 0x00002000;  // Capture/Compare 4 output Polarity.
// Capture/Compare 4 Complementary output Polarity.
const int TIM_CCER_CC4NP = 0x00008000;
const int TIM_CCER_CC5E = 0x00010000;  // Capture/Compare 5 output enable.
const int TIM_CCER_CC5P = 0x00020000;  // Capture/Compare 5 output Polarity.
const int TIM_CCER_CC6E = 0x00100000;  // Capture/Compare 6 output enable.
const int TIM_CCER_CC6P = 0x00200000;  // Capture/Compare 6 output Polarity.

// Bit definition for TIM_BDTR register.
// DTG[0:7] bits (Dead-Time Generator set-up).
const int TIM_BDTR_DTG = 0x000000FF;
const int TIM_BDTR_DTG_0 = 0x00000001;  // Bit 0.
const int TIM_BDTR_DTG_1 = 0x00000002;  // Bit 1.
const int TIM_BDTR_DTG_2 = 0x00000004;  // Bit 2.
const int TIM_BDTR_DTG_3 = 0x00000008;  // Bit 3.
const int TIM_BDTR_DTG_4 = 0x00000010;  // Bit 4.
const int TIM_BDTR_DTG_5 = 0x00000020;  // Bit 5.
const int TIM_BDTR_DTG_6 = 0x00000040;  // Bit 6.
const int TIM_BDTR_DTG_7 = 0x00000080;  // Bit 7.

const int TIM_BDTR_LOCK = 0x00000300;  // LOCK[1:0] bits (Lock Configuration).
const int TIM_BDTR_LOCK_0 = 0x00000100;  // Bit 0.
const int TIM_BDTR_LOCK_1 = 0x00000200;  // Bit 1.

const int TIM_BDTR_OSSI = 0x00000400;  // Off-State Selection for Idle mode.
const int TIM_BDTR_OSSR = 0x00000800;  // Off-State Selection for Run mode.
const int TIM_BDTR_BKE = 0x00001000;  // Break enable.
const int TIM_BDTR_BKP = 0x00002000;  // Break Polarity.
const int TIM_BDTR_AOE = 0x00004000;  // Automatic Output enable.
const int TIM_BDTR_MOE = 0x00008000;  // Main Output enable.
const int TIM_BDTR_BKF = 0x000F0000;  // Break Filter for Break1.
const int TIM_BDTR_BK2F = 0x00F00000;  // Break Filter for Break2.
const int TIM_BDTR_BK2E = 0x01000000;  // Break enable for Break2.
const int TIM_BDTR_BK2P = 0x02000000;  // Break Polarity for Break2.

// Bit definition for TIM_DCR register.
const int TIM_DCR_DBA = 0x001F;  // DBA[4:0] bits (DMA Base Address).
const int TIM_DCR_DBA_0 = 0x0001;  // Bit 0.
const int TIM_DCR_DBA_1 = 0x0002;  // Bit 1.
const int TIM_DCR_DBA_2 = 0x0004;  // Bit 2.
const int TIM_DCR_DBA_3 = 0x0008;  // Bit 3.
const int TIM_DCR_DBA_4 = 0x0010;  // Bit 4.

const int TIM_DCR_DBL = 0x1F00;  // DBL[4:0] bits (DMA Burst Length).
const int TIM_DCR_DBL_0 = 0x0100;  // Bit 0.
const int TIM_DCR_DBL_1 = 0x0200;  // Bit 1.
const int TIM_DCR_DBL_2 = 0x0400;  // Bit 2.
const int TIM_DCR_DBL_3 = 0x0800;  // Bit 3.
const int TIM_DCR_DBL_4 = 0x1000;  // Bit 4.

// Bit definition for TIM_OR regiter.
// TI4_RMP[1:0] bits (TIM5 Input 4 remap).
const int TIM_OR_TI4_RMP = 0x00C0;
const int TIM_OR_TI4_RMP_0 = 0x0040;  // Bit 0.
const int TIM_OR_TI4_RMP_1 = 0x0080;  // Bit 1.
// ITR1_RMP[1:0] bits (TIM2 Internal trigger 1 remap).
const int TIM_OR_ITR1_RMP = 0x0C00;
const int TIM_OR_ITR1_RMP_0 = 0x0400;  // Bit 0.
const int TIM_OR_ITR1_RMP_1 = 0x0800;  // Bit 1.

// Bit definition for TIM_CCMR3 register.
const int TIM_CCMR3_OC5FE = 0x00000004;  // Output Compare 5 Fast enable.
const int TIM_CCMR3_OC5PE = 0x00000008;  // Output Compare 5 Preload enable.
// OC5M[2:0] bits (Output Compare 5 Mode).
const int TIM_CCMR3_OC5M = 0x00010070;
const int TIM_CCMR3_OC5M_0 = 0x00000010;  // Bit 0.
const int TIM_CCMR3_OC5M_1 = 0x00000020;  // Bit 1.
const int TIM_CCMR3_OC5M_2 = 0x00000040;  // Bit 2.
const int TIM_CCMR3_OC5M_3 = 0x00010000;  // Bit 3.

const int TIM_CCMR3_OC5CE = 0x00000080;  // Output Compare 5 Clear Enable.

const int TIM_CCMR3_OC6FE = 0x00000400;  // Output Compare 4 Fast enable.
const int TIM_CCMR3_OC6PE = 0x00000800;  // Output Compare 4 Preload enable.
// OC4M[2:0] bits (Output Compare 4 Mode).
const int TIM_CCMR3_OC6M = 0x01007000;
const int TIM_CCMR3_OC6M_0 = 0x00001000;  // Bit 0.
const int TIM_CCMR3_OC6M_1 = 0x00002000;  // Bit 1.
const int TIM_CCMR3_OC6M_2 = 0x00004000;  // Bit 2.
const int TIM_CCMR3_OC6M_3 = 0x01000000;  // Bit 3.

const int TIM_CCMR3_OC6CE = 0x00008000;  // Output Compare 4 Clear Enable.

// Bit definition for TIM_CCR5 register.
const int TIM_CCR5_GC5C1 = 0x20000000;  // Group Channel 5 and Channel 1.
const int TIM_CCR5_GC5C2 = 0x40000000;  // Group Channel 5 and Channel 2.
const int TIM_CCR5_GC5C3 = 0x80000000;  // Group Channel 5 and Channel 3.

