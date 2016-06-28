// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/freertos/stm32f746g-discovery/button_driver.h"

#include <stdlib.h>

#include <stm32f7xx_hal.h>
#include <stm32746g_discovery.h>

#include "src/vm/hash_map.h"

// Bits set from interrupt handlers.
const int kButtonPressBit = 1 << 0;

dartino::HashMap<int, ButtonDriverImpl*> openButtons =
    dartino::HashMap<int, ButtonDriverImpl*>();

ButtonDriverImpl::ButtonDriverImpl() : device_id_(kIllegalDeviceId) {
  osSemaphoreDef(button_semaphore);
  semaphore_ = osSemaphoreCreate(osSemaphore(button_semaphore), 3);
}

static void ButtonTask(const void *arg) {
  const_cast<ButtonDriverImpl*>(
      reinterpret_cast<const ButtonDriverImpl*>(arg))->Task();
}

void ButtonDriverImpl::Initialize(uintptr_t device_id) {
  ASSERT(device_id_ == kIllegalDeviceId);
  ASSERT(device_id != kIllegalDeviceId);
  device_id_ = device_id;

  openButtons[KEY_BUTTON_PIN] = this;
  osThreadDef(BUTTON_TASK, ButtonTask, osPriorityHigh, 0, 128);
  osThreadCreate(osThread(BUTTON_TASK), reinterpret_cast<void*>(this));

  // Initialize interrupt handling.
  BSP_PB_Init(BUTTON_KEY, BUTTON_MODE_EXTI);
}

void ButtonDriverImpl::NotifyRead() {
  DeviceManagerClearFlags(device_id_, kButtonPressBit);
}

void ButtonDriverImpl::DeInitialize() {
  FATAL("NOT IMPLEMENTED");
}

void ButtonDriverImpl::Task() {
  // Process notifications from the interrupt handlers.
  for (;;) {
    // Wait for an event to process.
    osSemaphoreWait(semaphore_, osWaitForever);
    // This will send a message, if there currently is an eligible listener.
    DeviceManagerSetFlags(device_id_, kButtonPressBit);
  }
}

void ButtonDriverImpl::ReturnFromInterrupt() {
  // Pass control to the thread handling interrupts.
  portBASE_TYPE xHigherPriorityTaskWoken = pdFALSE;
  osSemaphoreRelease(semaphore_);
  portEND_SWITCHING_ISR(xHigherPriorityTaskWoken);
}

extern "C" void HAL_GPIO_EXTI_Callback(uint16_t GPIO_Pin) {
  ButtonDriverImpl *button = openButtons[GPIO_Pin];
  if (button != NULL) {
    button->ReturnFromInterrupt();
  }
}

extern "C" void EXTI15_10_IRQHandler(void) {
  HAL_GPIO_EXTI_IRQHandler(KEY_BUTTON_PIN);
}

static void Initialize(ButtonDriver* driver) {
  ButtonDriverImpl* button = new ButtonDriverImpl();
  driver->context = reinterpret_cast<uintptr_t>(button);
  button->Initialize(driver->device_id);
}

static void DeInitialize(ButtonDriver* driver) {
  ButtonDriverImpl* button =
      reinterpret_cast<ButtonDriverImpl*>(driver->context);
  button->DeInitialize();
  delete button;
  driver->context = 0;
}

static void NotifyRead(ButtonDriver* driver) {
  ButtonDriverImpl* button =
      reinterpret_cast<ButtonDriverImpl*>(driver->context);
  button->NotifyRead();
}

extern "C" void FillButtonDriver(ButtonDriver* driver) {
  driver->context = 0;
  driver->device_id = kIllegalDeviceId;
  driver->Initialize = Initialize;
  driver->DeInitialize = DeInitialize;
  driver->NotifyRead = NotifyRead;
}
