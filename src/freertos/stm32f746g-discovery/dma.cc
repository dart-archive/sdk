// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "src/freertos/stm32f746g-discovery/dma.h"

#include "include/static_ffi.h"

typedef struct {
  volatile uint32_t ISR;   // DMA interrupt status register.
  volatile uint32_t Reserved0;
  volatile uint32_t IFCR;  // DMA interrupt flag clear register.
} DMA_Base_Registers;

static void DmaTask(const void *arg) {
  const_cast<DmaStream*>(reinterpret_cast<const DmaStream*>(arg))->Task();
}

DmaStream::DmaStream(int controller, int stream)
    : Device("dma", Device::DMA_STREAM) {
  hdma_.Instance = GetInstance(controller, stream);
  CalcBaseAndBitshift(&hdma_);

  osThreadDef(DMA_TASK, DmaTask, osPriorityHigh, 0, 128);
  signalThread_ =
      osThreadCreate(osThread(DMA_TASK), reinterpret_cast<void*>(this));

  IRQn_Type irqn = GetIRQn(controller, stream);
  HAL_NVIC_SetPriority(irqn, 5, 0);
  HAL_NVIC_EnableIRQ(irqn);
}

void DmaStream::Task() {
  // Process notifications from the interrupt handlers.
  for (;;) {
    // Wait for a signal.
    osEvent event = osSignalWait(0x0000FFFF, osWaitForever);
    if (event.status == osEventSignal) {
      uint32_t flags = event.value.signals;
      // This will send a message on the event handler,
      // if there currently is an eligible listener.
      SetFlags(flags);
    }
  }
}

void DmaStream::HandleInterrupt() {
  int flags = 0;

  DMA_Base_Registers *regs =
      reinterpret_cast<DMA_Base_Registers *>(hdma_.StreamBaseAddress);

  // Transfer Error Interrupt
  if (((regs->ISR & (DMA_FLAG_TEIF0_4 << hdma_.StreamIndex)) != RESET) &&
      (__HAL_DMA_GET_IT_SOURCE(&hdma_, DMA_IT_TE) != RESET)) {
    __HAL_DMA_DISABLE_IT(&hdma_, DMA_IT_TE);
    flags |= kTransferErrorFlag;
  }
  // FIFO Error Interrupt
  if (((regs->ISR & (DMA_FLAG_FEIF0_4 << hdma_.StreamIndex)) != RESET) &&
      (__HAL_DMA_GET_IT_SOURCE(&hdma_, DMA_IT_FE) != RESET)) {
    __HAL_DMA_DISABLE_IT(&hdma_, DMA_IT_FE);
    flags |= kFifoErrorFlag;
  }
  // Direct Mode Error Interrupt
  if (((regs->ISR & (DMA_FLAG_DMEIF0_4 << hdma_.StreamIndex)) != RESET) &&
      (__HAL_DMA_GET_IT_SOURCE(&hdma_, DMA_IT_DME) != RESET)) {
    __HAL_DMA_DISABLE_IT(&hdma_, DMA_IT_DME);
    flags |= kDirectModeErrorFlag;
  }
  // Half Transfer Complete Interrupt
  if (((regs->ISR & (DMA_FLAG_HTIF0_4 << hdma_.StreamIndex)) != RESET) &&
      (__HAL_DMA_GET_IT_SOURCE(&hdma_, DMA_IT_HT) != RESET)) {
    __HAL_DMA_DISABLE_IT(&hdma_, DMA_IT_HT);
    flags |= kHalfTransferCompleteFlag;
  }
  // Transfer Complete Interrupt
  if (((regs->ISR & (DMA_FLAG_TCIF0_4 << hdma_.StreamIndex)) != RESET) &&
      (__HAL_DMA_GET_IT_SOURCE(&hdma_, DMA_IT_TC) != RESET)) {
    __HAL_DMA_DISABLE_IT(&hdma_, DMA_IT_TC);
    flags |= kTransferCompleteFlag;
  }

  if (flags != 0) {
    uint32_t result = osSignalSet(signalThread_, flags);
    ASSERT(result == osOK);
  }
}

DMA_Stream_TypeDef *DmaStream::GetInstance(int controller, int stream) {
  switch (controller) {
  case 1:
    switch (stream) {
      case 0: return DMA1_Stream0;
      case 1: return DMA1_Stream1;
      case 2: return DMA1_Stream2;
      case 3: return DMA1_Stream3;
      case 4: return DMA1_Stream4;
      case 5: return DMA1_Stream5;
      case 6: return DMA1_Stream6;
      case 7: return DMA1_Stream7;
    }
  case 2:
    switch (stream) {
      case 0: return DMA2_Stream0;
      case 1: return DMA2_Stream1;
      case 2: return DMA2_Stream2;
      case 3: return DMA2_Stream3;
      case 4: return DMA2_Stream4;
      case 5: return DMA2_Stream5;
      case 6: return DMA2_Stream6;
      case 7: return DMA2_Stream7;
    }
  }
  UNREACHABLE();
}

void DmaStream::CalcBaseAndBitshift(DMA_HandleTypeDef *hdma) {
  uint32_t stream_number = (((uint32_t)hdma->Instance & 0xFFU) - 16U) / 24U;

  // lookup table for necessary bitshift of flags within status registers
  static const uint8_t flagBitshiftOffset[8U] =
      {0U, 6U, 16U, 22U, 0U, 6U, 16U, 22U};
  hdma->StreamIndex = flagBitshiftOffset[stream_number];

  if (stream_number > 3U) {
    // use HISR and HIFCR
    hdma->StreamBaseAddress =
        (((uint32_t)hdma->Instance & (uint32_t)(~0x3FFU)) + 4U);
  } else {
    // use LISR and LIFCR
    hdma->StreamBaseAddress = ((uint32_t)hdma->Instance & (uint32_t)(~0x3FFU));
  }
}

IRQn_Type DmaStream::GetIRQn(int controller, int stream) {
  switch (controller) {
  case 1:
    switch (stream) {
      case 0: return DMA1_Stream0_IRQn;
      case 1: return DMA1_Stream1_IRQn;
      case 2: return DMA1_Stream2_IRQn;
      case 3: return DMA1_Stream3_IRQn;
      case 4: return DMA1_Stream4_IRQn;
      case 5: return DMA1_Stream5_IRQn;
      case 6: return DMA1_Stream6_IRQn;
      case 7: return DMA1_Stream7_IRQn;
    }
  case 2:
    switch (stream) {
      case 0: return DMA2_Stream0_IRQn;
      case 1: return DMA2_Stream1_IRQn;
      case 2: return DMA2_Stream2_IRQn;
      case 3: return DMA2_Stream3_IRQn;
      case 4: return DMA2_Stream4_IRQn;
      case 5: return DMA2_Stream5_IRQn;
      case 6: return DMA2_Stream6_IRQn;
      case 7: return DMA2_Stream7_IRQn;
    }
  }
  UNREACHABLE();
}

const int dma_controllers = 2;
const int streams_per_controller = 8;

static DmaStream *dma_streams_[dma_controllers][streams_per_controller];

extern "C" int DmaOpen(int controller, int stream) {
  if (controller < 1 || controller > 2) return -1;
  if (stream < 0 || stream > 7) return -1;

  int ctl_index = controller - 1;
  if (dma_streams_[ctl_index][stream] == NULL) {
    DmaStream* dma_stream = new DmaStream(controller, stream);
    dartino::DeviceManager::GetDeviceManager()->RegisterDevice(dma_stream);
    dma_streams_[ctl_index][stream] = dma_stream;
  }
  return dma_streams_[ctl_index][stream]->device_id();
}

extern "C" void DmaAcknowledgeInterrupt(int handle, int flags) {
  DeviceManagerClearFlags(handle, flags);
}

DARTINO_EXPORT_STATIC_RENAME(dma_open, DmaOpen)
DARTINO_EXPORT_STATIC_RENAME(dma_acknowledge_interrupt, DmaAcknowledgeInterrupt)

void DmaInterruptHandler(int controller, int stream) {
  DmaStream* dma_stream = dma_streams_[controller-1][stream];
  if (dma_stream != NULL) {
    dma_stream->HandleInterrupt();
  }
}

extern "C" {
void DMA1_Stream0_IRQHandler(void) { DmaInterruptHandler(1, 0); }
void DMA1_Stream1_IRQHandler(void) { DmaInterruptHandler(1, 1); }
void DMA1_Stream2_IRQHandler(void) { DmaInterruptHandler(1, 2); }
void DMA1_Stream3_IRQHandler(void) { DmaInterruptHandler(1, 3); }
void DMA1_Stream4_IRQHandler(void) { DmaInterruptHandler(1, 4); }
void DMA1_Stream5_IRQHandler(void) { DmaInterruptHandler(1, 5); }
void DMA1_Stream6_IRQHandler(void) { DmaInterruptHandler(1, 6); }
void DMA1_Stream7_IRQHandler(void) { DmaInterruptHandler(1, 7); }

void DMA2_Stream0_IRQHandler(void) { DmaInterruptHandler(2, 0); }
void DMA2_Stream1_IRQHandler(void) { DmaInterruptHandler(2, 1); }
void DMA2_Stream2_IRQHandler(void) { DmaInterruptHandler(2, 2); }
void DMA2_Stream3_IRQHandler(void) { DmaInterruptHandler(2, 3); }
void DMA2_Stream4_IRQHandler(void) { DmaInterruptHandler(2, 4); }
void DMA2_Stream5_IRQHandler(void) { DmaInterruptHandler(2, 5); }
void DMA2_Stream6_IRQHandler(void) { DmaInterruptHandler(2, 6); }
void DMA2_Stream7_IRQHandler(void) { DmaInterruptHandler(2, 7); }
}
