// Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <stm32f7xx_hal.h>
#include <cmsis_os.h>

extern "C" {
#include "platforms/stm/disco_fletch/generated/Inc/lwip.h"
}

#include "src/shared/assert.h"

#include "platforms/stm/disco_fletch/src/fletch_entry.h"

// Definition of functions in generated/Src/mx_main.c.
extern "C" {
void SystemClock_Config(void);
void MX_GPIO_Init(void);
void MX_DCMI_Init(void);
void MX_DMA2D_Init(void);
void MX_FMC_Init(void);
void MX_I2C1_Init(void);
void MX_LTDC_Init(void);
void MX_QUADSPI_Init(void);
void MX_SDMMC1_SD_Init(void);
void MX_SPDIFRX_Init(void);
void MX_USART1_UART_Init(void);
}

int main(void) {
  // Reset of all peripherals, and initialize the Flash interface and
  // the Systick.
  HAL_Init();

  // Configure the system clock. Thie functions is defined in
  // generated/Src/main.c.
  SystemClock_Config();

  // Initialize all configured peripherals. These functions are
  // defined in generated/Src/mx_main.c.
  MX_GPIO_Init();
  MX_DCMI_Init();
  MX_DMA2D_Init();
  MX_FMC_Init();
  MX_I2C1_Init();
  MX_LTDC_Init();
  MX_QUADSPI_Init();
  MX_SDMMC1_SD_Init();
  MX_SPDIFRX_Init();
  MX_USART1_UART_Init();

  // init code for LWIP. This function is defined in
  // generated/Src/lwip.c.
  MX_LWIP_Init();

  osThreadDef(mainTask, FletchEntry, osPriorityNormal, 0, 4 * 1024);
  osThreadId mainTaskHandle = osThreadCreate(osThread(mainTask), NULL);
  USE(mainTaskHandle);

  // Start the scheduler.
  osKernelStart();

  // We should never get as the scheduler should never terminate.
  FATAL("Returned from scheduler");
}
