// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef PLATFORMS_STM_DISCO_DARTINO_SRC_STM32F746G_DISCOVERY_ETHERNET_H_
#define PLATFORMS_STM_DISCO_DARTINO_SRC_STM32F746G_DISCOVERY_ETHERNET_H_

#include <inttypes.h>

#include <cmsis_os.h>

#include "FreeRTOSIPConfig.h"

#ifdef __cplusplus
extern "C" {
#endif

struct NetworkParameters {
  uint8_t ipAddress[4];
  uint8_t netMask[4];
  uint8_t gatewayAddress[4];
  uint8_t DNSServerAddress[4];
};

typedef struct NetworkParameters NetworkParameters;

void GetNetworkAddressConfiguration(NetworkParameters * parameters);
BaseType_t InitializeNetworkStack(NetworkParameters const * parameters);
bool IsNetworkUp();
bool NetworkAddressMayHaveChanged();
uint32_t GetEthernetAdapterStatus();
uint32_t LookupHost(const char *host, uint32_t *result);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // PLATFORMS_STM_DISCO_DARTINO_SRC_STM32F746G_DISCOVERY_ETHERNET_H_
