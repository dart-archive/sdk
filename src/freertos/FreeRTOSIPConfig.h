// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/*
 *  Based on the FreeRTOSIPConfig.h from
 *  FreeRTOS_Labs_160112/FreeRTOS-Plus/Demo/FreeRTOS_Plus_TCP_and_FAT_STM32F4xxx/src/
 *
 *  See the following URL for configuration information.
 *   http://www.freertos.org/FreeRTOS-Plus/FreeRTOS_Plus_TCP/TCP_IP_Configuration.html
 *
*/

#ifndef SRC_FREERTOS_FREERTOSIPCONFIG_H_
#define SRC_FREERTOS_FREERTOSIPCONFIG_H_

// This define is used inside FreeRTOS-Plus-TCP to check that the configuration
// file has been included file.
#define FREERTOS_IP_CONFIG_H

#ifdef __cplusplus
extern "C" {
#endif

#define ipconfigBYTE_ORDER pdFREERTOS_LITTLE_ENDIAN

#define ipconfigDRIVER_INCLUDED_TX_IP_CHECKSUM (1)
#define ipconfigDRIVER_INCLUDED_RX_IP_CHECKSUM (1)

#define ipconfigSOCK_DEFAULT_RECEIVE_BLOCK_TIME (5000)
#define ipconfigSOCK_DEFAULT_SEND_BLOCK_TIME (5000)

#define ipconfigZERO_COPY_RX_DRIVER (0)
#define ipconfigZERO_COPY_TX_DRIVER (0)

#define ipconfigUSE_LLMNR (0)

#define ipconfigUSE_NBNS (0)

#define ipconfigUSE_DNS_CACHE (1)
#define ipconfigDNS_CACHE_NAME_LENGTH (16)
#define ipconfigDNS_CACHE_ENTRIES (4)
#define ipconfigDNS_REQUEST_ATTEMPTS (4)

#define ipconfigIP_TASK_PRIORITY (configMAX_PRIORITIES - 2)

#define ipconfigIP_TASK_STACK_SIZE_WORDS (configMINIMAL_STACK_SIZE * 5)

extern UBaseType_t uxRand();
#define ipconfigRAND32() uxRand()

#define ipconfigUSE_NETWORK_EVENT_HOOK 1

#define ipconfigUDP_MAX_SEND_BLOCK_TIME_TICKS (5000 / portTICK_PERIOD_MS)

#define ipconfigUSE_DHCP 1
#define ipconfigDHCP_REGISTER_HOSTNAME 1
#define ipconfigDHCP_USES_UNICAST 1

#define ipconfigMAXIMUM_DISCOVER_TX_PERIOD (pdMS_TO_TICKS(5000))

#define ipconfigARP_CACHE_ENTRIES 6

#define ipconfigMAX_ARP_RETRANSMISSIONS (5)

#define ipconfigMAX_ARP_AGE 150

#define ipconfigINCLUDE_FULL_INET_ADDR 1

#if (ipconfigZERO_COPY_RX_DRIVER != 0)
#define ipconfigNUM_NETWORK_BUFFER_DESCRIPTORS (25 + 6)
#else
#define ipconfigNUM_NETWORK_BUFFER_DESCRIPTORS 25
#endif

#define ipconfigEVENT_QUEUE_LENGTH (ipconfigNUM_NETWORK_BUFFER_DESCRIPTORS + 5)

#define ipconfigALLOW_SOCKET_SEND_WITHOUT_BIND 1

#define ipconfigUDP_TIME_TO_LIVE 128
#define ipconfigTCP_TIME_TO_LIVE 128

#define ipconfigUSE_TCP (1)

#define ipconfigUSE_TCP_WIN (1)

#define ipconfigNETWORK_MTU 1500

#define ipconfigUSE_DNS 1

#define ipconfigREPLY_TO_INCOMING_PINGS 1

#define ipconfigSUPPORT_OUTGOING_PINGS 1

#define ipconfigSUPPORT_SELECT_FUNCTION 1

#define ipconfigFILTER_OUT_NON_ETHERNET_II_FRAMES 1

#define ipconfigETHERNET_DRIVER_FILTERS_FRAME_TYPES 0

#define ipconfigPACKET_FILLER_SIZE 2

#define ipconfigTCP_WIN_SEG_COUNT 64

#define ipconfigTCP_RX_BUF_LEN (3 * 1460)

#define ipconfigTCP_TX_BUF_LEN (2 * 1460)

#define ipconfigIS_VALID_PROG_ADDRESS(x) ((x) != NULL)

#define ipconfigTCP_HANG_PROTECTION (1)
#define ipconfigTCP_HANG_PROTECTION_TIME (30)

#define ipconfigTCP_KEEP_ALIVE (1)
#define ipconfigTCP_KEEP_ALIVE_INTERVAL (20) /* in seconds */

#define ipconfigUSE_FTP 0
#define ipconfigUSE_HTTP 0

#define ipconfigFTP_TX_BUFSIZE (4 * ipconfigTCP_MSS)
#define ipconfigFTP_TX_WINSIZE (2)
#define ipconfigFTP_RX_BUFSIZE (8 * ipconfigTCP_MSS)
#define ipconfigFTP_RX_WINSIZE (4)
#define ipconfigHTTP_TX_BUFSIZE (3 * ipconfigTCP_MSS)
#define ipconfigHTTP_TX_WINSIZE (2)
#define ipconfigHTTP_RX_BUFSIZE (4 * ipconfigTCP_MSS)
#define ipconfigHTTP_RX_WINSIZE (4)

extern int lUDPLoggingPrintf(const char *pcFormatString, ...);

#define ipconfigHAS_DEBUG_PRINTF 0
#if (ipconfigHAS_DEBUG_PRINTF == 1)
#define FreeRTOS_debug_printf(X) lUDPLoggingPrintf X
#endif

#define ipconfigHAS_PRINTF 0
#if (ipconfigHAS_PRINTF == 1)
#define FreeRTOS_printf(X) lUDPLoggingPrintf X
#endif

#define ipconfigDNS_USE_CALLBACKS 1
#define ipconfigSUPPORT_SIGNALS 1

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif  // SRC_FREERTOS_FREERTOSIPCONFIG_H_
