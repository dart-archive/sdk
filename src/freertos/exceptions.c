// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Defines exception handlers for ARM.

#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>

#define USE(x) ((x))

// Defines 'read only' structure member permissions
#define __IM volatile const
// Defines 'write only' structure member permissions
#define __OM volatile
// Defines 'read / write' structure member permissions
#define __IOM volatile

typedef struct {
  // CPUID Base Register
  __IM  uint32_t CPUID;
  // Interrupt Control and State Register
  __IOM uint32_t ICSR;
  // Vector Table Offset Register
  __IOM uint32_t VTOR;
  // Application Interrupt and Reset Control Register
  __IOM uint32_t AIRCR;
  // System Control Register
  __IOM uint32_t SCR;
  // Configuration Control Register
  __IOM uint32_t CCR;
  // System Handlers Priority Registers (4-7, 8-11, 12-15)
  __IOM uint8_t  SHPR[12U];
  // System Handler Control and State Register
  __IOM uint32_t SHCSR;
  // Configurable Fault Status Register
  __IOM uint32_t CFSR;
  // HardFault Status Register
  __IOM uint32_t HFSR;
  // Debug Fault Status Register
  __IOM uint32_t DFSR;
  // MemManage Fault Address Register
  __IOM uint32_t MMFAR;
  // BusFault Address Register
  __IOM uint32_t BFAR;
  // Auxiliary Fault Status Register
  __IOM uint32_t AFSR;
  // Processor Feature Register
  __IM  uint32_t ID_PFR[2U];
  // Debug Feature Register
  __IM  uint32_t ID_DFR;
  // Auxiliary Feature Register
  __IM  uint32_t ID_AFR;
  // Memory Model Feature Register
  __IM  uint32_t ID_MFR[4U];
  // Instruction Set Attributes Register
  __IM  uint32_t ID_ISAR[5U];
  uint32_t RESERVED0[1U];
  // Cache Level ID register
  __IM  uint32_t CLIDR;
  // Cache Type register
  __IM  uint32_t CTR;
  // Cache Size ID Register
  __IM  uint32_t CCSIDR;
  // Cache Size Selection Register
  __IOM uint32_t CSSELR;
  // Coprocessor Access Control Register
  __IOM uint32_t CPACR;
  uint32_t RESERVED3[93U];
  // Software Triggered Interrupt Register
  __OM  uint32_t STIR;
  uint32_t RESERVED4[15U];
  // Media and VFP Feature Register 0
  __IM  uint32_t MVFR0;
  // Media and VFP Feature Register 1
  __IM  uint32_t MVFR1;
  // Media and VFP Feature Register 1
  __IM  uint32_t MVFR2;
  uint32_t RESERVED5[1U];
  // I-Cache Invalidate All to PoU
  __OM  uint32_t ICIALLU;
  uint32_t RESERVED6[1U];
  // I-Cache Invalidate by MVA to PoU
  __OM  uint32_t ICIMVAU;
  // D-Cache Invalidate by MVA to PoC
  __OM  uint32_t DCIMVAC;
  // D-Cache Invalidate by Set-way
  __OM  uint32_t DCISW;
  // D-Cache Clean by MVA to PoU
  __OM  uint32_t DCCMVAU;
  // D-Cache Clean by MVA to PoC
  __OM  uint32_t DCCMVAC;
  // D-Cache Clean by Set-way
  __OM  uint32_t DCCSW;
  // D-Cache Clean and Invalidate by MVA to PoC
  __OM  uint32_t DCCIMVAC;
  // D-Cache Clean and Invalidate by Set-way
  __OM  uint32_t DCCISW;
  uint32_t RESERVED7[6U];
  // Instruction Tightly-Coupled Memory Control Register
  __IOM uint32_t ITCMCR;
  // Data Tightly-Coupled Memory Control Registers
  __IOM uint32_t DTCMCR;
  // AHBP Control Register
  __IOM uint32_t AHBPCR;
  // L1 Cache Control Register
  __IOM uint32_t CACR;
  // AHB Slave Control Register
  __IOM uint32_t AHBSCR;
  uint32_t RESERVED8[1U];
  // Auxiliary Bus Fault Status Register
  __IOM uint32_t ABFSR;
} SCB_Type;

// System Control Space Base Address.
#define SCS_BASE (0xE000E000UL)

// System Control Block Base Address.
#define SCB_BASE (SCS_BASE + 0x0D00UL)

// SCB configuration struct.
#define SCB ((SCB_Type*) SCB_BASE)

// When entering an exception handler LR holds the EXC_RETURN
// value. This value describes how to return from the exception
// handler. It can take the following 6 values:
//
// fffffff1  ...10001  handler, non-fp, msp
// fffffff9  ...11001  thread, non-fp, msp
// fffffffd  ...11101  thread, non-fp, psp

// ffffffe1  ...00001  handler, fp, msp
// ffffffe9  ...01001  thread, fp, msp
// ffffffed  ...01101  thread, fp, psp
//              FHS
//
// Bits[5:3] (FSH above) describe how to return.
//
// Bit F: 0 exception return uses floating-point-state (from MSP or PSP
//          depending on the value of bit S)
//        1 exception return uses non-floating-point-state (from MSP or PSP
//          depending on the value of bit S)
// Bit H: 0 exception returns to handler mode
//        1 exception returns to thread mode
// Bit S: 0 exception uses MSP after return
//        1 exception uses PSP after return
//
// Information extracted from:
// http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.dui0553a/Babefdjc.html

// Registers pushed when entering the exception handler.
struct arm_cm_exception_frame {
  uint32_t r0;
  uint32_t r1;
  uint32_t r2;
  uint32_t r3;
  uint32_t r12;
  uint32_t lr;
  uint32_t pc;
  uint32_t psr;
};

// Registers not pushed when entering the exception handler.
struct arm_cm_additional_registers {
  uint32_t r4;
  uint32_t r5;
  uint32_t r6;
  uint32_t r7;
  uint32_t r8;
  uint32_t r9;
  uint32_t r10;
  uint32_t r11;
};

static void hardfault(struct arm_cm_exception_frame *frame,
                      struct arm_cm_additional_registers *regs) {
  volatile uint32_t hfsr = SCB->HFSR;

  USE(hfsr);

  while (1);
}

struct memmanage_cause {
  bool instruction_fault;
  bool data_fault;
  bool fault_on_exception_return;
  bool fault_on_exception_entry;
  bool fault_on_lazy_fpu_preserve;
  bool valid_fault_address;
};

static void memmanage(struct arm_cm_exception_frame *frame,
                      struct arm_cm_additional_registers *regs) {
  // Extract values for easy inspection in debugger.
  volatile uint32_t mmfsr = SCB->CFSR & 0xff;
  volatile uint32_t fault_address = SCB->MMFAR;
  volatile struct memmanage_cause cause;

  // IACCVIOL
  cause.instruction_fault = (mmfsr & (1 << 0));
  // DACCVIOL
  cause.data_fault = (mmfsr & (1 << 1));
  // MUNSTKERR
  cause.fault_on_exception_return = (mmfsr & (1 << 3));
  // MSTKERR
  cause.fault_on_exception_entry = (mmfsr & (1 << 4));
  // MLSPERR
  cause.fault_on_lazy_fpu_preserve = (mmfsr & (1 << 5));
  // MMARVALID
  cause.valid_fault_address = (mmfsr & (1 << 7));

  USE(fault_address);
  USE(cause);

  while (1);
}

static void usagefault(struct arm_cm_exception_frame *frame,
                       struct arm_cm_additional_registers *regs) {
  while (1);
}

static void busfault(struct arm_cm_exception_frame *frame,
                     struct arm_cm_additional_registers *regs) {
  while (1);
}

void HardFault_Handler(void) __attribute__((naked));

void HardFault_Handler(void) {
  __asm__ volatile(
    // See comment on EXC_RETURN above for this bit test.
    "tst lr, #4;"
    "ite eq;"
    "mrseq r0, msp;"
    "mrsne r0, psp;"
    "push {r4-r11};"
    "mov r1, sp;"
    "b %0;" : : "i" (hardfault)
  );
  __builtin_unreachable();
}

void MemManage_Handler(void) __attribute__((naked));

void MemManage_Handler(void) {
  __asm__ volatile(
    // See comment on EXC_RETURN above for this bit test.
    "tst lr, #4;"
    "ite eq;"
    "mrseq r0, msp;"
    "mrsne r0, psp;"
    "push {r4-r11};"
    "mov r1, sp;"
    "b %0;" : : "i" (memmanage)
  );
  __builtin_unreachable();
}

void BusFault_Handler(void) __attribute__((naked));

void BusFault_Handler(void) {
  __asm__ volatile(
    // See comment on EXC_RETURN above for this bit test.
    "tst lr, #4;"
    "ite eq;"
    "mrseq r0, msp;"
    "mrsne r0, psp;"
    "push {r4-r11};"
    "mov r1, sp;"
    "b %0;" : : "i" (busfault)
  );
  __builtin_unreachable();
}

void __attribute__((naked)) UsageFault_Handler(void) {
  __asm__ volatile(
    // See comment on EXC_RETURN above for this bit test.
    "tst lr, #4;"
    "ite eq;"
    "mrseq r0, msp;"
    "mrsne r0, psp;"
    "push {r4-r11};"
    "mov r1, sp;"
    "b %0;" : : "i" (usagefault)
  );
  __builtin_unreachable();
}
