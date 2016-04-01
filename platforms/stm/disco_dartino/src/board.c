// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include <string.h>

#include <stm32f7xx_hal.h>
#include <stm32746g_discovery_lcd.h>
#include <stm32746g_discovery_sdram.h>
#include <stm32746g_discovery_ts.h>

#include <lcd_log.h>

#include "include/static_ffi.h"

#include "platforms/stm/disco_dartino/src/device_manager_api.h"
#include "platforms/stm/disco_dartino/src/ethernet.h"
#include "platforms/stm/disco_dartino/src/socket.h"
#include "platforms/stm/disco_dartino/src/page_alloc.h"

static UartDriver uart1;
static ButtonDriver button1;

void FillUartDriver(UartDriver* driver);
void FillButtonDriver(ButtonDriver* driver);

// Definition of functions in generated/Src/mx_main.c.
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

static void FillNotAccessible(MPU_Region_InitTypeDef* mpu_init_struct) {
  mpu_init_struct->AccessPermission = MPU_REGION_NO_ACCESS;
  mpu_init_struct->IsBufferable = MPU_ACCESS_NOT_BUFFERABLE;
  mpu_init_struct->IsCacheable = MPU_ACCESS_CACHEABLE;
  mpu_init_struct->IsShareable = MPU_ACCESS_NOT_SHAREABLE;
  mpu_init_struct->TypeExtField = MPU_TEX_LEVEL0;
  mpu_init_struct->SubRegionDisable = 0x00;
  mpu_init_struct->DisableExec = MPU_INSTRUCTION_ACCESS_ENABLE;
}

static void FillCachableWriteThrough(MPU_Region_InitTypeDef* mpu_init_struct) {
  mpu_init_struct->AccessPermission = MPU_REGION_FULL_ACCESS;
  mpu_init_struct->IsBufferable = MPU_ACCESS_NOT_BUFFERABLE;
  mpu_init_struct->IsCacheable = MPU_ACCESS_CACHEABLE;
  mpu_init_struct->IsShareable = MPU_ACCESS_NOT_SHAREABLE;
  mpu_init_struct->TypeExtField = MPU_TEX_LEVEL0;
  mpu_init_struct->SubRegionDisable = 0x00;
  mpu_init_struct->DisableExec = MPU_INSTRUCTION_ACCESS_ENABLE;
}

static void ConfigureMPU() {
  MPU_Region_InitTypeDef MPU_InitStruct;
  uint8_t region_number = 0;

  // Disable the MPU for configuration.
  HAL_MPU_Disable();

  // Configure addresses 0x00000000 - 0x08000000 as not
  // accessible. Currently there is no use of the 16kb ITCM-RAM at
  // address 0x00000000.
  MPU_InitStruct.Enable = MPU_REGION_ENABLE;
  MPU_InitStruct.Number = region_number++;
  MPU_InitStruct.BaseAddress = 0x00000000;
  MPU_InitStruct.Size = MPU_REGION_SIZE_128MB;
  FillNotAccessible(&MPU_InitStruct);

  HAL_MPU_ConfigRegion(&MPU_InitStruct);

  // Configure the MPU attributes cachable and write-through for SRAM.
  MPU_InitStruct.Enable = MPU_REGION_ENABLE;
  MPU_InitStruct.Number = region_number++;
  MPU_InitStruct.BaseAddress = 0x20010000;
  MPU_InitStruct.Size = MPU_REGION_SIZE_256KB;
  FillCachableWriteThrough(&MPU_InitStruct);

  HAL_MPU_ConfigRegion(&MPU_InitStruct);

  // Configure the MPU attributes cachable and write-through for SDRAM.
  MPU_InitStruct.Enable = MPU_REGION_ENABLE;
  MPU_InitStruct.Number = region_number++;
  MPU_InitStruct.BaseAddress = 0xc0000000;
  MPU_InitStruct.Size = MPU_REGION_SIZE_8MB;
  FillCachableWriteThrough(&MPU_InitStruct);

  HAL_MPU_ConfigRegion(&MPU_InitStruct);

  // Enable the MPU with new configuration.
  HAL_MPU_Enable(MPU_PRIVILEGED_DEFAULT);
}

static void EnableCPUCache() {
  // Enable branch prediction.
  SCB->CCR |= (1 <<18);
  __DSB();

  // Enable I-Cache.
  SCB_EnableICache();

  // Enable D-Cache.
  SCB_EnableDCache();
}

// LCDLogPutchar is defined by the STM LCD log utility
// (Utilities/Log/lcd_log.c) by means of the macro definitions of
// LCD_LOG_PUTCHAR in lcd_log_conf.h.
extern int LCDLogPutchar(int ch);
static void LCDPrintIntercepter(const char* message, int out, void* data) {
  int len = strlen(message);
  if (out == 3) {
    LCD_LineColor = LCD_COLOR_RED;
  } else {
    LCD_LineColor = LCD_COLOR_BLACK;
  }
  for (int i = 0; i < len; i++) {
    LCDLogPutchar(message[i]);
  }
}

void LCDDrawLine(
    uint32_t x1, uint32_t y1, uint32_t x2, uint32_t y2) {
  // BSP_LCD_DrawLine takes uint16_t arguments.
  BSP_LCD_DrawLine(x1, y1, x2, y2);
}

DARTINO_EXPORT_STATIC_RENAME(initialize_network_stack, InitializeNetworkStack)
DARTINO_EXPORT_STATIC_RENAME(is_network_up, IsNetworkUp)
DARTINO_EXPORT_STATIC_RENAME(get_ethernet_adapter_status,
                             GetEthernetAdapterStatus)
DARTINO_EXPORT_STATIC_RENAME(get_network_address_configuration,
                             GetNetworkAddressConfiguration)

DARTINO_EXPORT_STATIC_RENAME(create_socket,
                             FreeRTOS_socket)
DARTINO_EXPORT_STATIC_RENAME(socket_connect,
                             SocketConnect)
DARTINO_EXPORT_STATIC_RENAME(network_register_socket,
                             RegisterSocket)
DARTINO_EXPORT_STATIC_RENAME(network_close_socket,
                             FreeRTOS_closesocket)
DARTINO_EXPORT_STATIC_RENAME(network_lookup_host,
                             LookupHost)
DARTINO_EXPORT_STATIC_RENAME(socket_send,
                             FreeRTOS_send)
DARTINO_EXPORT_STATIC_RENAME(socket_recv,
                             FreeRTOS_recv)
DARTINO_EXPORT_STATIC_RENAME(socket_available,
                             FreeRTOS_recvcount)
DARTINO_EXPORT_STATIC_RENAME(socket_close,
                             FreeRTOS_closesocket)
DARTINO_EXPORT_STATIC_RENAME(socket_unregister,
                             UnregisterAndCloseSocket)
DARTINO_EXPORT_STATIC_RENAME(socket_shutdown,
                             FreeRTOS_shutdown)
DARTINO_EXPORT_STATIC_RENAME(socket_reset_flags,
                             ResetSocketFlags)
DARTINO_EXPORT_STATIC_RENAME(socket_listen_for_event,
                             ListenForSocketEvent)

DARTINO_EXPORT_STATIC_RENAME(lcd_height, BSP_LCD_GetYSize)
DARTINO_EXPORT_STATIC_RENAME(lcd_width, BSP_LCD_GetXSize)
DARTINO_EXPORT_STATIC_RENAME(lcd_clear, BSP_LCD_Clear)
DARTINO_EXPORT_STATIC_RENAME(lcd_read_pixel, BSP_LCD_ReadPixel)
DARTINO_EXPORT_STATIC_RENAME(lcd_draw_pixel, BSP_LCD_DrawPixel)
DARTINO_EXPORT_STATIC_RENAME(lcd_draw_line, LCDDrawLine)
DARTINO_EXPORT_STATIC_RENAME(lcd_draw_circle, BSP_LCD_DrawCircle)
DARTINO_EXPORT_STATIC_RENAME(lcd_set_foreground_color, BSP_LCD_SetTextColor)
DARTINO_EXPORT_STATIC_RENAME(lcd_set_background_color, BSP_LCD_SetBackColor)
DARTINO_EXPORT_STATIC_RENAME(lcd_display_string, BSP_LCD_DisplayStringAt)

DARTINO_EXPORT_STATIC_RENAME(ts_init, BSP_TS_Init)
DARTINO_EXPORT_STATIC_RENAME(ts_getState, BSP_TS_GetState)

extern int InitializeBoard() {
  // Configure the MPU attributes as Write Through.
  ConfigureMPU();

  // Enable the CPU Cache.
  EnableCPUCache();

  // Reset of all peripherals, and initialize the Flash interface and
  // the Systick.
  HAL_Init();

  // Configure the system clock. Thie functions is defined in
  // generated/Src/main.c.
  SystemClock_Config();

  // Initialize all configured peripherals. These functions are
  // defined in generated/Src/mx_main.c. We are not calling
  // MX_FMC_Init, as BSP_SDRAM_Init will do all initialization of the
  // FMC.
  MX_GPIO_Init();
  MX_DCMI_Init();
  MX_DMA2D_Init();
  MX_I2C1_Init();
  MX_LTDC_Init();
  MX_QUADSPI_Init();
  MX_SDMMC1_SD_Init();
  MX_SPDIFRX_Init();
  MX_USART1_UART_Init();

  // Initialize the SDRAM (including FMC).
  BSP_SDRAM_Init();

  // Add an arena of the 8Mb of external memory.
  int ext_mem_arena = add_page_arena("ExtMem", 0xc0000000, 0x800000);

  // Register UART driver for UART1.
  FillUartDriver(&uart1);
  DeviceManagerRegisterUartDevice("uart1", &uart1);

  // Register button driver for the user button.
  FillButtonDriver(&button1);
  DeviceManagerRegisterButtonDevice("button1", &button1);

  // Initialize the LCD.
  size_t fb_bytes = (RK043FN48H_WIDTH * RK043FN48H_HEIGHT * 4);
  size_t fb_pages = get_pages_for_bytes(fb_bytes);
  void* fb = page_alloc(fb_pages, ext_mem_arena);
  BSP_LCD_Init();
  BSP_LCD_LayerDefaultInit(1, (uint32_t) fb);
  BSP_LCD_SelectLayer(1);
  BSP_LCD_SetFont(&LCD_DEFAULT_FONT);

  // Initialize LCD Log module.
  LCD_LOG_Init();
  LCD_LOG_SetHeader((unsigned char*) "Dartino");
  LCD_LOG_SetFooter((unsigned char*) "STM32746G-Discovery");

  DartinoRegisterPrintInterceptor(LCDPrintIntercepter, NULL);

  return 0;
}
