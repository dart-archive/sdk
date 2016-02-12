// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "platforms/stm/disco_dartino/src/button.h"

#include <stdlib.h>

#include <stm32f7xx_hal.h>
#include <stm32746g_discovery.h>

#include "src/vm/hash_map.h"

// Bits set from interrupt handlers.
const int kButtonPressBit = 1 << 0;

dartino::HashMap<int, Button*> openButtons =
    dartino::HashMap<int, Button*>();

Button::Button() : device_(this) {
  osSemaphoreDef(button_semaphore);
  semaphore_ = osSemaphoreCreate(osSemaphore(button_semaphore), 3);
}

static void ButtonTask(const void *arg) {
  const_cast<Button*>(reinterpret_cast<const Button*>(arg))->Task();
}

int Button::Open() {
  int handle_ =
      dartino::DeviceManager::GetDeviceManager()->InstallDevice(&device_);
  openButtons[KEY_BUTTON_PIN] = this;
  osThreadDef(BUTTON_TASK, ButtonTask, osPriorityHigh, 0, 1024);
  osThreadCreate(osThread(BUTTON_TASK), reinterpret_cast<void*>(this));
  // Initialize interrupt handling.
  BSP_PB_Init(BUTTON_KEY, BUTTON_MODE_EXTI);

  return handle_;
}

void Button::NotifyRead() {
  device_.ClearFlag(kButtonPressBit);
}

void Button::Task() {
  // Process notifications from the interrupt handlers.
  for (;;) {
    // Wait for an event to process.
    osSemaphoreWait(semaphore_, osWaitForever);
    // This will send a message, if there currently is an eligible listener.
    device_.SetFlag(kButtonPressBit);
  }
}

Button *GetButton(int handle) {
  return reinterpret_cast<Button*>(
      dartino::DeviceManager::GetDeviceManager()->GetDevice(handle)->GetData());
}

void Button::ReturnFromInterrupt() {
  // Pass control to the thread handling interrupts.
  portBASE_TYPE xHigherPriorityTaskWoken = pdFALSE;
  osSemaphoreRelease(semaphore_);
  portEND_SWITCHING_ISR(xHigherPriorityTaskWoken);
}

extern "C" void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin) {
  Button *button = openButtons[GPIO_Pin];
  if (button != NULL) {
    button->ReturnFromInterrupt();
  }
}

extern "C" void EXTI15_10_IRQHandler(void) {
  HAL_GPIO_EXTI_IRQHandler(KEY_BUTTON_PIN);
}
