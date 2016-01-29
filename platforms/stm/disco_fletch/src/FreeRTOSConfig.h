// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

#ifndef PLATFORMS_STM_DISCO_FLETCH_SRC_FREERTOSCONFIG_H_
#define PLATFORMS_STM_DISCO_FLETCH_SRC_FREERTOSCONFIG_H_

extern uint32_t SystemCoreClock;

#define configUSE_PREEMPTION                     1
#define configUSE_IDLE_HOOK                      0
#define configUSE_TICK_HOOK                      0
#define configCPU_CLOCK_HZ                       (SystemCoreClock)
#define configTICK_RATE_HZ                       ((TickType_t)1000)
#define configMAX_PRIORITIES                     (7)
#define configMINIMAL_STACK_SIZE                 ((uint16_t)128)
// No heap here as we are using heap_3 at the moment.
#define configTOTAL_HEAP_SIZE                    0
#define configMAX_TASK_NAME_LEN                  (16)
#define configUSE_TRACE_FACILITY                 1
#define configUSE_16_BIT_TICKS                   0
#define configUSE_MUTEXES                        1
#define configQUEUE_REGISTRY_SIZE                8
#define configCHECK_FOR_STACK_OVERFLOW           2
#define configUSE_RECURSIVE_MUTEXES              1
#define configUSE_MALLOC_FAILED_HOOK             1
#define configUSE_COUNTING_SEMAPHORES            1
#define configUSE_CO_ROUTINES                    0
#define configMAX_CO_ROUTINE_PRIORITIES          (2)

#define INCLUDE_vTaskPrioritySet            1
#define INCLUDE_uxTaskPriorityGet           1
#define INCLUDE_vTaskDelete                 1
#define INCLUDE_vTaskCleanUpResources       0
#define INCLUDE_vTaskSuspend                1
#define INCLUDE_vTaskDelayUntil             0
#define INCLUDE_vTaskDelay                  1
#define INCLUDE_xTaskGetSchedulerState      1

// Cortex-M specific definitions.
#ifdef __NVIC_PRIO_BITS
// __NVIC_PRIO_BITS will be specified when CMSIS is being used.
  #define configPRIO_BITS         __NVIC_PRIO_BITS
#else
  #define configPRIO_BITS         4
#endif

// The lowest interrupt priority that can be used in a call to a "set
// priority" function.
#define configLIBRARY_LOWEST_INTERRUPT_PRIORITY   15

// The highest interrupt priority that can be used by any interrupt
// service routine that makes calls to interrupt safe FreeRTOS API
// functions.  DO NOT CALL INTERRUPT SAFE FREERTOS API FUNCTIONS FROM
// ANY INTERRUPT THAT HAS A HIGHER PRIORITY THAN THIS! (higher
// priorities are lower numeric values. */
#define configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY 5

// Interrupt priorities used by the kernel port layer itself.  These
// are generic to all Cortex-M ports, and do not rely on any
// particular library functions.
#define configKERNEL_INTERRUPT_PRIORITY \
    (configLIBRARY_LOWEST_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))
// configMAX_SYSCALL_INTERRUPT_PRIORITY must not be set to zero.
// See http://www.FreeRTOS.org/RTOS-Cortex-M3-M4.html. */
#define configMAX_SYSCALL_INTERRUPT_PRIORITY \
    (configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))

#define configASSERT(x) if ((x) == 0) { taskDISABLE_INTERRUPTS(); for (;;); }

// Definitions that map the FreeRTOS port interrupt handlers to their
// CMSIS standard names.
#define vPortSVCHandler    SVC_Handler
#define xPortPendSVHandler PendSV_Handler

// Allocate a newlib reent structure for each created task.
#define configUSE_NEWLIB_REENTRANT 1

#endif  // PLATFORMS_STM_DISCO_FLETCH_SRC_FREERTOSCONFIG_H_
