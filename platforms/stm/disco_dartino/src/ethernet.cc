// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#include "platforms/stm/disco_dartino/src/ethernet.h"

#include <stdlib.h>
#include <time.h>
#include <stdarg.h>

#include <stm32746g_discovery.h>
#include <stm32746g_discovery_lcd.h>

#include "include/dartino_api.h"
#include "include/static_ffi.h"

#include "platforms/stm/disco_dartino/src/dartino_entry.h"
#include "platforms/stm/disco_dartino/src/page_allocator.h"
#include "src/shared/utils.h"

#include "FreeRTOS.h"
#include "FreeRTOSIPConfig.h"
#include "FreeRTOS_IP.h"
#include "FreeRTOS_Sockets.h"


// The value of the ethernet adapters "Basic Mode Status Register".  This value
// is updated by the driver and can be used, e.g., to check for link status,
// link speed, and duplex mode.
extern uint32_t bmsrValue;

// The MAC_ADDRx constants are currently defined in FreeRTOSIPConfig.h.
uint8_t MACAddress[6] = {MAC_ADDR0, MAC_ADDR1, MAC_ADDR2, MAC_ADDR3, MAC_ADDR4,
                         MAC_ADDR5};

static int networkIsUp = 0;

uint8_t IsNetworkUp() {
  return networkIsUp;
}

void GetNetworkAddressConfiguration(NetworkParameters * parameters) {
  FreeRTOS_GetAddressConfiguration(
      reinterpret_cast<uint32_t *>(parameters->ipAddress),
      reinterpret_cast<uint32_t *>(parameters->netMask),
      reinterpret_cast<uint32_t *>(parameters->gatewayAddress),
      reinterpret_cast<uint32_t *>(parameters->DNSServerAddress));
}

// TODO(karlklose): this function should take an adapter index as argument when
// we support multiple physical ethernet units.
uint32_t GetEthernetAdapterStatus() {
  return bmsrValue;
}

BaseType_t InitializeNetworkStack(NetworkParameters const * parameters) {
  BaseType_t result = pdFAIL;
  // Initialize random number generator for use in uxRand.
  srand(time(NULL));
  result = FreeRTOS_IPInit(parameters->ipAddress,
                           parameters->netMask,
                           parameters->gatewayAddress,
                           parameters->DNSServerAddress,
                           MACAddress);
  return result;
}

UBaseType_t uxRand() {
  return rand();
}

BaseType_t xApplicationDNSQueryHook(const char *pcName ) {
  return strcasecmp( pcName, "disco_dartino") == 0;
}

const char *pcApplicationHostnameHook() {
  return "disco_dartino";
}

void vApplicationIPNetworkEventHook(eIPCallbackEvent_t eNetworkEvent) {
  if (eNetworkEvent == eNetworkUp) {
    networkIsUp = 1;
  } else {
    networkIsUp = 0;
  }
}

// This empty implementation is expected to exist by the framework.
void vApplicationPingReplyHook(ePingReplyStatus_t eStatus,
                               uint16_t usIdentifier) {}

// Debug printing function.  Enable printing in FreeRTOSIPConfig.h.
int lUDPLoggingPrintf(const char *format, ...) {
  va_list argptr;
  va_start(argptr, format);
  int result = vfprintf(stderr, format, argptr);
  va_end(argptr);
  return result;
}
