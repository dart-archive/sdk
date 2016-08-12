// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef SRC_FREERTOS_STM32F411XE_NUCLEO_DMA_H_
#define SRC_FREERTOS_STM32F411XE_NUCLEO_DMA_H_

#include <stm32f4xx_hal.h>
#include <stm32f4xx_hal_dma.h>

#include "src/freertos/device_manager.h"

// Bits set from the interrupt handler.
const int kTransferCompleteFlag = 1 << 0;
const int kHalfTransferCompleteFlag = 1 << 1;
const int kTransferErrorFlag = 1 << 3;
const int kDirectModeErrorFlag = 1 << 4;
const int kFifoErrorFlag = 1 << 5;

class DmaStream: public dartino::Device {
 public:
  DmaStream(int controller, int stream);

  void Task();
  void HandleInterrupt();

 private:
  DMA_HandleTypeDef hdma_;
  osThreadId signalThread_;

  DMA_Stream_TypeDef *GetInstance(int controller, int stream);
  void CalcBaseAndBitshift(DMA_HandleTypeDef *hdma);
  IRQn_Type GetIRQn(int controller, int stream);
};

extern "C" int DmaOpen(int controller, int stream);
extern "C" void DmaAcknowledgeInterrupt(int handle, int flags);


#endif  // SRC_FREERTOS_STM32F411XE_NUCLEO_DMA_H_
