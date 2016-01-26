// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Configuration of the STM LCD log utility
#ifndef PLATFORMS_STM_DISCO_FLETCH_SRC_LCD_LOG_CONF_H_
#define PLATFORMS_STM_DISCO_FLETCH_SRC_LCD_LOG_CONF_H_

#include <stdio.h>

#include <stm32746g_discovery_lcd.h>

// Enable the scroll back and forward feature
#define LCD_SCROLL_ENABLED 1

// Define the Fonts.
#define LCD_LOG_HEADER_FONT Font16
#define LCD_LOG_FOOTER_FONT Font12
#define LCD_LOG_TEXT_FONT Font12

// Define the LCD LOG Color.
#define LCD_LOG_BACKGROUND_COLOR LCD_COLOR_WHITE
#define LCD_LOG_TEXT_COLOR LCD_COLOR_DARKBLUE

#define LCD_LOG_SOLID_BACKGROUND_COLOR LCD_COLOR_BLUE
#define LCD_LOG_SOLID_TEXT_COLOR LCD_COLOR_WHITE

// Define the cache depth.
#define CACHE_SIZE 100
#define YWINDOW_SIZE 17

#if (YWINDOW_SIZE > 17)
  #error "Wrong YWINDOW SIZE"
#endif

// Define the writing to the display in log utility to this signature.
#define LCD_LOG_PUTCHAR int LCDLogPutchar(int ch)

#endif  // PLATFORMS_STM_DISCO_FLETCH_SRC_LCD_LOG_CONF_H_
