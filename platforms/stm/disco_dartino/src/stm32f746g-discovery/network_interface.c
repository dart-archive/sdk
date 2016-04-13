// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Low-level driver for the LAN8720A chipset.  Based on the F7xxx driver shipped
// with FreeRTOS-Plus-TCP which can be find along with its license at:
//   FreeRTOS-Plus-TCP/portable/NetworkInterface/STM32Fxx/NetworkInterface.c

// This file is (partly) formatted using the FreeRTOS code style because we
// might want to contribute it back to the FreeRTOS-Plus-TCP project.


#include <FreeRTOS.h>
#include <assert.h>
#include <task.h>
#include <FreeRTOS_IP.h>
#include <FreeRTOS_Sockets.h>
#include <FreeRTOS_IP_Private.h>
#include <NetworkBufferManagement.h>
#include <NetworkInterface.h>
#include <stm32f7xx_hal.h>

// TODO(karlklose): evaluate, if this driver can be used for other standard
// chipsets as well.
#ifndef LAN8742A_PHY_ADDRESS
  #error This device driver is for the LAN8720A PHY.
#endif

// Interrupt events to process. This driver only processes RX events at the
// moment.
#define EMAC_IF_RX_EVENT 1UL
#define EMAC_IF_TX_EVENT 2UL
#define EMAC_IF_ERR_EVENT 4UL
#define EMAC_IF_ALL_EVENT \
  (EMAC_IF_RX_EVENT | EMAC_IF_TX_EVENT | EMAC_IF_ERR_EVENT)

// Register addresses.
#define PHY_REG_00_BMCR 0x00  // Basic mode control register.
#define PHY_REG_01_BMSR 0x01  // Basic mode status register.

#define BMSR_LINK_STATUS 0x0004UL

// A copy of the status register. This value is updated in the handler task.
uint32_t bmsrValue = 0;

#if !defined(ipconfigETHERNET_AN_ENABLE)
/* Enable auto-negotiation */
#define ipconfigETHERNET_AN_ENABLE 1
#endif

#if !defined(ipconfigETHERNET_AUTO_CROSS_ENABLE)
#define ipconfigETHERNET_AUTO_CROSS_ENABLE 1
#endif

#if (ipconfigETHERNET_AN_ENABLE == 0)
  #error Only auto-negotiation supported currently.
#endif /* ipconfigETHERNET_AN_ENABLE == 0 */

#ifndef configEMAC_TASK_STACK_SIZE
#define configEMAC_TASK_STACK_SIZE (2 * configMINIMAL_STACK_SIZE)
#endif

// Bit map of outstanding ETH interrupt events for processing.  This variable is
// updated by the IRQ handler and read by the handler task.
static volatile uint32_t ulISREvents;

/* Ethernet handle. */
static ETH_HandleTypeDef xETH;

/* Holds the handle of the task used as a deferred interrupt processor.  The
   handle is used so direct notifications can be sent to the task for all
   EMAC/DMA
   related interrupts. */
static TaskHandle_t NetworkTaskHandle = NULL;

/*
 * The description and data buffers for receiving and sending. These are located
 * in fast memory in the linker script.
 */
ETH_DMADescTypeDef  DMARxDscrTab[ETH_RXBUFNB]
    __attribute__((section(".RxDescripSection")));
ETH_DMADescTypeDef  DMATxDscrTab[ETH_TXBUFNB]
     __attribute__((section(".TxDescripSection")));
uint8_t Rx_Buff[ETH_RXBUFNB][ETH_RX_BUF_SIZE]
     __attribute__((section(".RxBUF")));
uint8_t Tx_Buff[ETH_TXBUFNB][ETH_TX_BUF_SIZE]
     __attribute__((section(".TxBUF")));


extern const uint8_t MACAddress[6];


static BaseType_t NetworkInterfaceInput(void);

// The main handler task, which calls NetworkInterfaceInput for each arriving
// packet.  TODO(karlklose): add packet filtering.
static void NetworkHandlerTask(void *pvParameters) {
  (void)pvParameters;

  const TickType_t timeout = pdMS_TO_TICKS(500UL);

  for (;;) {
    // Update the global copy of the device status register.
    HAL_ETH_ReadPHYRegister(&xETH, PHY_REG_01_BMSR, &bmsrValue);

    if ((ulISREvents & EMAC_IF_ALL_EVENT) == 0) {
      // No events to process now, wait for the next timeout.
      ulTaskNotifyTake(pdFALSE, timeout);
    }

    if ((ulISREvents & EMAC_IF_RX_EVENT) != 0) {
      // This may accidentially clear a RX bit set in the IRQ handler, when the
      // two operations overlap, but we attempt to read as much as possible in
      // the following loop, so we do not actually skip frames.
      // TODO(karlklose): use a mutex here?
      ulISREvents &= ~EMAC_IF_RX_EVENT;
      while (NetworkInterfaceInput() > 0);
    }
  }
}


// Called from the HAL when a frame has been received.
void HAL_ETH_RxCpltCallback(ETH_HandleTypeDef *heth) {
  BaseType_t xHigherPriorityTaskWoken = 0;

  ulISREvents |= EMAC_IF_RX_EVENT;
  vTaskNotifyGiveFromISR(NetworkTaskHandle, &xHigherPriorityTaskWoken);
  portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}


BaseType_t xNetworkInterfaceInitialise(void) {
  HAL_StatusTypeDef hal_eth_init_status;

  /* Initialise ETH */
  xETH.Instance = ETH;
  xETH.Init.AutoNegotiation = ETH_AUTONEGOTIATION_ENABLE;
  xETH.Init.Speed = ETH_SPEED_100M;
  xETH.Init.DuplexMode = ETH_MODE_FULLDUPLEX;
  xETH.Init.PhyAddress = LAN8742A_PHY_ADDRESS;
  xETH.Init.MACAddr = (uint8_t *) MACAddress;
  xETH.Init.RxMode = ETH_RXINTERRUPT_MODE;
  xETH.Init.ChecksumMode = ETH_CHECKSUM_BY_HARDWARE;
  xETH.Init.MediaInterface = ETH_MEDIA_INTERFACE_RMII;

  hal_eth_init_status = HAL_ETH_Init(&xETH);

  if (hal_eth_init_status != HAL_OK) {
    return pdFAIL;
  }

  // Initialize Tx and Rx descriptor in chain mode.
  HAL_ETH_DMATxDescListInit(&xETH, DMATxDscrTab, Tx_Buff[0], ETH_TXBUFNB);
  HAL_ETH_DMARxDescListInit(&xETH, DMARxDscrTab, Rx_Buff[0], ETH_RXBUFNB);

  if (NetworkTaskHandle == NULL) {
    xTaskCreate(NetworkHandlerTask, "EMAC", configEMAC_TASK_STACK_SIZE, NULL,
                configMAX_PRIORITIES - 1, &NetworkTaskHandle);
  }

  HAL_ETH_Start(&xETH);

  return pdPASS;
}


// Transfers a packet to the ethernet interface for sending.
BaseType_t xNetworkInterfaceOutput(
    xNetworkBufferDescriptor_t *const pxDescriptor,
    BaseType_t bReleaseAfterSend) {
  BaseType_t xReturn;
  uint32_t ulTransmitSize = 0;
  __IO ETH_DMADescTypeDef *pxDmaTxDesc;

#if (ipconfigDRIVER_INCLUDED_TX_IP_CHECKSUM != 0)
  {
    ProtocolPacket_t *pxPacket;

    /* If the peripheral must calculate the checksum, it wants
       the protocol checksum to have a value of zero. */
    pxPacket = (ProtocolPacket_t *)(pxDescriptor->pucEthernetBuffer);

    switch (pxPacket->xTCPPacket.xIPHeader.ucProtocol) {
      case ipPROTOCOL_ICMP:
        pxPacket->xICMPPacket.xICMPHeader.usChecksum = (uint16_t)0u;
        break;
      case ipPROTOCOL_UDP:
        pxPacket->xUDPPacket.xUDPHeader.usChecksum = (uint16_t)0u;
        break;
#if (ipconfigUSE_TCP == 1)
      case ipPROTOCOL_TCP:
        pxPacket->xTCPPacket.xTCPHeader.usChecksum = (uint16_t)0u;
        break;
#endif /* ipconfigUSE_TCP */
    }
  }
#endif

  /* This function does the actual transmission of the packet. The packet is
     contained in 'pxDescriptor' that is passed to the function. */
  pxDmaTxDesc = xETH.TxDesc;

  /* Is this buffer available? */
  if ((pxDmaTxDesc->Status & ETH_DMATXDESC_OWN) != 0) {
    xReturn = pdFAIL;
  } else {
    /* Get bytes in current buffer. */
    ulTransmitSize = pxDescriptor->xDataLength;

    assert(ulTransmitSize <= ETH_TX_BUF_SIZE);

    /* Copy the remaining bytes */
    memcpy((void *)pxDmaTxDesc->Buffer1Addr, pxDescriptor->pucEthernetBuffer,
           ulTransmitSize);

    /* Prepare transmit descriptors to give to DMA. */
    HAL_ETH_TransmitFrame(&xETH, ulTransmitSize);

    iptraceNETWORK_INTERFACE_TRANSMIT();
    xReturn = pdPASS;
  }

#if (ipconfigZERO_COPY_TX_DRIVER == 0)
  {
    /* The buffer has been sent so can be released. */
    if (bReleaseAfterSend != pdFALSE) {
      vReleaseNetworkBufferAndDescriptor(pxDescriptor);
    }
  }
#endif

  return xReturn;
}


// Transfers a received packet from the ethernet adapter to the network stack.
static BaseType_t NetworkInterfaceInput(void) {
  xNetworkBufferDescriptor_t *pxDescriptor;
  uint16_t usReceivedLength;
  __IO ETH_DMADescTypeDef *xDMARxDescriptor;
  uint32_t ulSegCount;
  xIPStackEvent_t xRxEvent = {eNetworkRxEvent, NULL};
  const TickType_t xDescriptorWaitTime = pdMS_TO_TICKS(250);

  /* get received frame */
  if (HAL_ETH_GetReceivedFrame(&xETH) != HAL_OK) {
    usReceivedLength = 0;
  } else {
    /* Obtain the size of the packet and put it into the "usReceivedLength"
     * variable. */
    usReceivedLength = xETH.RxFrameInfos.length;

    if (usReceivedLength > 0) {
      /* Create a buffer of the required length. */
      pxDescriptor = pxGetNetworkBufferWithDescriptor(usReceivedLength,
                                                      xDescriptorWaitTime);

      if (pxDescriptor != NULL) {
        xDMARxDescriptor = xETH.RxFrameInfos.FSRxDesc;

        /* Copy remaining data. */
        if (usReceivedLength > pxDescriptor->xDataLength) {
          usReceivedLength = pxDescriptor->xDataLength;
        }

        memcpy(pxDescriptor->pucEthernetBuffer,
               (uint8_t *)xETH.RxFrameInfos.buffer, usReceivedLength);

        xRxEvent.pvData = (void *)pxDescriptor;

        /* Pass the data to the TCP/IP task for processing. */
        if (xSendEventStructToIPTask(&xRxEvent, xDescriptorWaitTime) ==
            pdFALSE) {
          /* Could not send the descriptor into the TCP/IP stack, it
             must be released. */
          vReleaseNetworkBufferAndDescriptor(pxDescriptor);
          iptraceETHERNET_RX_EVENT_LOST();
        } else {
          iptraceNETWORK_INTERFACE_RECEIVE();
        }

        /* Release descriptors to DMA.  Point to first descriptor. */
        xDMARxDescriptor = xETH.RxFrameInfos.FSRxDesc;
        ulSegCount = xETH.RxFrameInfos.SegCount;

        /* Set Own bit in RX descriptors: gives the buffers back to
           DMA. */
        while (ulSegCount != 0) {
          xDMARxDescriptor->Status |= ETH_DMARXDESC_OWN;
          xDMARxDescriptor =
              (ETH_DMADescTypeDef *)xDMARxDescriptor->Buffer2NextDescAddr;
          ulSegCount--;
        }

        /* Clear Segment_Count */
        xETH.RxFrameInfos.SegCount = 0;
      } else {
        FreeRTOS_printf(
            ("NetworkInterfaceInput: pxGetNetworkBuffer failed length %u\n",
             usReceivedLength));
      }
    } else {
      FreeRTOS_printf(("NetworkInterfaceInput: zero-sized packet?\n"));
    }

    /* When Rx Buffer unavailable flag is set clear it and resume
       reception. */
    if ((xETH.Instance->DMASR & ETH_DMASR_RBUS) != 0) {
      /* Clear RBUS ETHERNET DMA flag. */
      xETH.Instance->DMASR = ETH_DMASR_RBUS;

      /* Resume DMA reception. */
      xETH.Instance->DMARPDR = 0;
    }
  }

  return (usReceivedLength > 0);
}


void ETH_IRQHandler(void) {
  // The HAL IRQ handler will call back for received packages.
  HAL_ETH_IRQHandler(&xETH);
}
