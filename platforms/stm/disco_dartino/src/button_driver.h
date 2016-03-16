// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef PLATFORMS_STM_DISCO_DARTINO_SRC_BUTTON_DRIVER_H_
#define PLATFORMS_STM_DISCO_DARTINO_SRC_BUTTON_DRIVER_H_

#include <cmsis_os.h>
#include <stm32f7xx_hal.h>

#include <cinttypes>

#include "platforms/stm/disco_dartino/src/device_manager.h"
#include "src/shared/platform.h"

// Interface to the user button.
class ButtonDriverImpl {
 public:
  ButtonDriverImpl();

  // Initialize the button.
  void Initialize(uintptr_t device_id);

  // De-initialize the UART.
  void DeInitialize();

  // Clears the press flag.
  void NotifyRead();

  void Task();

  void ReturnFromInterrupt();

 private:
  // Device ID returned from device driver registration.
  uintptr_t device_id_;

  // Used to signal new events from the event handler.
  osSemaphoreId semaphore_;
};

#endif  // PLATFORMS_STM_DISCO_DARTINO_SRC_BUTTON_DRIVER_H_
