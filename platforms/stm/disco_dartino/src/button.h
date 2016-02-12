// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef PLATFORMS_STM_DISCO_DARTINO_SRC_BUTTON_H_
#define PLATFORMS_STM_DISCO_DARTINO_SRC_BUTTON_H_

#include <cmsis_os.h>
#include <stm32f7xx_hal.h>

#include <cinttypes>

#include "src/shared/platform.h"
#include "platforms/stm/disco_dartino/src/device_manager.h"

// Interface to the user button.
class Button {
 public:
  // Access the UserButton.
  Button();

  // Open the user button. Returns the device id used for listening.
  int Open();

  // Clears the press flag.
  void NotifyRead();

  void Task();

  void ReturnFromInterrupt();

 private:
  // Used to signal new events from the event handler.
  osSemaphoreId semaphore_;

  dartino::Device device_;
};

Button *GetButton(int handle);

#endif  // PLATFORMS_STM_DISCO_DARTINO_SRC_BUTTON_H_
